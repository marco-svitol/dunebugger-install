#!/bin/bash
#
# DuneBugger Core - Update Script
# ================================
#
# Updates the core Python application to a new version.
#
# Usage: ./update.sh VERSION
# Example: ./update.sh 1.2.3
#

set -e

VERSION="$1"
INSTALL_DIR="/opt/dunebugger/core"
BACKUP_DIR="/opt/dunebugger/backups"
TEMP_DIR="/tmp/dunebugger_update"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
GITHUB_REPO="marco-svitol/dunebugger"

# Validate input
if [ -z "$VERSION" ]; then
    echo "Error: Version argument required"
    echo "Usage: $0 VERSION"
    exit 1
fi

echo "=========================================="
echo "Updating dunebugger-core to v${VERSION}"
echo "=========================================="

# Create directories
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"

# Download release artifact
echo "Downloading release artifact..."
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/dunebugger-${VERSION}.tar.gz"
wget -O "${TEMP_DIR}/dunebugger-${VERSION}.tar.gz" "$DOWNLOAD_URL"

if [ $? -ne 0 ]; then
    echo "Error: Failed to download release artifact"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "✓ Artifact downloaded"

# Create backup of current installation
echo "Creating backup..."
tar -czf "${BACKUP_DIR}/core.${TIMESTAMP}.tar.gz" -C "$INSTALL_DIR" .
echo "✓ Backup created: ${BACKUP_DIR}/core.${TIMESTAMP}.tar.gz"

# Stop service
echo "Stopping service..."
systemctl stop dunebugger || true
echo "✓ Service stopped"

# Remove old installation
echo "Removing old installation..."
rm -rf "${INSTALL_DIR:?}"/*
echo "✓ Old installation removed"

# Extract new version
echo "Extracting new version..."
tar -xzf "${TEMP_DIR}/dunebugger-${VERSION}.tar.gz" -C "$INSTALL_DIR"
echo "✓ New version extracted"

# Install dependencies
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
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    echo ""
    echo "Update completed successfully!"
    exit 0
else
    echo "✗ Service is not running"
    echo "Rolling back..."
    
    # Stop failed service
    systemctl stop dunebugger || true
    
    # Restore backup
    rm -rf "${INSTALL_DIR:?}"/*
    tar -xzf "${BACKUP_DIR}/core.${TIMESTAMP}.tar.gz" -C "$INSTALL_DIR"
    
    # Start service
    systemctl start dunebugger
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    exit 1
fi
