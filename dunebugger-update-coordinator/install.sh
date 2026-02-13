#!/bin/bash
#
# DuneBugger Update Coordinator Installation Script
# ==================================================
#
# This script installs the update coordinator as a systemd service on the host.
#
# Usage:
#   sudo ./install.sh
#
# What it does:
#   1. Copies coordinator script to /opt/dunebugger/update-coordinator/
#   2. Installs systemd service file
#   3. Creates required directories with proper permissions
#   4. Enables and starts the service
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/dunebugger/update-coordinator"
UPDATE_DIR="/var/dunebugger/updates"
LOG_DIR="/var/log/dunebugger"
SERVICE_NAME="dunebugger-update-coordinator"
SERVICE_FILE="${SERVICE_NAME}.service"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   echo "Please run: sudo $0"
   exit 1
fi

echo "=========================================="
echo "DuneBugger Update Coordinator Installation"
echo "=========================================="
echo ""

# Check and install dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"

if ! command -v inotifywait &> /dev/null; then
    echo -e "${YELLOW}Installing inotify-tools...${NC}"
    apt-get install -y inotify-tools
fi

if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Installing jq...${NC}"
    apt-get install -y jq
fi

# Install yq for safe YAML editing (Go binary, ARM-compatible)
if ! command -v yq &> /dev/null; then
    echo -e "${YELLOW}Installing yq...${NC}"
    YQ_ARCH=$(dpkg --print-architecture)
    YQ_VERSION="v4.44.6"
    wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${YQ_ARCH}"
    chmod +x /usr/local/bin/yq
fi

echo -e "${GREEN}✓ Dependencies OK${NC}"
echo ""

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p "${UPDATE_DIR}/requests"
mkdir -p "${UPDATE_DIR}/status"
mkdir -p "$LOG_DIR"

# Set permissions
chmod 755 "$INSTALL_DIR"
chmod 755 "$UPDATE_DIR"
chmod 755 "${UPDATE_DIR}/requests"
chmod 755 "${UPDATE_DIR}/status"
chmod 755 "$LOG_DIR"

echo -e "${GREEN}✓ Directories created${NC}"
echo "  Install dir: $INSTALL_DIR"
echo "  Update dir: $UPDATE_DIR"
echo "  Log dir: $LOG_DIR"
echo ""

# Copy coordinator script
echo -e "${YELLOW}Installing coordinator script...${NC}"
cp update-coordinator.sh "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/update-coordinator.sh"
echo -e "${GREEN}✓ Coordinator script installed${NC}"

# Copy component scripts
echo -e "${YELLOW}Installing component scripts...${NC}"
cp -r component-scripts/ "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/component-scripts/*/update.sh
chmod +x "$INSTALL_DIR"/component-scripts/*/rollback.sh
chmod +x "$INSTALL_DIR"/component-scripts/*/health-check.sh
echo -e "${GREEN}✓ Component scripts installed${NC}"
echo ""

# Install systemd service
echo -e "${YELLOW}Installing systemd service...${NC}"
cp "$SERVICE_FILE" "/etc/systemd/system/"
systemctl daemon-reload
echo -e "${GREEN}✓ Service file installed${NC}"
echo ""

# Enable and start service
echo -e "${YELLOW}Enabling and starting service...${NC}"
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

# Wait a moment and check status
sleep 2

if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${GREEN}✓ Service is running${NC}"
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo "Check logs with: journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Installation completed successfully!${NC}"
echo "=========================================="
echo ""
echo "Service status:"
systemctl status "$SERVICE_NAME" --no-pager | head -n 10
echo ""
echo "Useful commands:"
echo "  View logs:    journalctl -u $SERVICE_NAME -f"
echo "  Stop service: systemctl stop $SERVICE_NAME"
echo "  Start service: systemctl start $SERVICE_NAME"
echo "  Service status: systemctl status $SERVICE_NAME"
echo ""
echo "Update directories:"
echo "  Requests: ${UPDATE_DIR}/requests"
echo "  Status:   ${UPDATE_DIR}/status"
echo "  Logs:     ${LOG_DIR}/update-coordinator.log"
echo ""
