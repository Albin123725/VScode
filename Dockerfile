FROM ubuntu:22.04

# Install everything
RUN apt-get update && \
    apt-get install -y \
    curl wget git sudo \
    xfce4 xfce4-goodies xfce4-terminal \
    xrdp xorgxrdp \
    tightvncserver \
    x11vnc xvfb \
    firefox chromium-browser \
    python3 python3-pip \
    htop neofetch vim nano \
    net-tools iputils-ping \
    unzip zip \
    && rm -rf /var/lib/apt/lists/*

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Create user
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder123" | chpasswd && \
    usermod -aG sudo coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder

# Configure RDP
RUN echo "xfce4-session" > /home/coder/.xsession && \
    chown coder:coder /home/coder/.xsession

RUN sed -i 's/port=3389/port=3390/g' /etc/xrdp/xrdp.ini

# Setup VNC
RUN mkdir -p /home/coder/.vnc && \
    echo "coder123" | vncpasswd -f > /home/coder/.vnc/passwd && \
    chown -R coder:coder /home/coder/.vnc && \
    chmod 600 /home/coder/.vnc/passwd

# Switch to user
USER coder
WORKDIR /home/coder

# Create VNC script
RUN cat > ~/start_vnc.sh << 'EOF'
#!/bin/bash
vncserver :1 -geometry 1280x720 -depth 24 -localhost no
echo "VNC: localhost:5901, Password: coder123"
EOF

# Create RDP script
RUN cat > ~/start_rdp.sh << 'EOF'
#!/bin/bash
sudo systemctl start xrdp
echo "RDP: localhost:3390, User: coder, Pass: coder123"
EOF

# Create desktop shortcuts
RUN cat > ~/create_desktop.sh << 'EOF'
#!/bin/bash
mkdir -p ~/Desktop
cat > ~/Desktop/vscode.desktop << 'DESKTOP'
[Desktop Entry]
Name=VS Code
Exec=firefox http://localhost:8080
Type=Application
DESKTOP
cat > ~/Desktop/terminal.desktop << 'DESKTOP'
[Desktop Entry]
Name=Terminal
Exec=xfce4-terminal
Type=Application
DESKTOP
chmod +x ~/Desktop/*.desktop
echo "Desktop shortcuts created"
EOF

# Install cloudflared
RUN mkdir -p ~/.local/bin && \
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -O ~/.local/bin/cloudflared && \
    chmod +x ~/.local/bin/cloudflared

# Create tunnel script
RUN cat > ~/setup_tunnel.sh << 'EOF'
#!/bin/bash
echo "CLOUDFLARE TUNNEL SETUP"
echo ""
echo "1. Login: ~/.local/bin/cloudflared tunnel login"
echo "2. Create: ~/.local/bin/cloudflared tunnel create rdp-tunnel"
echo "3. Run: ~/.local/bin/cloudflared tunnel run rdp-tunnel"
echo ""
echo "Then connect via RDP client to your tunnel URL"
EOF

RUN chmod +x ~/*.sh

# VS Code config
RUN mkdir -p ~/.config/code-server
RUN echo 'bind-addr: 0.0.0.0:8080' > ~/.config/code-server/config.yaml
RUN echo 'auth: none' >> ~/.config/code-server/config.yaml

# Startup script
RUN cat > ~/start.sh << 'EOF'
#!/bin/bash
echo "Starting RDP Desktop + VS Code..."

# Start VS Code
code-server --bind-addr 0.0.0.0:8080 --auth none &

# Start RDP
sudo systemctl start xrdp

# Start VNC
vncserver :1 -geometry 1280x720 -depth 24 -localhost no &

echo ""
echo "✅ Services Started!"
echo ""
echo "🔗 Access URLs:"
echo "VS Code: http://localhost:8080"
echo "RDP: localhost:3390 (User: coder, Pass: coder123)"
echo "VNC: localhost:5901 (Pass: coder123)"
echo ""
echo "🛠️  Commands:"
echo "./setup_tunnel.sh - Setup Cloudflare tunnel"
echo "./start_vnc.sh   - Start VNC server"
echo "./start_rdp.sh   - Start RDP server"
echo ""

tail -f /dev/null
EOF

RUN chmod +x ~/start.sh

# Expose ports
EXPOSE 8080
EXPOSE 3390
EXPOSE 5901

# Default command
CMD ["bash", "-c", "./start.sh"]
