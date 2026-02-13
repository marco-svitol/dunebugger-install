#!/bin/bash
#
# DuneBugger Core - Health Check Script
# ======================================
#
# Verifies that the core service is running and healthy.
#
# Usage: ./health-check.sh
#

set -e

SERVICE_NAME="dunebugger"

# Check if service is active
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Service $SERVICE_NAME is active"
    exit 0
else
    echo "Service $SERVICE_NAME is not active"
    exit 1
fi
