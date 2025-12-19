#!/bin/bash

# Start health check server in background
echo "Starting health check server..."
python3 /home/coder/scripts/health-server.py &

# Start code-server with our config
echo "Starting VS Code Server..."
su -c "code-server --config /home/coder/.config/code-server/config.yaml" coder &

# Start additional services
echo "Starting additional services..."

# Start a simple HTTP server on port 3000 for uptime robot
python3 -m http.server 3000 --directory /home/coder/health-check &

# Keep container running
echo "All services started. Container is running."
wait
