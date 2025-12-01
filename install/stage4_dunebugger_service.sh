#!/usr/bin/env bash
set -e

echo "=== Dunebugger RPi Setup — Stage 4: Systemd Service ==="

###############################################
# Create systemd unit
###############################################
SERVICE_FILE=/etc/systemd/system/dunebugger.service

echo "[INFO] Creating Dunebugger systemd service..."

sudo bash -c "cat > $SERVICE_FILE" <<'EOF'
[Unit]
Description=Dunebugger Core App
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/opt/dunebugger
ExecStart=/opt/dunebugger/.venv/bin/python /opt/dunebugger/app/main.py
Restart=always
RestartSec=5
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOF

###############################################
# Enable + start
###############################################
echo "[INFO] Reloading systemd..."
sudo systemctl daemon-reload

echo "[INFO] Enabling service..."
sudo systemctl enable dunebugger.service

echo "[INFO] Starting service..."
sudo systemctl start dunebugger.service

echo "[INFO] Checking service status..."
sudo systemctl status --no-pager dunebugger.service || true

###############################################
# Add aliases to .bashrc
###############################################
echo "[INFO] Adding helpful aliases..."

if ! grep -q "alias dbt=" ~/.bashrc; then
  cat >> ~/.bashrc <<'EOF'

# Dunebugger aliases
alias dbt='/opt/dunebugger-terminal/.venv/bin/python /opt/dunebugger-terminal/app/main.py'
alias dbj='journalctl -u dunebugger.service -f'
alias dbst='sudo systemctl status dunebugger.service'
EOF
fi

echo ""
echo "=== Installation COMPLETE ==="
echo "You can now run:"
echo "  dbt     -> Dunebugger terminal"
echo "  dbj     -> Follow Dunebugger logs"
echo "  dbst    -> Check service status"
echo ""
echo "Optionally reboot:"
echo "  sudo reboot"
echo ""
