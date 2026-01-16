#!/bin/bash
#
# DuneBugger Remote - Health Check Script
# ========================================
#
# Verifies that the remote container is running and healthy.
#
# Usage: ./health-check.sh
# Exit codes:
#   0 = healthy
#   1 = unhealthy
#

set -e

CONTAINER_NAME="dunebugger-remote"

# Check if container exists and is running
if ! docker ps --filter name="$CONTAINER_NAME" --filter status=running --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
    echo "Container $CONTAINER_NAME is not running"
    exit 1
fi

# Check if container is healthy (if health check is defined)
HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "none")

if [ "$HEALTH_STATUS" = "none" ]; then
    # No health check defined, just verify it's running
    echo "Container $CONTAINER_NAME is running (no health check defined)"
    exit 0
elif [ "$HEALTH_STATUS" = "healthy" ]; then
    echo "Container $CONTAINER_NAME is healthy"
    exit 0
else
    echo "Container $CONTAINER_NAME health status: $HEALTH_STATUS"
    exit 1
fi
