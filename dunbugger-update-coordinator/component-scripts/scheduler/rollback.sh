#!/bin/bash
#
# DuneBugger Scheduler - Rollback Script
# =======================================
#
# Rolls back to the previous version.
#
# Usage: ./rollback.sh
#

set -e

COMPOSE_FILE="/opt/dunebugger/docker-compose.yml"
BACKUP_DIR="/opt/dunebugger/backups"

echo "=========================================="
echo "Rolling back dunebugger-scheduler"
echo "=========================================="

# Find the most recent backup
LATEST_BACKUP=$(ls -t "${BACKUP_DIR}"/docker-compose.*.yml 2>/dev/null | head -n 1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "Error: No backup found in ${BACKUP_DIR}"
    exit 1
fi

echo "Using backup: ${LATEST_BACKUP}"

# Restore backup
echo "Restoring docker-compose.yml..."
cp "$LATEST_BACKUP" "$COMPOSE_FILE"
echo "✓ Backup restored"

# Stop current container
echo "Stopping container..."
docker-compose -f "$COMPOSE_FILE" stop scheduler
echo "✓ Container stopped"

# Pull image from restored compose file
echo "Ensuring correct image is available..."
docker-compose -f "$COMPOSE_FILE" pull scheduler

# Restart container
echo "Starting container with previous configuration..."
docker-compose -f "$COMPOSE_FILE" up -d --no-deps scheduler
echo "✓ Container started"

# Wait for container to stabilize
echo "Waiting for container to stabilize..."
sleep 5

# Verify container is running
if docker ps --filter name=dunebugger-scheduler --filter status=running --format '{{.Names}}' | grep -q dunebugger-scheduler; then
    echo "✓ Container is running"
    echo ""
    echo "Rollback completed successfully!"
    exit 0
else
    echo "✗ Container is not running after rollback"
    exit 1
fi
