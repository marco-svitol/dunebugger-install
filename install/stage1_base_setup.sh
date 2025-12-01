#!/usr/bin/env bash
set -e

echo "=== Dunebugger RPi Setup — Stage 1: Base OS Preparation ==="

# Ensure script is run as pi (not root)
if [[ $EUID -eq 0 ]]; then
  echo "ERROR: Run this script as user 'pi', not as root."
  exit 1
fi

###############################################
# SYSTEM UPGRADE
###############################################
echo "[INFO] Updating system packages..."
sudo apt update -y
sudo apt upgrade -y

###############################################
# Basic utilities
###############################################
echo "[INFO] Installing base tools (tmux, vim)..."
sudo apt install -y tmux vim

###############################################
# Configure VIM
###############################################
echo "[INFO] Configuring vim for user pi..."

cat > ~/.vimrc <<'EOF'
syntax on
filetype plugin indent on
set visualbell
set t_vb=
set mouse-=a
set mousemodel=extend
EOF

echo "[INFO] Copying vim config to root..."
sudo cp ~/.vimrc /root/

###############################################
# VLC minimal installation
###############################################
echo "[INFO] Installing lightweight VLC components..."
sudo apt install --no-install-recommends vlc-bin vlc-plugin-base -y

###############################################
# Install Docker (Debian Trixie method)
###############################################
echo "[INFO] Installing Docker (Debian Trixie method)..."

sudo apt install -y apt-transport-https ca-certificates curl gpg

if [[ ! -f /usr/share/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
fi

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian trixie stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y

echo "[INFO] Verifying docker origin in apt-cache policy..."
apt-cache policy docker-ce | grep "download.docker.com" || echo "WARNING: Docker origin not detected (may still work)."

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[INFO] Adding user pi to docker group..."
sudo usermod -aG docker pi

sudo systemctl enable docker
sudo systemctl start docker

###############################################
# HOSTS FILE — add nats-server entry
###############################################
echo "[INFO] Ensuring hosts file has entry for nats-server..."

if ! grep -q "nats-server" /etc/hosts; then
  echo "127.0.0.1 nats-server" | sudo tee -a /etc/hosts
fi

###############################################
# Handle cloud-init managed hosts file (Debian Trixie on some images)
###############################################
CLOUD_CFG="/etc/cloud/cloud.cfg"
HOSTS_TEMPLATE="/etc/cloud/templates/hosts.debian.tmpl"

if [ -f "$CLOUD_CFG" ]; then
  if grep -q "manage_etc_hosts: true" "$CLOUD_CFG"; then
    echo "Cloud-init manages /etc/hosts. Updating template…"

    if [ -f "$HOSTS_TEMPLATE" ]; then
      if ! grep -q "nats-server" "$HOSTS_TEMPLATE"; then
        echo "127.0.0.1 nats-server" | sudo tee -a "$HOSTS_TEMPLATE" >/dev/null
        echo "Updated hosts.debian.tmpl with nats-server entry."
      else
        echo "nats-server already present in hosts.debian.tmpl"
      fi
    else
      echo "WARNING: Cloud-init enabled but hosts template not found at $HOSTS_TEMPLATE"
    fi
  else
    echo "Cloud-init present but not managing /etc/hosts. No template update required."
  fi
fi

###############################################
# MANUAL STEPS REMINDER
###############################################
echo ""
echo "=== MANUAL STEPS REQUIRED BEFORE CONTINUING ==="
echo "1. Add your private SSH keys to ~/.ssh (id_rsa and id_rsa.pub)."
echo "2. Run:"
echo "     chmod 600 ~/.ssh/id_rsa"
echo "     chmod 644 ~/.ssh/id_rsa.pub"
echo ""
echo "3. Prepare your remote replication machine, because in Stage 2 we will copy configs using scp."
echo ""
echo "When done, run:"
echo "    bash stage2_dunebugger_setup.sh"
echo ""

echo "=== Stage 1 completed successfully ==="
