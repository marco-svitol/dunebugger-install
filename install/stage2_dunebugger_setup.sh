#!/usr/bin/env bash
set -e

echo "=== Dunebugger RPi Setup — Stage 2: Dunebugger folders, repos, venvs ==="

# must be pi
if [[ $EUID -eq 0 ]]; then
  echo "ERROR: Run this script as user 'pi'."
  exit 1
fi

###############################################
# Create config directories
###############################################
echo "[INFO] Creating Dunebugger directories..."

sudo mkdir -p /opt/dunebugger-data/music/easteregg
sudo mkdir -p /opt/dunebugger-data/music/onair
sudo mkdir -p /opt/dunebugger-data/sequences/onair
sudo mkdir -p /opt/dunebugger-data/sfx
sudo chown -R pi:pi /opt/dunebugger-data
sudo mkdir -p /opt/dunebugger-remote/config
sudo chown -R pi:pi /opt/dunebugger-remote
sudo mkdir -p /opt/dunebugger-scheduler/config
sudo chown -R pi:pi /opt/dunebugger-scheduler

echo ""
echo "=== MANUAL STEP REQUIRED ==="
echo "Please copy your configurations FROM YOUR REMOTE MACHINE TO THIS RPI:"
echo ""
echo "On your remote machine run:"
echo "  scp -r /opt/dunebugger-data pi@<RPi_IP>:/opt"
echo "  scp -r /opt/dunebugger-remote pi@<RPi_IP>:/opt"
echo "  scp -r /opt/dunebugger-scheduler pi@<RPi_IP>:/opt"
echo ""
echo "Press ENTER once copying is complete..."
read

###############################################
# Folder creation for code
###############################################
echo "[INFO] Creating /opt folders..."

sudo mkdir -p /opt/dunebugger
sudo mkdir -p /opt/dunebugger-terminal
sudo mkdir -p /opt/axpop-captive-portal
sudo chown -R pi:pi /opt

###############################################
# Clone repos over SSH
###############################################
echo "[INFO] Cloning Git repositories..."

cd /opt
git clone git@github.com:marco-svitol/dunebugger.git
git clone git@github.com:marco-svitol/dunebugger-terminal.git
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

cd /opt/dunebugger
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
deactivate

cd /opt/dunebugger-terminal
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
deactivate

cd /opt/axpop-captive-portal
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
deactivate

###############################################
# Install captive portal
###############################################
echo "[INFO] Installing captive portal..."
cd /opt/axpop-captive-portal
sudo ./install.sh

echo ""
echo "=== Stage 2 completed ==="
echo "Next step: Install container: Remote + Scheduler + NATS."
echo "Run:"
echo "    bash stage3_containers.sh"
echo ""
