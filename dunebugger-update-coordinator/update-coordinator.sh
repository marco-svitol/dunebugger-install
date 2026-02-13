#!/bin/bash
#
# DuneBugger Update Coordinator
# ==============================
#
# Lightweight host-side service that watches for update requests from
# dunebugger-remote (via shared volume) and executes component scripts.
#
# Replaces update-coordinator.py — no Python dependency, uses inotifywait + jq.
#
# Architecture:
#   dunebugger-remote (container) --[writes JSON]--> /var/dunebugger/updates/requests/
#                                                              |
#                                                    update-coordinator.sh
#                                                              |
#                                            [executes component scripts]
#                                                              |
#   dunebugger-remote (container) <--[reads JSON]-- /var/dunebugger/updates/status/
#

set -euo pipefail

# Configuration
REQUEST_DIR="/var/dunebugger/updates/requests"
STATUS_DIR="/var/dunebugger/updates/status"
LOCKFILE="/var/dunebugger/updates/.lock"
SCRIPT_BASE="/opt/dunebugger/update-coordinator/component-scripts"
SCRIPT_TIMEOUT=600  # 10 minutes

# Valid components and actions
VALID_COMPONENTS="core scheduler remote"
VALID_ACTIONS="update rollback health"

# Logging helpers
log_info()  { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO]  $*"; }
log_error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2; }
log_warn()  { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN]  $*"; }

# Write a status JSON file
write_status() {
    local request_id="$1"
    local component="$2"
    local action="$3"
    local success="$4"
    local message="$5"
    local output="$6"
    local error_msg="$7"
    local phase="${8:-completed}"

    local status_file="${STATUS_DIR}/${request_id}.json"

    jq -n \
        --arg rid "$request_id" \
        --arg comp "$component" \
        --arg act "$action" \
        --argjson success "$success" \
        --arg msg "$message" \
        --arg out "$output" \
        --arg err "$error_msg" \
        --arg ts "$(date -Iseconds)" \
        --arg phase "$phase" \
        '{
            request_id: $rid,
            component: $comp,
            action: $act,
            success: $success,
            message: $msg,
            output: $out,
            error: $err,
            phase: $phase,
            timestamp: $ts
        }' > "$status_file"

    log_info "Status written: ${status_file} (success=${success}, phase=${phase})"
}

# Write an in-progress status (for progress feedback)
write_progress() {
    local request_id="$1"
    local component="$2"
    local action="$3"
    local phase="$4"

    local status_file="${STATUS_DIR}/${request_id}.json"

    jq -n \
        --arg rid "$request_id" \
        --arg comp "$component" \
        --arg act "$action" \
        --arg phase "$phase" \
        --arg ts "$(date -Iseconds)" \
        '{
            request_id: $rid,
            component: $comp,
            action: $act,
            success: null,
            message: "in_progress",
            output: "",
            error: "",
            phase: $phase,
            timestamp: $ts
        }' > "$status_file"

    log_info "Progress update: ${component}/${action} phase=${phase}"
}

