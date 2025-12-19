#!/bin/bash

echo "Starting VS Code Cloud Terminal with ROOT privileges..."

# Create health check directory
mkdir -p /home/coder/health-check
echo "<h1>VS Code with Sudo Access</h1><p>Run 'sudo' for root access</p>" > /home/coder/health-check/index.html

# Verify sudo works
sudo echo "✅ Sudo access verified" || echo "⚠ Sudo may not work"

# Start health check server
python3 /home/coder/scripts/health-server.py &

# Start uptime monitor
python3 -m http.server 3000 --directory /home/coder/health-check &

# Start code-server with no auth
su -c "code-server --bind-addr 0.0.0.0:8080 --auth none --disable-telemetry" coder &

echo "=========================================="
echo "✅ VS Code with ROOT ACCESS"
echo "=========================================="
echo "VS Code: https://YOUR_URL.onrender.com:8080"
echo "Health:  https://YOUR_URL.onrender.com:8081/health"
echo ""
echo "📦 ROOT PRIVILEGES ENABLED:"
echo "   • Run: sudo apt update"
echo "   • Run: sudo apt install [package]"
echo "   • Run: sudo nano /etc/..."
echo "   • Password: coder (if asked)"
echo ""
echo "🛠️  Available commands:"
echo "   sudo apt update && sudo apt upgrade"
echo "   sudo apt install neofetch htop vim"
echo "   sudo systemctl [command]"
echo "=========================================="

wait
