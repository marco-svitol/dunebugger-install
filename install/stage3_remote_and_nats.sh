#!/usr/bin/env bash
set -e

echo "=== Dunebugger RPi Setup — Stage 3: Docker Remote + NATS ==="

if [[ $EUID -eq 0 ]]; then
  echo "ERROR: Run as user pi."
  exit 1
fi

###############################################
# Create .env template if missing
###############################################
if [[ ! -f ~/.env ]]; then
  echo "[INFO] Creating ~/.env template..."

  cat > ~/.env <<'EOF'
AUTH0_CLIENT_ID=""
AUTH0_CLIENT_SECRET=""
AUTH0_USERNAME=""
AUTH0_PASSWORD=""
WS_GROUP_NAME=""
DEVICE_ID=""
LOCATION_DESCRIPTION=""
EOF

  echo "[ACTION REQUIRED]"
  echo "Edit ~/.env with real values:"
  echo "  nano ~/.env"
  echo "Press ENTER when done..."
  read
fi

###############################################
# Create docker-compose.yaml template
###############################################
if [[ ! -f ~/docker-compose.yaml ]]; then
  echo "[INFO] Creating docker-compose.yaml template..."

  cat > ~/docker-compose.yaml <<'EOF'
version: '3.8'
services:
  dunebugger-remote:
    image: ilciclaio/dunebugger-remote:latest
    container_name: dunebugger-remote
    restart: unless-stopped
    network_mode: host
    env_file:
      - .env
    environment:
      - PYTHONPATH=/app
    volumes:
      - /etc/dunebugger-remote/config:/app/app/config:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
    depends_on:
      - nats-server

  nats-server:
    image: nats:latest
    container_name: nats-server
    restart: unless-stopped
    network_mode: host
    command: ["-m", "8222", "-DV"]
EOF

  echo "[ACTION REQUIRED]"
  echo "Review ~/docker-compose.yaml and modify if needed."
  echo "Press ENTER when done..."
  read
fi

###############################################
# Bring up Docker Remote + NATS
###############################################
echo "[INFO] Starting docker compose services..."
cd ~
docker compose up -d

echo "[INFO] Checking service health..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

echo ""
echo "Check that both containers are running and healthy."
echo "If OK, proceed to Stage 4:"
echo "    bash stage4_dunebugger_service.sh"
echo ""
echo "=== Stage 3 completed ==="
