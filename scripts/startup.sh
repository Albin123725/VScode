#!/bin/bash

echo "Starting VS Code Cloud Terminal..."

# Create health check directory
mkdir -p /home/coder/health-check
echo "<h1>VS Code Cloud Terminal</h1><p>Service is running</p>" > /home/coder/health-check/index.html

# Verify code-server
if ! command -v code-server &> /dev/null; then
    echo "Installing code-server..."
    curl -fsSL https://code-server.dev/install.sh | sh
fi

echo "✅ code-server: $(code-server --version)"

# Start health check server
echo "Starting health check server..."
python3 /home/coder/scripts/health-server.py &

# Start uptime monitor for Uptime Robot
echo "Starting uptime monitor..."
python3 -m http.server 3000 --directory /home/coder/health-check &

# Start code-server WITH NO AUTHENTICATION
echo "Starting VS Code Server (no password required)..."
su -c "code-server --bind-addr 0.0.0.0:8080 --auth none --disable-telemetry" coder &

echo "=========================================="
echo "✅ ALL SERVICES STARTED!"
echo "VS Code: https://YOUR_URL.onrender.com:8080"
echo "Health: https://YOUR_URL.onrender.com:8081/health"
echo "Uptime: https://YOUR_URL.onrender.com:3000"
echo "=========================================="

wait
