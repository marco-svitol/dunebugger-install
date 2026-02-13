#!/usr/bin/env bash
set -e

echo "=== Dunebugger RPi Setup — Stage 2: Dunebugger folders, repos, venvs ==="

# must be pi
if [[ $EUID -eq 0 ]]; then
  echo "ERROR: Run this script as user 'pi'."
  exit 1
fi

###############################################
# Create components, config and data directories
###############################################
echo "[INFO] Creating Dunebugger directories..."

sudo mkdir -p /opt/dunebugger

sudo mkdir -p /opt/dunebugger/core
sudo mkdir -p /opt/dunebugger/terminal
sudo mkdir -p /opt/dunebugger/axpop-captive-portal

sudo mkdir -p /opt/dunebugger/data/core/music/easteregg
sudo mkdir -p /opt/dunebugger/data/core/music/onair
sudo mkdir -p /opt/dunebugger/data/core/sequences/onair
sudo mkdir -p /opt/dunebugger/data/core/modes
sudo mkdir -p /opt/dunebugger/data/core/sfx
sudo mkdir -p /opt/dunebugger/config/remote/
sudo mkdir -p /opt/dunebugger/config/scheduler/

sudo mkdir -p /opt/dunebugger/backups/
sudo mkdir -p /opt/dunebugger/update-coordinator/

sudo chown -R pi:pi /opt/dunebugger

sudo mkdir -p /var/log/dunebugger
sudo chown -R pi:pi /var/log/dunebugger

sudo mkdir -p /var/dunebugger/
sudo chown -R pi:pi /var/dunebugger/

###############################################
# Create NATS configuration
###############################################
echo "[INFO] Creating NATS configuration..."

sudo mkdir -p /opt/nats
sudo chown -R pi:pi /opt/nats
sudo tee /opt/nats/nats.conf > /dev/null <<'EOF'
listen: 0.0.0.0:4222
http: 0.0.0.0:8222
EOF

echo ""
echo "=== MANUAL STEP REQUIRED ==="
echo "Please copy your configurations FROM YOUR REMOTE MACHINE TO THIS RPI:"
echo ""
echo "On your remote machine run:"
echo "  scp -r /opt/dunebugger/data pi@<RPi_IP>:/opt/dunebugger/data"
echo "  scp -r /opt/dunebugger/config pi@<RPi_IP>:/opt/dunebugger/config"
echo ""
echo "Press ENTER once copying is complete..."
read

###############################################
# Clone repos over SSH
###############################################
echo "[INFO] Cloning Git repositories..."

cd /opt/dunebugger/core
git clone git@github.com:marco-svitol/dunebugger.git
cd /opt/dunebugger/terminal
git clone git@github.com:marco-svitol/dunebugger-terminal.git
cd /opt/dunebugger/axpop-captive-portal
git clone git@github.com:marco-svitol/axpop-captive-portal.git

###############################################
# Install build prerequisites
###############################################
echo "[INFO] Installing SWIG and Python dev libs..."
sudo apt install -y swig python3-dev liblgpio-dev python3-venv

###############################################
# Create venvs
###############################################
echo "[INFO] Creating Python venvs and installing requirements..."

cd /opt/dunebugger/core
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
deactivate

cd /opt/dunebugger/terminal
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
deactivate

cd /opt/dunebugger/axpop-captive-portal
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
deactivate

###############################################
# Install captive portal
###############################################
echo "[INFO] Installing captive portal..."
cd /opt/dunebugger/axpop-captive-portal
sudo ./install.sh

###############################################
# Install update coordinator
###############################################
echo "[INFO] Installing update coordinator..."

UPDATE_COORD_DIR="/opt/dunebugger/update-coordinator"
sudo mkdir -p "$UPDATE_COORD_DIR"
sudo mkdir -p /var/dunebugger/updates/requests
sudo mkdir -p /var/dunebugger/updates/status

# Copy coordinator script and component scripts
# These are sourced from the dunebugger-install repo
INSTALL_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COORDINATOR_SRC="${INSTALL_REPO_DIR}/../dunebugger-update-coordinator"

if [[ -d "$COORDINATOR_SRC" ]]; then
    sudo cp "$COORDINATOR_SRC/update-coordinator.sh" "$UPDATE_COORD_DIR/"
    sudo chmod +x "$UPDATE_COORD_DIR/update-coordinator.sh"
    sudo cp -r "$COORDINATOR_SRC/component-scripts" "$UPDATE_COORD_DIR/"
    sudo chmod +x "$UPDATE_COORD_DIR"/component-scripts/*/update.sh
    sudo chmod +x "$UPDATE_COORD_DIR"/component-scripts/*/rollback.sh
    sudo chmod +x "$UPDATE_COORD_DIR"/component-scripts/*/health-check.sh
    echo "[INFO] Update coordinator scripts installed"
else
    echo "[WARN] Update coordinator source not found at $COORDINATOR_SRC"
    echo "       You can install it manually later using the coordinator install.sh script."
fi

# Install yq for safe YAML editing (used by update scripts)
if ! command -v yq &> /dev/null; then
    echo "[INFO] Installing yq..."
    YQ_ARCH=$(dpkg --print-architecture)
    YQ_VERSION="v4.44.6"
    sudo wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${YQ_ARCH}"
    sudo chmod +x /usr/local/bin/yq
fi

# Install systemd service for update coordinator
if [[ -f "$COORDINATOR_SRC/dunebugger-update-coordinator.service" ]]; then
    sudo cp "$COORDINATOR_SRC/dunebugger-update-coordinator.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable dunebugger-update-coordinator
    echo "[INFO] Update coordinator systemd service enabled"
fi

sudo chown -R pi:pi /var/dunebugger/

echo ""
echo "=== Stage 2 completed ==="
echo "Next step: Install container: Remote + Scheduler + NATS."
echo "Run:"
echo "    bash stage3_containers.sh"
echo ""
