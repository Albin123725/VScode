# ============================================================================
# VS CODE WITH 30GB RAM MINECRAFT SERVER
# ============================================================================
FROM ubuntu:22.04

# ============================================================================
# INSTALL EVERYTHING AS ROOT
# ============================================================================
RUN apt-get update && \
    apt-get install -y \
    curl wget git \
    openjdk-21-jdk openjdk-21-jre \
    python3 python3-pip python3-venv \
    htop neofetch vim nano tmux screen \
    net-tools iputils-ping dnsutils \
    unzip zip \
    software-properties-common \
    ca-certificates gnupg lsb-release \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# INSTALL CODE-SERVER
# ============================================================================
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ============================================================================
# CREATE USER WITH PROPER PERMISSIONS
# ============================================================================
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder123" | chpasswd

USER coder
WORKDIR /home/coder

# ============================================================================
# SETUP MINECRAFT SERVER WITH 30GB RAM CAPABILITY
# ============================================================================
# Create Minecraft directory
RUN mkdir -p ~/minecraft-30gb/server
RUN mkdir -p ~/minecraft-30gb/{backup,logs,plugins,worlds}

# Download PaperMC 1.21.10 build 127
RUN cd ~/minecraft-30gb/server && \
    wget -q "https://api.papermc.io/v2/projects/paper/versions/1.21.10/builds/127/downloads/paper-1.21.10-127.jar" -O paper.jar

# Create optimized server.properties for high RAM
RUN cat > ~/minecraft-30gb/server/server.properties << 'EOF'
# 30GB RAM MINECRAFT SERVER CONFIG
max-players=100
server-port=25565
server-ip=0.0.0.0
online-mode=false
motd=30GB RAM Render Server | Paper 1.21.10
gamemode=survival
difficulty=normal
pvp=true
view-distance=16
simulation-distance=12
spawn-protection=0
max-tick-time=60000
enable-rcon=true
rcon.port=25575
rcon.password=render123
enable-command-block=true
player-idle-timeout=0
network-compression-threshold=512
use-native-transport=true
max-world-size=60000000
entity-broadcast-range-percentage=100
rate-limit=0
hardcore=false
white-list=false
force-gamemode=false
allow-nether=true
allow-flight=true
max-build-height=320
announce-player-achievements=true
enable-query=true
query.port=25565
generator-settings={}
level-type=minecraft:normal
resource-pack=
require-resource-pack=false
resource-pack-prompt=
EOF

# Accept EULA
RUN echo "eula=true" > ~/minecraft-30gb/server/eula.txt

# ============================================================================
# CREATE ADVANCED STARTUP SCRIPTS
# ============================================================================
# Main start script with 24GB RAM allocation
RUN cat > ~/start_minecraft_30gb.sh << 'EOF'
#!/bin/bash
clear
echo "================================================================"
echo "          30GB RAM MINECRAFT SERVER STARTUP"
echo "================================================================"
echo ""
echo "Available Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Allocating RAM: ${MINECRAFT_RAM:-24G} to Minecraft"
echo "Java Version: $(java --version | head -1)"
echo "Server Location: ~/minecraft-30gb/server"
echo "Port: 25565"
echo ""
echo "Starting server with optimized JVM flags..."
echo "================================================================"

cd ~/minecraft-30gb/server

# Start with optimized JVM flags for high RAM
java -Xms8G -Xmx${MINECRAFT_RAM:-24G} \
  -XX:+UseG1GC \
  -XX:+ParallelRefProcEnabled \
  -XX:MaxGCPauseMillis=150 \
  -XX:+UnlockExperimentalVMOptions \
  -XX:+DisableExplicitGC \
  -XX:+AlwaysPreTouch \
  -XX:G1NewSizePercent=30 \
  -XX:G1MaxNewSizePercent=40 \
  -XX:G1HeapRegionSize=8M \
  -XX:G1ReservePercent=20 \
  -XX:InitiatingHeapOccupancyPercent=15 \
  -Dusing.aikars.flags=true \
  -Daikars.new.flags=true \
  -jar paper.jar \
  --nogui
EOF

