#!/bin/bash
#
# DuneBugger Remote - Update Script
# ==================================
#
# Updates the remote container to a new version by modifying docker-compose.yml
# and pulling/restarting the container.
#
# Usage: ./update.sh VERSION
# Example: ./update.sh 1.2.3
#

set -e

VERSION="$1"
COMPOSE_FILE="/opt/dunebugger/docker-compose.yml"
BACKUP_DIR="/opt/dunebugger/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Validate input
if [ -z "$VERSION" ]; then
    echo "Error: Version argument required"
    echo "Usage: $0 VERSION"
    exit 1
fi

echo "=========================================="
echo "Updating dunebugger-remote to v${VERSION}"
echo "=========================================="

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup current docker-compose.yml
echo "Creating backup..."
cp "$COMPOSE_FILE" "${BACKUP_DIR}/docker-compose.${TIMESTAMP}.yml"
echo "✓ Backup created: ${BACKUP_DIR}/docker-compose.${TIMESTAMP}.yml"

# Update image tag in docker-compose.yml
echo "Updating docker-compose.yml..."
sed -i "s|image: ghcr.io/marco-svitol/dunebugger-remote:.*|image: ghcr.io/marco-svitol/dunebugger-remote:${VERSION}|g" "$COMPOSE_FILE"
echo "✓ Image tag updated to ${VERSION}"

# Pull new image
echo "Pulling new image..."
docker-compose -f "$COMPOSE_FILE" pull remote
echo "✓ Image pulled"

# Restart container
echo "Restarting container..."
docker-compose -f "$COMPOSE_FILE" up -d --no-deps remote
echo "✓ Container restarted"

# Wait for container to be healthy
echo "Waiting for container to be healthy..."
sleep 5

# Verify container is running
if docker ps --filter name=dunebugger-remote --filter status=running --format '{{.Names}}' | grep -q dunebugger-remote; then
    echo "✓ Container is running"
    echo ""
    echo "Update completed successfully!"
    exit 0
else
    echo "✗ Container is not running"
    echo "Rolling back..."
    cp "${BACKUP_DIR}/docker-compose.${TIMESTAMP}.yml" "$COMPOSE_FILE"
    docker-compose -f "$COMPOSE_FILE" up -d --no-deps remote
    exit 1
fi
