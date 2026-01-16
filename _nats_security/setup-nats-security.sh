#!/bin/bash
# NATS Security Setup Script
# This script sets up secure NATS configuration for DuneBugger

set -e

echo "Setting up NATS security configuration..."

# Create NATS config directory
sudo mkdir -p /opt/dunebugger/remote/config/nats

# Copy the configuration file
sudo cp nats-secure.conf /opt/dunebugger/remote/config/nats/nats.conf

# Generate a secure random token
SECURE_TOKEN=$(openssl rand -hex 32)
echo "Generated secure token: $SECURE_TOKEN"

# Replace the default token with the generated one
sudo sed -i "s/dunebugger_secure_token_change_me_123456789/$SECURE_TOKEN/g" /opt/dunebugger/remote/config/nats/nats.conf

# Set proper permissions
sudo chown -R 1000:1000 /opt/dunebugger/remote/config/nats/
sudo chmod 644 /opt/dunebugger/remote/config/nats/nats.conf
echo "NATS security configuration completed!"
echo ""
echo "IMPORTANT: Save this token for your applications:"
echo "Token: $SECURE_TOKEN"
echo ""
echo "Next steps:"
echo "1. Update your DuneBugger applications to use this token"
echo "2. Consider setting up TLS certificates for additional encryption"
echo "3. Configure firewall rules to restrict access to NATS ports"
echo ""
echo "To use the token in your applications, set the NATS_TOKEN environment variable"
echo "or configure your NATS client connection string as:"
echo "nats://token@<rpi-ip>:4222"

# Optional: Create environment file for applications
echo "Creating .env.nats file for easy token management..."
cat > .env.nats << EOF
# NATS Security Configuration
NATS_TOKEN=$SECURE_TOKEN
NATS_URL=nats://localhost:4222
NATS_SECURE_URL=nats://$SECURE_TOKEN@localhost:4222
EOF

echo "Environment file created: .env.nats"
echo "You can source this file or use it in your docker-compose configuration"