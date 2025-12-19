#!/bin/bash

echo "Enabling all services..."

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Switching to root..."
    sudo su -
fi

# Enable Docker
systemctl enable docker 2>/dev/null || true
service docker start 2>/dev/null || true

# Enable SSH
systemctl enable ssh 2>/dev/null || true
service ssh restart 2>/dev/null || true

# Enable cron
systemctl enable cron 2>/dev/null || true
service cron start 2>/dev/null || true

# Set up firewall (allow everything)
ufw allow 22/tcp 2>/dev/null || true
ufw allow 80/tcp 2>/dev/null || true  
ufw allow 443/tcp 2>/dev/null || true
ufw allow 8080/tcp 2>/dev/null || true
ufw allow 3389/tcp 2>/dev/null || true
ufw allow 5900/tcp 2>/dev/null || true

echo "✅ All services enabled!"
