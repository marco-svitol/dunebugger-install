#!/usr/bin/env bash
set -euo pipefail

###############################################
# DUNEBUGGER INSTALL WRAPPER
# Downloads and runs Stage 1–4 from GitHub
###############################################

# --- CONFIG ---
GITHUB_REPO_URL="https://raw.githubusercontent.com/ilciclaio/dunebugger-install/main/install"
SCRIPTS=(
  "stage1_base_setup.sh"
  "stage2_dunebugger_setup.sh"
  "stage3_containers.sh"
  "stage4_dunebugger_service.sh"
)

LOG_FILE="/var/log/dunebugger-install.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

###############################################
log() {
  echo "[DUNEBUGGER] $*" | tee -a "$LOG_FILE"
}

###############################################
# 1. SAFETY CHECKS
###############################################
if [[ $EUID -eq 0 ]]; then
  log "ERROR: Do NOT run this installer as root. Run it as user 'pi'."
  exit 1
fi

if ! ping -c1 google.com &>/dev/null; then
  log "ERROR: No internet connection detected."
  exit 1
fi

ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" != "armhf" && "$ARCH" != "arm64" ]]; then
  log "ERROR: Unsupported architecture: $ARCH"
  log "Run on Raspberry Pi only."
  exit 1
fi

log "System architecture OK: $ARCH"
log "Internet connection OK"

###############################################
# 2. WORK DIRECTORY
###############################################
WORKDIR="$HOME/dunebugger-install"
mkdir -p "$WORKDIR"

log "Using work directory: $WORKDIR"

###############################################
# 3. DOWNLOAD SCRIPTS
###############################################
log "Downloading installation stages from GitHub..."

cd "$WORKDIR"

for script in "${SCRIPTS[@]}"; do
  URL="$GITHUB_REPO_URL/$script"
  log "Fetching: $URL"

  if ! curl -fsSL "$URL" -o "$script"; then
    log "ERROR: Failed to download $script"
    exit 1
  fi

  chmod +x "$script"
  log "Downloaded and marked executable: $script"
done

###############################################
# 4. RUN SCRIPTS SEQUENTIALLY
###############################################

for script in "${SCRIPTS[@]}"; do
  echo ""
  echo "--------------------------------------------------------"
  log "READY TO RUN: $script"
  echo "--------------------------------------------------------"
  echo ""
  echo "This part may require manual interaction depending on the stage."
  echo "Press ENTER to continue."
  read

  log "Executing $script..."
  bash "$script" 2>&1 | tee -a "$LOG_FILE"

  log "$script completed successfully."
done

###############################################
# 5. FINISH
###############################################
echo ""
log "======================================================"
log "   Dunebugger installation COMPLETED SUCCESSFULLY"
log "======================================================"
echo ""
log "You may now reboot the system:"
log "  sudo reboot"
echo ""
