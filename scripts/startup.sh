#!/bin/bash

echo "Starting VS Code Cloud Terminal..."

# Create health check directory
mkdir -p /home/coder/health-check
echo "<h1>VS Code Cloud Terminal</h1><p>Service is running</p>" > /home/coder/health-check/index.html

# Verify code-server exists
if ! command -v code-server &> /dev/null; then
    echo "❌ code-server not found! Installing via alternative method..."
    
    # Try to install via npm
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    npm install -g code-server
    
    if ! command -v code-server &> /dev/null; then
        echo "❌❌ FATAL: Cannot install code-server"
        exit 1
    fi
fi

echo "✅ code-server verified: $(code-server --version)"

# Start health check server
echo "Starting health check server..."
python3 /home/coder/scripts/health-server.py &

# Start simple HTTP server for Uptime Robot
echo "Starting uptime monitor..."
python3 -m http.server 3000 --directory /home/coder/health-check &

# Start code-server
echo "Starting VS Code Server..."
su -c "code-server --config /home/coder/.config/code-server/config.yaml" coder &

echo "✅ All services started!"
echo "VS Code available at: http://0.0.0.0:8080"
echo "Health check at: http://0.0.0.0:8081/health"

# Keep container running
wait
