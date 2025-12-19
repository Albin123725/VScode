#!/bin/bash
echo "🔧 Fixing VS Code authentication..."

# Create no-auth config
cat > /home/coder/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080
auth: none
cert: false
disable-telemetry: true
disable-update-check: true
EOF

# Restart code-server
pkill -f code-server
sleep 3

# Start with new config
su -c "code-server --config /home/coder/.config/code-server/config.yaml &" coder

echo "=========================================="
echo "✅ PASSWORD AUTHENTICATION DISABLED!"
echo ""
echo "Access your VS Code at:"
echo "https://YOUR_URL.onrender.com:8080"
echo ""
echo "No password required! 🎉"
echo "=========================================="
