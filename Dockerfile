# ============================================================================
# VS CODE WITH RDP DESKTOP SERVER
# ============================================================================
FROM ubuntu:22.04

# ============================================================================
# INSTALL EVERYTHING AS ROOT
# ============================================================================
RUN apt-get update && \
    apt-get install -y \
    # System tools
    curl wget git sudo \
    # Desktop environment
    xfce4 xfce4-goodies xfce4-terminal \
    xrdp xorgxrdp \
    # RDP/VNC tools
    tightvncserver tigervnc-standalone-server \
    x11vnc xvfb \
    # Browser
    firefox chromium-browser \
    # Programming
    python3 python3-pip python3-venv \
    openjdk-17-jdk nodejs npm \
    # Utilities
    htop neofetch vim nano \
    net-tools iputils-ping \
    unzip zip \
    # Audio support (optional)
    pulseaudio pavucontrol \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# INSTALL CODE-SERVER
# ============================================================================
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ============================================================================
# CREATE USER WITH RDP ACCESS
# ============================================================================
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder123" | chpasswd && \
    usermod -aG sudo coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder

# ============================================================================
# CONFIGURE RDP SERVER
# ============================================================================
# Set up xrdp
RUN echo "xfce4-session" > /home/coder/.xsession && \
    chown coder:coder /home/coder/.xsession

# Configure xrdp
RUN sed -i 's/port=3389/port=3390/g' /etc/xrdp/xrdp.ini && \
    echo "crypt_level=low" >> /etc/xrdp/xrdp.ini && \
    echo "max_bpp=24" >> /etc/xrdp/xrdp.ini

# Set up VNC password
RUN mkdir -p /home/coder/.vnc && \
    echo "coder123" | vncpasswd -f > /home/coder/.vnc/passwd && \
    chown -R coder:coder /home/coder/.vnc && \
    chmod 600 /home/coder/.vnc/passwd

# ============================================================================
# SWITCH TO USER AND SETUP
# ============================================================================
USER coder
WORKDIR /home/coder

# Create VNC start script
RUN cat > ~/start_vnc.sh << 'EOF'
#!/bin/bash
echo "Starting VNC Server..."
vncserver :1 -geometry 1280x720 -depth 24 -localhost no
echo "VNC running on display :1 (port 5901)"
echo "Password: coder123"
EOF

# Create RDP start script
RUN cat > ~/start_rdp.sh << 'EOF'
#!/bin/bash
echo "Starting RDP Server..."
sudo systemctl start xrdp
echo "RDP running on port 3390"
echo "Username: coder"
echo "Password: coder123"
EOF

# Create desktop shortcuts script
RUN cat > ~/create_desktop_shortcuts.sh << 'EOF'
#!/bin/bash
mkdir -p ~/Desktop
# Create VS Code desktop shortcut
cat > ~/Desktop/vscode.desktop << 'DESKTOP'
[Desktop Entry]
Name=VS Code Web
Exec=firefox http://localhost:8080
Icon=application-x-executable
Type=Application
DESKTOP

# Create terminal shortcut
cat > ~/Desktop/terminal.desktop << 'DESKTOP'
[Desktop Entry]
Name=Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Type=Application
DESKTOP

# Create browser shortcut
cat > ~/Desktop/browser.desktop << 'DESKTOP'
[Desktop Entry]
Name=Firefox
Exec=firefox
Icon=firefox
Type=Application
DESKTOP

