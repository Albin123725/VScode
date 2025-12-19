# ============================================================================
# WORKING MINECRAFT VS CODE FOR RENDER
# ============================================================================
FROM ubuntu:22.04

# ============================================================================
# INSTALL SYSTEM PACKAGES AS ROOT
# ============================================================================
RUN apt-get update && apt-get install -y \
    curl wget git \
    python3 python3-pip \
    openjdk-17-jre-headless \
    nano vim htop \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# INSTALL CODE-SERVER
# ============================================================================
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ============================================================================
# CREATE USER AND SETUP
# ============================================================================
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder123" | chpasswd

# Switch to coder user for remaining setup
USER coder
WORKDIR /home/coder

# ============================================================================
# CREATE DIRECTORIES
# ============================================================================
RUN mkdir -p \
    ~/.local/bin \
    ~/.config/code-server \
    ~/minecraft/server \
    ~/logs

# ============================================================================
# DOWNLOAD MINECRAFT SERVER
# ============================================================================
RUN cd ~/minecraft/server && \
    wget -q "https://api.papermc.io/v2/projects/paper/versions/1.21.10/builds/127/downloads/paper-1.21.10-127.jar" -O paper.jar

# Create eula.txt
RUN echo "eula=true" > ~/minecraft/server/eula.txt

# Create server.properties
RUN cat > ~/minecraft/server/server.properties << 'EOF'
max-players=20
server-port=25565
online-mode=false
motd=Render Minecraft Server
gamemode=survival
difficulty=normal
EOF

# ============================================================================
# CREATE MINECRAFT START SCRIPT
# ============================================================================
RUN cat > ~/start_minecraft.sh << 'EOF'
#!/bin/bash
cd ~/minecraft/server
echo "Starting Minecraft Server..."
echo "Version: PaperMC 1.21.10"
echo "Port: 25565"
echo "RAM: ${MC_RAM:-2G}"
java -Xms1G -Xmx${MC_RAM:-2G} -jar paper.jar --nogui
EOF

RUN chmod +x ~/start_minecraft.sh

# ============================================================================
# CREATE MINECRAFT UPDATE SCRIPT
# ============================================================================
RUN cat > ~/update_minecraft.sh << 'EOF'
#!/bin/bash
echo "Checking for Minecraft updates..."
cd ~/minecraft/server

# Get latest build
LATEST_BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/1.21.10" | \
    grep -o '"builds":\[[0-9,]*\]' | grep -o '[0-9][0-9,]*' | tr ',' '\n' | tail -1)

if [ -n "$LATEST_BUILD" ] && [ "$LATEST_BUILD" -gt 127 ]; then
    echo "New version available: build $LATEST_BUILD"
    echo "Backing up current server..."
    cp paper.jar "paper_backup_$(date +%Y%m%d_%H%M%S).jar"
    
    echo "Downloading new version..."
    wget -q "https://api.papermc.io/v2/projects/paper/versions/1.21.10/builds/$LATEST_BUILD/downloads/paper-1.21.10-$LATEST_BUILD.jar" -O paper_new.jar
    
    if [ -f "paper_new.jar" ]; then
        mv paper_new.jar paper.jar
        echo "Updated to PaperMC 1.21.10 build $LATEST_BUILD"
    else
        echo "Download failed, keeping current version"
    fi
else
    echo "Already on latest version (build 127)"
fi
EOF

RUN chmod +x ~/update_minecraft.sh

# ============================================================================
# DOWNLOAD CLOUDFLARED TO USER BIN
# ============================================================================
RUN cd ~/.local/bin && \
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -O cloudflared && \
    chmod +x cloudflared

# ============================================================================
# CREATE CLOUDFLARE SETUP SCRIPT
# ============================================================================
RUN cat > ~/setup_cloudflare.sh << 'EOF'
#!/bin/bash
echo "Cloudflare Tunnel Setup"
echo "======================="
mkdir -p ~/.cloudflared

cat > ~/.cloudflared/config.yml << 'CONFIG'
tunnel: minecraft-tunnel
credentials-file: /home/coder/.cloudflared/cert.pem
ingress:
  - hostname: minecraft.example.com
    service: tcp://localhost:25565
  - hostname: vscode.example.com
    service: http://localhost:8080
  - service: http_status:404
CONFIG

echo "Config created at ~/.cloudflared/config.yml"
echo ""
echo "To setup Cloudflare Tunnel:"
echo "1. Login: ~/.local/bin/cloudflared tunnel login"
echo "2. Create tunnel: ~/.local/bin/cloudflared tunnel create minecraft-tunnel"
echo "3. Run: ~/.local/bin/cloudflared tunnel run minecraft-tunnel"
EOF

RUN chmod +x ~/setup_cloudflare.sh

# ============================================================================
# CREATE VS CODE CONFIG
# ============================================================================
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
RUN cat > ~/startup.sh << 'EOF'
#!/bin/bash
echo "========================================"
echo "Minecraft VS Code Server"
echo "========================================"

# Start VS Code
code-server --bind-addr 0.0.0.0:8080 --auth none &

echo ""
echo "Services:"
echo "• VS Code: http://localhost:8080"
echo "• Minecraft: localhost:25565"
echo ""
echo "Commands:"
echo "• Start Minecraft: ~/start_minecraft.sh"
echo "• Update Minecraft: ~/update_minecraft.sh"
echo "• Setup Cloudflare: ~/setup_cloudflare.sh"
echo "========================================"

# Keep container running
tail -f /dev/null
EOF

RUN chmod +x ~/startup.sh

# ============================================================================
# EXPOSE PORTS
# ============================================================================
EXPOSE 8080
EXPOSE 25565

# ============================================================================
# DEFAULT COMMAND
# ============================================================================
CMD ["bash", "-c", "~/startup.sh"]