# Quick start script (simple)
RUN cat > ~/minecraft_start.sh << 'EOF'
#!/bin/bash
cd ~/minecraft-30gb/server
java -Xms8G -Xmx24G -jar paper.jar --nogui
EOF

# Monitor script
RUN cat > ~/minecraft_monitor.sh << 'EOF'
#!/bin/bash
echo "=== 30GB MINECRAFT SERVER MONITOR ==="
echo ""
echo "SYSTEM RESOURCES:"
echo "Total RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "Used RAM: $(free -h | grep Mem | awk '{print $3}')"
echo "Free RAM: $(free -h | grep Mem | awk '{print $4}')"
echo "CPU Cores: $(nproc)"
echo ""
echo "MINECRAFT STATUS:"
if pgrep -f paper.jar > /dev/null; then
    PID=$(pgrep -f paper.jar)
    echo "Server is RUNNING (PID: $PID)"
    echo "RAM Usage: $(ps -p $PID -o rss= | awk '{printf "%.2f GB\n", $1/1024/1024}')"
    echo "Uptime: $(ps -p $PID -o etime=)"
    
    # Check if RCON is responding
    if timeout 2 nc -z localhost 25575; then
        echo "RCON Port (25575) is open"
    fi
else
    echo "Server is STOPPED"
fi
echo ""
echo "NETWORK PORTS:"
netstat -tulpn | grep -E "(25565|25575)" || echo "No Minecraft ports listening"
EOF

