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
# INSTALL EVERYTHING
# ============================================================================
RUN apt-get update && \
    apt-get install -y \
    curl wget git sudo tzdata locales \
    xfce4 xfce4-goodies xfce4-terminal \
    xrdp xorgxrdp \
    tightvncserver \
    x11vnc xvfb \
    firefox chromium-browser \
    python3 python3-pip \
    htop vim nano \
    net-tools iputils-ping \
    unzip zip \
    && rm -rf /var/lib/apt/lists/*

# Set Indian timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# ============================================================================
# INSTALL CODE-SERVER
# ============================================================================
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ============================================================================
# CREATE USER
# ============================================================================
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder123" | chpasswd && \
    usermod -aG sudo coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder

# ============================================================================
# CONFIGURE RDP SERVER
# ============================================================================
RUN echo "xfce4-session" > /home/coder/.xsession && \
    chown coder:coder /home/coder/.xsession

RUN sed -i 's/port=3389/port=3390/g' /etc/xrdp/xrdp.ini

# Setup VNC
RUN mkdir -p /home/coder/.vnc && \
    echo "coder123" | vncpasswd -f > /home/coder/.vnc/passwd && \
    chown -R coder:coder /home/coder/.vnc && \
    chmod 600 /home/coder/.vnc/passwd

# ============================================================================
# SWITCH TO USER
# ============================================================================
USER coder
WORKDIR /home/coder

# Set Indian locale
RUN echo "export TZ=Asia/Kolkata" >> ~/.bashrc

# Create VNC start script
RUN cat > ~/start_vnc.sh << 'EOF'
#!/bin/bash
vncserver :1 -geometry 1280x720 -depth 24 -localhost no
echo "VNC running on port 5901"
echo "Password: coder123"
EOF

# Create RDP start script
RUN cat > ~/start_rdp.sh << 'EOF'
#!/bin/bash
sudo systemctl start xrdp
echo "RDP running on port 3390"
echo "Username: coder"
echo "Password: coder123"
EOF

# Create welcome file WITHOUT special characters
RUN cat > ~/Desktop/WELCOME.txt << 'EOF'
=================================================
    INDIAN RDP DESKTOP SERVER
=================================================

Timezone: Asia/Kolkata (IST)

Connection Information:
- RDP Port: 3390
- VNC Port: 5901
- VS Code Web: http://localhost:8080

Login Credentials:
- Username: coder
- Password: coder123

Available Applications:
- Firefox Web Browser
- Terminal
- VS Code (via browser)
- File Manager

Quick Start Commands:
- ./start_rdp.sh    - Start RDP server
- ./start_vnc.sh    - Start VNC server
- ./setup_tunnel.sh - Setup external access

Support:
- Timezone: Asia/Kolkata
- Language: English
- Check logs: ~/logs/
EOF

# ============================================================================
# INSTALL CLOUDFLARED
# ============================================================================
RUN mkdir -p ~/.local/bin && \
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -O ~/.local/bin/cloudflared && \
    chmod +x ~/.local/bin/cloudflared

# Create tunnel script
RUN cat > ~/setup_tunnel.sh << 'EOF'
#!/bin/bash
echo "CLOUDFLARE TUNNEL SETUP"
echo ""
echo "1. Login: ~/.local/bin/cloudflared tunnel login"
echo "2. Create: ~/.local/bin/cloudflared tunnel create india-desktop"
echo "3. Run: ~/.local/bin/cloudflared tunnel run india-desktop"
EOF

RUN chmod +x ~/*.sh

# ============================================================================
# VS CODE CONFIG
# ============================================================================
RUN mkdir -p ~/.config/code-server
RUN echo 'bind-addr: 0.0.0.0:8080' > ~/.config/code-server/config.yaml
RUN echo 'auth: none' >> ~/.config/code-server/config.yaml

# ============================================================================
# CREATE STARTUP SCRIPT
# ============================================================================
RUN cat > ~/start_services.sh << 'EOF'
#!/bin/bash
echo "================================================"
echo "   INDIAN RDP DESKTOP SERVER"
echo "   Timezone: Asia/Kolkata"
echo "================================================"

# Start VS Code
code-server --bind-addr 0.0.0.0:8080 --auth none &

# Start RDP
sudo systemctl start xrdp

# Start VNC
vncserver :1 -geometry 1280x720 -depth 24 -localhost no &

echo ""
echo "Services started!"
echo ""
echo "Access URLs:"
echo "VS Code: http://localhost:8080"
echo "RDP: localhost:3390"
echo "VNC: localhost:5901"
echo ""
echo "Username: coder"
echo "Password: coder123"
echo ""

tail -f /dev/null
EOF

RUN chmod +x ~/start_services.sh

# Create logs directory
RUN mkdir -p ~/logs

# ============================================================================
# EXPOSE PORTS
# ============================================================================
EXPOSE 8080
EXPOSE 3390
EXPOSE 5901

# ============================================================================
# DEFAULT COMMAND
# ============================================================================
CMD ["bash", "-c", "./start_services.sh"]
