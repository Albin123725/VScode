FROM ubuntu:22.04

# ============================================================================
# AUTOMATIC TIMEZONE CONFIGURATION FOR INDIA
# ============================================================================
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata

# Pre-configure timezone for India
RUN echo "tzdata tzdata/Areas select Asia" > /tmp/tz.txt && \
    echo "tzdata tzdata/Zones/Asia select Kolkata" >> /tmp/tz.txt && \
    debconf-set-selections /tmp/tz.txt && \
    rm /tmp/tz.txt

# ============================================================================
# INSTALL EVERYTHING WITH AUTOMATIC CONFIGURATION
# ============================================================================
RUN apt-get update && \
    apt-get install -y \
    # System tools
    curl wget git sudo tzdata locales \
    # Desktop environment
    xfce4 xfce4-goodies xfce4-terminal \
    xrdp xorgxrdp \
    # RDP/VNC tools
    tightvncserver \
    x11vnc xvfb \
    # Browser
    firefox chromium-browser \
    # Programming
    python3 python3-pip \
    # Utilities
    htop neofetch vim nano \
    net-tools iputils-ping \
    unzip zip \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# SET INDIAN LOCALE AND TIMEZONE
# ============================================================================
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

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

# Configure xrdp for better performance
RUN sed -i 's/port=3389/port=3390/g' /etc/xrdp/xrdp.ini && \
    echo "[xrdp1]" >> /etc/xrdp/xrdp.ini && \
    echo "name=Indian Desktop" >> /etc/xrdp/xrdp.ini && \
    echo "lib=libvnc.so" >> /etc/xrdp/xrdp.ini && \
    echo "username=coder" >> /etc/xrdp/xrdp.ini && \
    echo "password=coder123" >> /etc/xrdp/xrdp.ini && \
    echo "ip=127.0.0.1" >> /etc/xrdp/xrdp.ini && \
    echo "port=5901" >> /etc/xrdp/xrdp.ini

# ============================================================================
# SETUP VNC FOR INDIAN DESKTOP
# ============================================================================
RUN mkdir -p /home/coder/.vnc && \
    echo "coder123" | vncpasswd -f > /home/coder/.vnc/passwd && \
    chown -R coder:coder /home/coder/.vnc && \
    chmod 600 /home/coder/.vnc/passwd

# ============================================================================
# SWITCH TO USER AND SETUP DESKTOP
# ============================================================================
USER coder
WORKDIR /home/coder

# Set Indian locale for user
RUN echo "export LANG=en_IN.UTF-8" >> ~/.bashrc && \
    echo "export LANGUAGE=en_IN:en" >> ~/.bashrc && \
    echo "export LC_ALL=en_IN.UTF-8" >> ~/.bashrc && \
    echo "export TZ=Asia/Kolkata" >> ~/.bashrc

# Create desktop environment with Indian settings
RUN cat > ~/configure_indian_desktop.sh << 'EOF'
#!/bin/bash
# Set Indian keyboard layout
setxkbmap -layout in

# Create Indian desktop theme
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml
cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml << 'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Adwaita"/>
    <property name="IconThemeName" type="string" value="Adwaita"/>
    <property name="DoubleClickTime" type="int" value="250"/>
    <property name="DoubleClickDistance" type="int" value="5"/>
  </property>
</channel>
XML

echo "Indian desktop configured!"
EOF

# Create VNC start script
RUN cat > ~/start_vnc.sh << 'EOF'
#!/bin/bash
echo "Starting VNC Server with Indian timezone (IST)..."
echo "Current time: $(TZ=Asia/Kolkata date)"
vncserver :1 -geometry 1280x720 -depth 24 -localhost no -name "Indian Desktop"
echo "✅ VNC running on display :1 (port 5901)"
echo "🔑 Password: coder123"
echo "🕐 Timezone: Asia/Kolkata (IST)"
EOF

# Create RDP start script
RUN cat > ~/start_rdp.sh << 'EOF'
#!/bin/bash
echo "Starting RDP Server with Indian timezone (IST)..."
echo "Current time: $(TZ=Asia/Kolkata date)"
sudo systemctl start xrdp
echo "✅ RDP running on port 3390"
echo "👤 Username: coder"
echo "🔑 Password: coder123"
echo "🇮🇳 Region: India (IST)"
EOF

# Create Indian welcome desktop file
RUN cat > ~/Desktop/WELCOME_INDIA.txt << 'EOF'
╔═══════════════════════════════════════════════════╗
║      🇮🇳 WELCOME TO INDIAN RDP DESKTOP 🇮🇳       ║
╚═══════════════════════════════════════════════════╝

📅 Timezone: Asia/Kolkata (IST)
🕐 Current Time: $(date)

🔧 Connection Information:
   • RDP Port: 3390
   • VNC Port: 5901  
   • VS Code Web: http://localhost:8080

