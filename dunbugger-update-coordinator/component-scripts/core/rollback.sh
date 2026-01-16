#!/bin/bash
#
# DuneBugger Core - Rollback Script
# ==================================
#
# Rolls back to the previous version by restoring the latest backup.
#
# Usage: ./rollback.sh
#

set -e

INSTALL_DIR="/opt/dunebugger/core"
BACKUP_DIR="/opt/dunebugger/backups"

echo "=========================================="
echo "Rolling back dunebugger-core"
echo "=========================================="

# Find the most recent backup
LATEST_BACKUP=$(ls -t "${BACKUP_DIR}"/core.*.tar.gz 2>/dev/null | head -n 1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "Error: No backup found in ${BACKUP_DIR}"
    exit 1
fi

echo "Using backup: ${LATEST_BACKUP}"

# Stop service
echo "Stopping service..."
systemctl stop dunebugger || true
echo "✓ Service stopped"

# Remove current installation
echo "Removing current installation..."
rm -rf "${INSTALL_DIR:?}"/*
echo "✓ Current installation removed"

# Restore backup
echo "Restoring backup..."
tar -xzf "$LATEST_BACKUP" -C "$INSTALL_DIR"
echo "✓ Backup restored"

# Install dependencies (in case they changed)
echo "Installing dependencies..."
pip3 install -r "${INSTALL_DIR}/requirements.txt"
echo "✓ Dependencies installed"

# Start service
echo "Starting service..."
systemctl start dunebugger
echo "✓ Service started"

# Wait for service to stabilize
echo "Waiting for service to stabilize..."
sleep 5

# Verify service is running
if systemctl is-active --quiet dunebugger; then
    echo "✓ Service is running"
    echo ""
    echo "Rollback completed successfully!"
    exit 0
else
    echo "✗ Service is not running after rollback"
    exit 1
fi