chmod +x ~/Desktop/*.desktop
echo "Desktop shortcuts created!"
EOF

# ============================================================================
# INSTALL CLOUDFLARED FOR TUNNELING
# ============================================================================
RUN mkdir -p ~/.local/bin && \
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -O ~/.local/bin/cloudflared && \
    chmod +x ~/.local/bin/cloudflared

# Create RDP tunnel setup script
RUN cat > ~/setup_rdp_tunnel.sh << 'EOF'
#!/bin/bash
echo "CLOUDFLARE TUNNEL SETUP FOR RDP"
echo "================================"
echo ""
echo "This will create a secure tunnel for RDP access."
echo ""
echo "1. Login to Cloudflare (first time only):"
echo "   ~/.local/bin/cloudflared tunnel login"
echo ""
echo "2. Create a tunnel:"
echo "   ~/.local/bin/cloudflared tunnel create rdp-desktop"
echo ""
echo "3. Create config file:"
echo "   mkdir -p ~/.cloudflared"
echo "   cat > ~/.cloudflared/config.yml << 'CONFIG'"
echo "   tunnel: YOUR_TUNNEL_ID"
echo "   credentials-file: /home/coder/.cloudflared/cert.pem"
echo "   ingress:"
echo "     - hostname: rdp.yourdomain.com"
echo "       service: rdp://localhost:3390"
echo "     - hostname: vscode.yourdomain.com"
echo "       service: http://localhost:8080"
echo "     - service: http_status:404"
echo "   CONFIG"
echo ""
echo "4. Run the tunnel:"
echo "   ~/.local/bin/cloudflared tunnel run rdp-desktop"
echo ""
echo "5. Connect with:"
echo "   Windows: Use Remote Desktop Connection"
echo "   macOS: Use Microsoft Remote Desktop"
echo "   Linux: Use Remmina or xfreerdp"
echo "   Server: rdp.yourdomain.com:3390"
echo "   Username: coder"
echo "   Password: coder123"
EOF

RUN chmod +x ~/setup_rdp_tunnel.sh

# Create web-based RDP access script (noVNC)
RUN cat > ~/start_novnc.sh << 'EOF'
#!/bin/bash
echo "Setting up web-based RDP access..."
# Download noVNC
git clone https://github.com/novnc/noVNC.git ~/noVNC 2>/dev/null || echo "noVNC already exists"
cd ~/noVNC

# Start VNC server if not running
if ! vncserver -list | grep -q ":1"; then
    vncserver :1 -geometry 1024x768 -depth 24 -localhost no
fi

# Start noVNC proxy
./utils/novnc_proxy --vnc localhost:5901 --listen 6080 &
echo "Web RDP access at: http://localhost:6080/vnc.html"
echo "Password: coder123"
EOF

RUN chmod +x ~/start_novnc.sh

# ============================================================================
# VS CODE CONFIGURATION
# ============================================================================
RUN mkdir -p ~/.config/code-server
RUN cat > ~/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080
auth: none
cert: false
disable-telemetry: true
disable-update-check: true
EOF

# ============================================================================
# CREATE STARTUP SCRIPT
# ============================================================================
RUN cat > ~/start_all_services.sh << 'EOF'
#!/bin/bash
echo "========================================"
echo "     RDP DESKTOP + VS CODE SERVER"
echo "========================================"
echo ""
echo "Starting services..."

# Start VS Code
echo "1. Starting VS Code..."
code-server --bind-addr 0.0.0.0:8080 --auth none > ~/logs/vscode.log 2>&1 &

# Start RDP server
echo "2. Starting RDP Server..."
sudo systemctl start xrdp

# Start VNC server (optional)
echo "3. Starting VNC Server (optional)..."
vncserver :1 -geometry 1280x720 -depth 24 -localhost no > ~/logs/vnc.log 2>&1 &

# Create desktop shortcuts
echo "4. Creating desktop shortcuts..."
bash ~/create_desktop_shortcuts.sh

echo ""
echo "✅ ALL SERVICES STARTED!"
echo ""
echo "🔗 ACCESS METHODS:"
echo ""
echo "1. 🌐 VS Code Web Interface:"
echo "   http://localhost:8080"
echo ""
echo "2. 🖥️  RDP Access (Recommended):"
echo "   Port: 3390"
echo "   Username: coder"
echo "   Password: coder123"
echo "   Use: Remote Desktop Client"
echo ""
echo "3. 🌐 Web RDP (noVNC):"
echo "   http://localhost:6080/vnc.html"
echo "   Password: coder123"
echo ""
echo "4. 🔌 VNC Access:"
echo "   Port: 5901"
echo "   Password: coder123"
echo ""
echo "🛠️  AVAILABLE COMMANDS:"
echo "   ./setup_rdp_tunnel.sh    - Setup Cloudflare tunnel"
echo "   ./start_novnc.sh         - Start web RDP access"
echo "   cat ~/logs/vscode.log    - View VS Code logs"
echo ""
echo "📁 DESKTOP APPLICATIONS:"
echo "   • Firefox Browser"
echo "   • Terminal"
echo "   • File Manager"
echo "   • VS Code (via browser)"
echo "========================================"

# Keep container running
tail -f /dev/null
EOF

RUN chmod +x ~/start_all_services.sh

# ============================================================================
# CREATE DESKTOP WELCOME FILE
# ============================================================================
RUN cat > ~/Desktop/WELCOME.txt << 'EOF'
╔═══════════════════════════════════════════════════╗
║         WELCOME TO RDP DESKTOP SERVER            ║
╚═══════════════════════════════════════════════════╝

📌 Available Applications:
   • Firefox Web Browser
   • Terminal
   • VS Code (open Firefox and go to http://localhost:8080)
   • File Manager

🔧 Connection Information:
   RDP Port: 3390
   VNC Port: 5901
   Web RDP: http://localhost:6080/vnc.html
   VS Code: http://localhost:8080

👤 Login Credentials:
   Username: coder
   Password: coder123

🌐 External Access:
   Run: ./setup_rdp_tunnel.sh
   This will setup Cloudflare tunnel for secure external access

📞 Support:
   Check logs: ~/logs/
   Restart services from terminal
EOF

# ============================================================================
# CREATE LOGS DIRECTORY
# ============================================================================
RUN mkdir -p ~/logs

# ============================================================================
# EXPOSE PORTS
# ============================================================================
EXPOSE 8080    # VS Code
EXPOSE 3390    # RDP
EXPOSE 5901    # VNC
EXPOSE 6080    # noVNC Web

# ============================================================================
# SET DEFAULT COMMAND
# ============================================================================
CMD ["bash", "-c", "~/start_all_services.sh"]