# Backup script
RUN cat > ~/minecraft_backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR=~/minecraft-30gb/backup/$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"
echo "Creating backup to: $BACKUP_DIR"
cp -r ~/minecraft-30gb/server/world "$BACKUP_DIR/" 2>/dev/null || echo "No world to backup"
cp ~/minecraft-30gb/server/*.json "$BACKUP_DIR/" 2>/dev/null
cp ~/minecraft-30gb/server/server.properties "$BACKUP_DIR/" 2>/dev/null
cp ~/minecraft-30gb/server/paper.jar "$BACKUP_DIR/" 2>/dev/null
echo "Backup completed!"
EOF

# Update script
RUN cat > ~/minecraft_update.sh << 'EOF'
#!/bin/bash
echo "Checking for Minecraft updates..."
cd ~/minecraft-30gb/server

# Get latest build
LATEST_BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/1.21.10" | \
    grep -o '"builds":\[[0-9,]*\]' | grep -o '[0-9][0-9,]*' | tr ',' '\n' | tail -1)

if [ -n "$LATEST_BUILD" ] && [ "$LATEST_BUILD" -gt 127 ]; then
    echo "New build available: $LATEST_BUILD (current: 127)"
    
    # Backup
    ./../minecraft_backup.sh
    
    # Download new version
    wget -q "https://api.papermc.io/v2/projects/paper/versions/1.21.10/builds/$LATEST_BUILD/downloads/paper-1.21.10-$LATEST_BUILD.jar" -O paper_new.jar
    
    if [ -f "paper_new.jar" ]; then
        mv paper_new.jar paper.jar
        echo "Updated to PaperMC 1.21.10 build $LATEST_BUILD"
        echo "Restart server to apply update"
    else
        echo "Download failed"
    fi
else
    echo "Already on latest version"
fi
EOF

# Make all scripts executable
RUN chmod +x ~/*.sh

# ============================================================================
# INSTALL CLOUDFLARED FOR TUNNELING
# ============================================================================
RUN mkdir -p ~/.local/bin && \
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -O ~/.local/bin/cloudflared && \
    chmod +x ~/.local/bin/cloudflared

# Create tunnel setup script
RUN cat > ~/setup_minecraft_tunnel.sh << 'EOF'
#!/bin/bash
echo "CLOUDFLARE TUNNEL SETUP FOR MINECRAFT"
echo "========================================"
echo ""
echo "Steps to expose your 30GB Minecraft server:"
echo ""
echo "1. Login to Cloudflare:"
echo "   ~/.local/bin/cloudflared tunnel login"
echo ""
echo "2. Create a tunnel:"
echo "   ~/.local/bin/cloudflared tunnel create 30gb-minecraft"
echo ""
echo "3. Configure DNS in Cloudflare dashboard:"
echo "   Add CNAME: minecraft -> YOUR_TUNNEL_ID.cfargotunnel.com"
echo ""
echo "4. Create config file:"
echo "   mkdir -p ~/.cloudflared"
echo "   cat > ~/.cloudflared/config.yml << 'CONFIG'"
echo "   tunnel: YOUR_TUNNEL_ID"
echo "   credentials-file: /home/coder/.cloudflared/cert.pem"
echo "   ingress:"
echo "     - hostname: minecraft.yourdomain.com"
echo "       service: tcp://localhost:25565"
echo "     - service: http_status:404"
echo "   CONFIG"
echo ""
echo "5. Run the tunnel:"
echo "   ~/.local/bin/cloudflared tunnel run 30gb-minecraft"
echo ""
echo "Your 30GB Minecraft server will be available at:"
echo "   minecraft.yourdomain.com:25565"
EOF

RUN chmod +x ~/setup_minecraft_tunnel.sh

# ============================================================================
# CREATE VS CODE CONFIG
# ============================================================================
RUN mkdir -p ~/.config/code-server
RUN cat > ~/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080
auth: none
cert: false
disable-telemetry: true
disable-update-check: true
disable-workspace-trust: true
disable-getting-started-override: true
EOF

# ============================================================================
# CREATE STARTUP INFO
# ============================================================================
RUN cat > ~/WELCOME.md << 'EOF'
# 30GB RAM MINECRAFT VS CODE SERVER

## MINECRAFT SERVER COMMANDS:

### Start Minecraft (with 24GB RAM):
./start_minecraft_30gb.sh

### Quick Start:
./minecraft_start.sh

### Monitor Server:
./minecraft_monitor.sh

### Update Server:
./minecraft_update.sh

### Create Backup:
./minecraft_backup.sh

### Setup Cloudflare Tunnel:
./setup_minecraft_tunnel.sh

## SERVER SPECS:
- Total RAM: 30GB
- Minecraft RAM: 24GB allocated
- Players: Up to 100 players
- View Distance: 16 chunks
- Port: 25565 (Minecraft), 25575 (RCON)

## OPTIMIZED FOR HIGH RAM:
- G1GC Garbage Collector
- Parallel processing enabled
- Large heap regions (8MB)
- Minimal GC pauses
- Aikars optimized JVM flags

## EXTERNAL ACCESS:
1. Run ./setup_minecraft_tunnel.sh
2. Follow Cloudflare setup instructions
3. Connect via: minecraft.yourdomain.com:25565

## SERVER LOCATION:
- Directory: ~/minecraft-30gb/server/
- Config: server.properties
- Logs: Auto-saved to console
EOF

# ============================================================================
# STARTUP SCRIPT
# ============================================================================
RUN cat > ~/start_all.sh << 'EOF'
#!/bin/bash
echo "================================================================"
echo "      VS CODE + 30GB MINECRAFT SERVER STARTED"
echo "================================================================"
echo ""
echo "System Resources:"
echo "   RAM: $(free -h | grep Mem | awk '{print $2}') total"
echo "   CPU: $(nproc) cores"
echo "   Java: $(java --version | head -1)"
echo ""
echo "Access URLs:"
echo "   VS Code:      http://localhost:8080"
echo "   Minecraft:    localhost:25565"
echo "   RCON:         localhost:25575 (password: render123)"
echo ""
echo "Available Minecraft Commands:"
echo "   ./start_minecraft_30gb.sh     - Start with 24GB RAM"
echo "   ./minecraft_monitor.sh        - Check server status"
echo "   ./minecraft_update.sh         - Update to latest version"
echo "   ./setup_minecraft_tunnel.sh   - Setup external access"
echo ""
echo "Documentation: cat ~/WELCOME.md"
echo "================================================================"

# Start code-server
code-server --bind-addr 0.0.0.0:8080 --auth none &

# Keep container running
tail -f /dev/null
EOF

RUN chmod +x ~/start_all.sh

# ============================================================================
# EXPOSE PORTS
# ============================================================================
EXPOSE 8080
EXPOSE 25565
EXPOSE 25575

# ============================================================================
# DEFAULT COMMAND
# ============================================================================
CMD ["bash", "-c", "./start_all.sh"]
