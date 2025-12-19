#!/bin/bash

echo "Starting VS Code Cloud Terminal..."

# Create health check directory
mkdir -p /home/coder/health-check
echo "<h1>VS Code Cloud Terminal</h1><p>Service is running</p>" > /home/coder/health-check/index.html

# Install VS Code extensions as coder user (if not already installed)
if [ ! -d "/home/coder/.local/share/code-server/extensions" ]; then
    echo "Installing VS Code extensions..."
    su -c "code-server --install-extension ms-python.python" coder
    su -c "code-server --install-extension formulahendry.code-runner" coder
    su -c "code-server --install-extension yzhang.markdown-all-in-one" coder
fi

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
