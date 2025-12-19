#!/bin/bash

echo "=========================================="
echo "🚀 FULL ROOT ACCESS VS CODE TERMINAL"
echo "=========================================="

# Start all services as root
echo "Starting services..."

# 1. Start SSH
service ssh start
echo "✅ SSH (Port 22): root:root123 / coder:coder123"

# 2. Start RDP
xrdp --nodaemon &
echo "✅ RDP (Port 3389): User: coder, Password: coder123"

# 3. Start virtual display
Xvfb :99 -screen 0 1280x720x24 &
echo "✅ Virtual Display :99 ready"

# 4. Start VNC
x11vnc -display :99 -forever -shared -rfbport 5900 -passwd coder123 -bg &
echo "✅ VNC (Port 5900): Password: coder123"

# 5. Start code-server as coder user
su -c "code-server --bind-addr 0.0.0.0:8080 --auth none" coder &
echo "✅ VS Code (Port 8080): No password required"

# 6. Start health check server
python3 -m http.server 8081 --directory /tmp &

echo ""
echo "=========================================="
echo "📡 ACCESS INFORMATION"
echo "=========================================="
echo "VS Code:      https://YOUR_URL.onrender.com:8080"
echo "SSH:          ssh coder@YOUR_URL.onrender.com -p 2222"
echo "RDP:          Use Cloudflare Tunnel to port 3389"
echo "VNC:          Use Cloudflare Tunnel to port 5900"
echo ""
echo "🔑 CREDENTIALS"
echo "Root:         username: root, password: root123"
echo "Coder:        username: coder, password: coder123"
echo "Sudo:         Passwordless sudo enabled for coder"
echo ""
echo "🛠️  PRE-INSTALLED TOOLS"
echo "• Docker, Kubernetes, AWS/GCP/Azure CLI"
echo "• XFCE Desktop, RDP, VNC"
echo "• Python, Node.js, Java, Go, Rust"
echo "• MySQL, PostgreSQL, Redis, MongoDB"
echo "• Nmap, Wireshark, Security tools"
echo "=========================================="

# Keep container running
tail -f /dev/null