👤 Login Credentials:
   • Username: coder
   • Password: coder123

🌐 Available Applications:
   • Firefox Web Browser
   • Terminal
   • VS Code (via browser)
   • File Manager

🚀 Quick Start Commands:
   • ./start_rdp.sh    - Start RDP server
   • ./start_vnc.sh    - Start VNC server
   • ./setup_tunnel.sh - Setup external access

📞 Support:
   • Timezone: Asia/Kolkata
   • Language: English
   • Check logs: ~/logs/
EOF

# ============================================================================
# INSTALL CLOUDFLARED FOR TUNNELING
# ============================================================================
RUN mkdir -p ~/.local/bin && \
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -O ~/.local/bin/cloudflared && \
    chmod +x ~/.local/bin/cloudflared

# Create tunnel setup script
RUN cat > ~/setup_tunnel.sh << 'EOF'
#!/bin/bash
echo "🌐 CLOUDFLARE TUNNEL SETUP FOR INDIAN DESKTOP"
echo "=============================================="
echo "Timezone: Asia/Kolkata (IST)"
echo ""
echo "Steps to expose your Indian desktop:"
echo "1. Login to Cloudflare:"
echo "   ~/.local/bin/cloudflared tunnel login"
echo ""
echo "2. Create a tunnel:"
echo "   ~/.local/bin/cloudflared tunnel create india-desktop"
echo ""
echo "3. Create config:"
echo "   mkdir -p ~/.cloudflared"
echo '   cat > ~/.cloudflared/config.yml << "CONFIG"'
echo '   tunnel: YOUR_TUNNEL_ID'
echo '   credentials-file: /home/coder/.cloudflared/cert.pem'
echo '   ingress:'
echo '     - hostname: desktop.yourdomain.com'
echo '       service: rdp://localhost:3390'
echo '     - hostname: vscode.yourdomain.com'
echo '       service: http://localhost:8080'
echo '     - service: http_status:404'
echo '   CONFIG'
echo ""
echo "4. Run tunnel:"
echo "   ~/.local/bin/cloudflared tunnel run india-desktop"
echo ""
echo "🇮🇳 Your Indian desktop will be available at:"
echo "   RDP: desktop.yourdomain.com:3390"
echo "   VS Code: https://vscode.yourdomain.com"
EOF

RUN chmod +x ~/*.sh

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
# CREATE STARTUP SCRIPT WITH INDIAN TIMEZONE
# ============================================================================
RUN cat > ~/start_indian_desktop.sh << 'EOF'
#!/bin/bash
# Set Indian timezone
export TZ=Asia/Kolkata

echo "╔═══════════════════════════════════════════════════╗"
echo "║   🇮🇳 STARTING INDIAN RDP DESKTOP SERVER 🇮🇳    ║"
echo "║         Timezone: Asia/Kolkata (IST)             ║"
echo "║           Time: $(date)                         ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# Start VS Code
echo "🚀 Starting VS Code..."
code-server --bind-addr 0.0.0.0:8080 --auth none > ~/logs/vscode.log 2>&1 &

# Start RDP server
echo "🖥️  Starting RDP Server..."
sudo systemctl start xrdp

# Start VNC server
echo "🔌 Starting VNC Server..."
vncserver :1 -geometry 1280x720 -depth 24 -localhost no -name "Indian Desktop" > ~/logs/vnc.log 2>&1 &

# Configure Indian desktop
echo "🇮🇳 Configuring Indian desktop settings..."
bash ~/configure_indian_desktop.sh

echo ""
echo "✅ ALL SERVICES STARTED SUCCESSFULLY!"
echo ""
echo "🔗 ACCESS METHODS:"
echo "   1. VS Code Web: http://localhost:8080"
echo "   2. RDP Desktop: localhost:3390"
echo "      👤 Username: coder"
echo "      🔑 Password: coder123"
echo "   3. VNC Access: localhost:5901"
echo "      🔑 Password: coder123"
echo ""
echo "🛠️  AVAILABLE COMMANDS:"
echo "   ./start_rdp.sh      - Start RDP server"
echo "   ./start_vnc.sh      - Start VNC server"
echo "   ./setup_tunnel.sh   - Setup external access"
echo "   ./configure_indian_desktop.sh - Configure Indian settings"
echo ""
echo "📁 Check desktop for WELCOME_INDIA.txt file"
echo "=============================================="

# Keep container running
tail -f /dev/null
EOF

RUN chmod +x ~/start_indian_desktop.sh

# Create logs directory
RUN mkdir -p ~/logs

# ============================================================================
# EXPOSE PORTS
# ============================================================================
EXPOSE 8080
EXPOSE 3390
EXPOSE 5901

# ============================================================================
# SET DEFAULT COMMAND
# ============================================================================
CMD ["bash", "-c", "./start_indian_desktop.sh"]
