#!/bin/bash
#
# DuneBugger Scheduler - Health Check Script
# ===========================================
#
# Verifies that the scheduler container is running and healthy.
#
# Usage: ./health-check.sh
#

set -e

CONTAINER_NAME="dunebugger-scheduler"

# Check if container exists and is running
if ! docker ps --filter name="$CONTAINER_NAME" --filter status=running --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
    echo "Container $CONTAINER_NAME is not running"
    exit 1
fi

# Check if container is healthy
HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "none")

if [ "$HEALTH_STATUS" = "none" ]; then
    echo "Container $CONTAINER_NAME is running (no health check defined)"
    exit 0
elif [ "$HEALTH_STATUS" = "healthy" ]; then
    echo "Container $CONTAINER_NAME is healthy"
    exit 0
else
    echo "Container $CONTAINER_NAME health status: $HEALTH_STATUS"
    exit 1
fi
