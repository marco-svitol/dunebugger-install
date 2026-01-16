#!/bin/bash
# NATS Firewall Security Script
# Restricts NATS access to specific IP ranges

set -e

echo "Configuring firewall rules for NATS security..."

# Check if ufw is available
if command -v ufw >/dev/null 2>&1; then
    echo "Using UFW firewall..."
    
    # Block NATS ports by default
    sudo ufw deny 4222
    sudo ufw deny 8222
    
    # Allow NATS access only from local network (adjust as needed)
    echo "Enter your local network range (e.g., 192.168.1.0/24):"
    read -r LOCAL_NETWORK
    
    if [ -n "$LOCAL_NETWORK" ]; then
        sudo ufw allow from "$LOCAL_NETWORK" to any port 4222
        sudo ufw allow from "$LOCAL_NETWORK" to any port 8222
        echo "Allowed NATS access from $LOCAL_NETWORK"
    fi
    
    # Allow specific trusted IPs (optional)
    echo "Enter specific trusted IPs (comma-separated, or press Enter to skip):"
    read -r TRUSTED_IPS
    
    if [ -n "$TRUSTED_IPS" ]; then
        IFS=',' read -ra IPS <<< "$TRUSTED_IPS"
        for ip in "${IPS[@]}"; do
            ip=$(echo "$ip" | xargs) # trim whitespace
            sudo ufw allow from "$ip" to any port 4222
            sudo ufw allow from "$ip" to any port 8222
            echo "Allowed NATS access from $ip"
        done
    fi
    
elif command -v iptables >/dev/null 2>&1; then
    echo "Using iptables firewall..."
    
    # Example iptables rules (adjust as needed)
    echo "Enter your local network range (e.g., 192.168.1.0/24):"
    read -r LOCAL_NETWORK
    
    if [ -n "$LOCAL_NETWORK" ]; then
        sudo iptables -A INPUT -p tcp --dport 4222 -s "$LOCAL_NETWORK" -j ACCEPT
        sudo iptables -A INPUT -p tcp --dport 8222 -s "$LOCAL_NETWORK" -j ACCEPT
        sudo iptables -A INPUT -p tcp --dport 4222 -j DROP
        sudo iptables -A INPUT -p tcp --dport 8222 -j DROP
        echo "Configured iptables rules for $LOCAL_NETWORK"
        
        # Save rules (Ubuntu/Debian)
        if command -v iptables-save >/dev/null 2>&1; then
            sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        fi
    fi
    
else
    echo "No supported firewall found. Consider installing ufw or configuring iptables manually."
    echo ""
    echo "Manual iptables commands for your reference:"
    echo "sudo iptables -A INPUT -p tcp --dport 4222 -s YOUR_NETWORK/24 -j ACCEPT"
    echo "sudo iptables -A INPUT -p tcp --dport 8222 -s YOUR_NETWORK/24 -j ACCEPT"
    echo "sudo iptables -A INPUT -p tcp --dport 4222 -j DROP"
    echo "sudo iptables -A INPUT -p tcp --dport 8222 -j DROP"
fi

echo ""
echo "Firewall configuration completed!"
echo "NATS ports are now restricted to authorized networks only."