# Validate a request JSON and process it
process_request() {
    local request_file="$1"

    # Small delay to ensure file is fully written
    sleep 0.2

    # Read and validate JSON
    if ! jq empty "$request_file" 2>/dev/null; then
        log_error "Invalid JSON in request file: $request_file"
        rm -f "$request_file"
        return
    fi

    local component action version request_id
    component=$(jq -r '.component // empty' "$request_file")
    action=$(jq -r '.action // empty' "$request_file")
    version=$(jq -r '.version // empty' "$request_file")
    request_id=$(jq -r '.request_id // "unknown"' "$request_file")

    log_info "Processing request ${request_id}: ${component}/${action} (version: ${version})"

    # Validate component
    if [[ -z "$component" ]]; then
        write_status "$request_id" "unknown" "unknown" false "Missing 'component' field" "" "Validation error"
        rm -f "$request_file"
        return
    fi
    if ! echo "$VALID_COMPONENTS" | grep -qw "$component"; then
        write_status "$request_id" "$component" "unknown" false "Unknown component: ${component}" "" "Validation error"
        rm -f "$request_file"
        return
    fi

    # Validate action
    if [[ -z "$action" ]]; then
        write_status "$request_id" "$component" "unknown" false "Missing 'action' field" "" "Validation error"
        rm -f "$request_file"
        return
    fi
    if ! echo "$VALID_ACTIONS" | grep -qw "$action"; then
        write_status "$request_id" "$component" "$action" false "Invalid action: ${action}" "" "Validation error"
        rm -f "$request_file"
        return
    fi

    # Validate script exists
    local script_path="${SCRIPT_BASE}/${component}/${action}.sh"
    if [[ ! -x "$script_path" ]]; then
        write_status "$request_id" "$component" "$action" false "Script not found or not executable: ${script_path}" "" "Missing script"
        rm -f "$request_file"
        return
    fi

    # Acquire lock to prevent concurrent updates
    (
        flock -n 200 || {
            write_status "$request_id" "$component" "$action" false "Another update is already in progress" "" "Concurrent update rejected"
            rm -f "$request_file"
            return
        }

        # Write initial progress
        write_progress "$request_id" "$component" "$action" "starting"

        # Build command
        local cmd=("$script_path")
        if [[ "$action" == "update" && -n "$version" ]]; then
            cmd+=("$version")
        fi

        log_info "Executing: ${cmd[*]}"

        # Execute script, capture output and parse PHASE markers for progress
        local output="" error_output="" exit_code=0
        local temp_out temp_err
        temp_out=$(mktemp)
        temp_err=$(mktemp)

        # Run script with timeout, streaming stdout to parse PHASE: markers
        if timeout "$SCRIPT_TIMEOUT" "${cmd[@]}" > >(
            while IFS= read -r line; do
                echo "$line" >> "$temp_out"
                # Check for PHASE markers and write progress
                if [[ "$line" == PHASE:* ]]; then
                    local phase="${line#PHASE:}"
                    write_progress "$request_id" "$component" "$action" "$phase"
                fi
            done
        ) 2>"$temp_err"; then
            exit_code=0
        else
            exit_code=$?
        fi

        output=$(cat "$temp_out" 2>/dev/null || echo "")
        error_output=$(cat "$temp_err" 2>/dev/null || echo "")
        rm -f "$temp_out" "$temp_err"

        if [[ $exit_code -eq 0 ]]; then
            write_status "$request_id" "$component" "$action" true "Command completed successfully" "$output" ""
            log_info "Request ${request_id} completed successfully"
        elif [[ $exit_code -eq 124 ]]; then
            write_status "$request_id" "$component" "$action" false "Script execution timeout (10 minutes)" "$output" "$error_output"
            log_error "Script timeout: ${script_path}"
        else
            write_status "$request_id" "$component" "$action" false "Command failed with exit code ${exit_code}" "$output" "$error_output"
            log_error "Script failed (exit ${exit_code}): ${script_path}"
        fi

        # Remove processed request file
        rm -f "$request_file"

    ) 200>"$LOCKFILE"
}

# Process any leftover request files from before startup
process_pending_requests() {
    local pending
    pending=$(find "$REQUEST_DIR" -name '*.json' -type f 2>/dev/null | sort)
    if [[ -n "$pending" ]]; then
        log_info "Processing pending requests from before startup..."
        while IFS= read -r f; do
            process_request "$f"
        done <<< "$pending"
    fi
}

# Graceful shutdown
cleanup() {
    log_info "Received shutdown signal, stopping..."
    # Kill all child processes (inotifywait pipe)
    kill 0 2>/dev/null || true
    log_info "Update coordinator stopped"
    exit 0
}

# Main
main() {
    log_info "========================================================================"
    log_info "DuneBugger Update Coordinator Starting"
    log_info "========================================================================"

    # Setup signal handlers
    trap cleanup SIGTERM SIGINT

    # Ensure directories exist
    mkdir -p "$REQUEST_DIR" "$STATUS_DIR"

    # Log configuration
    log_info "Request directory: ${REQUEST_DIR}"
    log_info "Status directory:  ${STATUS_DIR}"
    log_info "Script base:       ${SCRIPT_BASE}"
    log_info "Component directories:"
    for comp in $VALID_COMPONENTS; do
        local comp_dir="${SCRIPT_BASE}/${comp}"
        if [[ -d "$comp_dir" ]]; then
            log_info "  ${comp}: ${comp_dir} [✓]"
        else
            log_warn "  ${comp}: ${comp_dir} [✗]"
        fi
    done

    # Process any leftover requests
    process_pending_requests

    log_info "Watching for requests in: ${REQUEST_DIR}"

        # Start inotifywait in monitor mode, pipe filenames to the processing loop
    log_info "Watching for requests in: ${REQUEST_DIR}"
    inotifywait -m -q -e close_write --format '%f' "$REQUEST_DIR" | \
    while IFS= read -r filename; do
        if [[ "$filename" == *.json ]]; then
            local request_file="${REQUEST_DIR}/${filename}"
            if [[ -f "$request_file" ]]; then
                process_request "$request_file"
            fi
        fi
    done
}

main "$@"
