# ============================================================================
# MINECRAFT VS CODE ON RENDER - USER SPACE SETUP
# ============================================================================
FROM ubuntu:22.04

# Basic configuration
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install system dependencies
RUN apt-get update && \
    apt-get install -y \
    curl wget git python3 python3-pip \
    unzip zip nano vim htop \
    net-tools iputils-ping dnsutils \
    screen tmux \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create user FIRST (before code-server install)
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder123" | chpasswd

# ============================================================================
# INSTALL VS CODE SERVER AS ROOT
# ============================================================================
# Install code-server system-wide
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ============================================================================
# SWITCH TO CODER USER
# ============================================================================
USER coder
WORKDIR /home/coder

# ============================================================================
# SETUP LOCAL DIRECTORIES
# ============================================================================
RUN mkdir -p \
    ~/.local/{bin,lib,share,opt,cloudflared} \
    ~/.config/code-server \
    ~/logs

# ============================================================================
# INSTALL JAVA 21 (USER SPACE)
# ============================================================================
RUN mkdir -p ~/.local/java && \
    cd ~/.local/java && \
    wget -q "https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.tar.gz" -O java.tar.gz && \
    tar -xzf java.tar.gz --strip-components=1 && \
    rm java.tar.gz && \
    echo "Java 21 installed in ~/.local/java"

# ============================================================================
# MINECRAFT SERVER INSTALLATION
# ============================================================================
# Create Minecraft directory structure
RUN mkdir -p \
    ~/minecraft/{server,backup,plugins,logs,worlds,configs} \
    ~/minecraft/server/plugins

# Download PaperMC 1.21.10 build 127
RUN cd ~/minecraft/server && \
    echo "Downloading PaperMC 1.21.10 build 127..." && \
    wget -q "https://api.papermc.io/v2/projects/paper/versions/1.21.10/builds/127/downloads/paper-1.21.10-127.jar" -O paper.jar && \
    echo "Minecraft server downloaded"

# Create server.properties
RUN cat > ~/minecraft/server/server.properties << 'EOF'
max-players=20
server-port=25565
online-mode=false
server-ip=0.0.0.0
motd=Render Minecraft Server
gamemode=survival
difficulty=normal
pvp=true
view-distance=8
simulation-distance=6
spawn-protection=0
max-tick-time=60000
enable-rcon=false
enable-command-block=true
player-idle-timeout=0
EOF

# Create eula.txt
RUN echo "eula=true" > ~/minecraft/server/eula.txt

# ============================================================================
# MINECRAFT STARTUP SCRIPTS
# ============================================================================
# Main start script
RUN cat > ~/minecraft/start.sh << 'EOF'
#!/bin/bash
cd ~/minecraft/server

echo "========================================"
echo "STARTING MINECRAFT SERVER"
echo "========================================"
echo "Version: PaperMC 1.21.10 build 127"
echo "Port: 25565"
echo "RAM: ${MC_RAM:-3G}"
echo "Java: $(java --version | head -1)"
echo "========================================"

# Use custom Java from user space
export JAVA_HOME="$HOME/.local/java"
export PATH="$JAVA_HOME/bin:$PATH"

# Start server
java -Xms1G -Xmx${MC_RAM:-3G} -jar paper.jar --nogui
EOF

# Minecraft update script
RUN cat > ~/minecraft/update.sh << 'EOF'
#!/bin/bash
echo "Checking for Minecraft updates..."
cd ~/minecraft/server

# Get latest build
LATEST_BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/1.21.10" | grep -o '"builds":\[[0-9,]*\]' | grep -o '[0-9][0-9,]*' | tr ',' '\n' | tail -1)

if [ -n "$LATEST_BUILD" ] && [ "$LATEST_BUILD" -gt 127 ]; then
    echo "New build available: $LATEST_BUILD"
    
    # Backup
    cp paper.jar "paper_backup_$(date +%Y%m%d_%H%M%S).jar"
    
    # Download new version
    wget -q "https://api.papermc.io/v2/projects/paper/versions/1.21.10/builds/$LATEST_BUILD/downloads/paper-1.21.10-$LATEST_BUILD.jar" -O paper_new.jar
    
    if [ -f "paper_new.jar" ]; then
        mv paper_new.jar paper.jar
        echo "Updated to PaperMC 1.21.10 build $LATEST_BUILD"
    else
        echo "Download failed, keeping version 127"
    fi
else
    echo "Already on latest version"
fi
EOF

# Make scripts executable
RUN chmod +x ~/minecraft/*.sh

# ============================================================================
# CLOUDFLARED INSTALLATION
# ============================================================================
RUN cd ~/.local/cloudflared && \
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" && \
    chmod +x cloudflared

# Create tunnel setup script
RUN cat > ~/setup_tunnel.sh << 'EOF'
#!/bin/bash
echo "CLOUDFLARE TUNNEL SETUP"
echo "========================"

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

echo "Config created: ~/.cloudflared/config.yml"
echo ""
echo "Next steps:"
echo "1. ~/.local/cloudflared/cloudflared tunnel login"
echo "2. ~/.local/cloudflared/cloudflared tunnel create minecraft-tunnel"
echo "3. Configure DNS in Cloudflare dashboard"
echo "4. ~/.local/cloudflared/cloudflared tunnel run minecraft-tunnel"
EOF

RUN chmod +x ~/setup_tunnel.sh

# ============================================================================
# VS CODE CONFIGURATION
# ============================================================================
RUN cat > ~/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080
auth: none
cert: false
disable-telemetry: true
disable-update-check: true
EOF

# ============================================================================
# STARTUP SCRIPT
# ============================================================================
RUN cat > ~/start_services.sh << 'EOF'
#!/bin/bash
echo "Starting Minecraft VS Code..."

# Start code-server
code-server --bind-addr 0.0.0.0:8080 --auth none &

# Create simple management script
cat > ~/manage.py << 'PYTHON'
from http.server import HTTPServer, BaseHTTPRequestHandler
import subprocess
import json

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        html = '''
        <html>
        <body>
            <h1>Minecraft Server Control</h1>
            <button onclick="start()">Start Server</button>
            <button onclick="stop()">Stop Server</button>
            <script>
            async function start() {
                await fetch('/start', {method: 'POST'});
                alert('Starting server...');
            }
            async function stop() {
                await fetch('/stop', {method: 'POST'});
                alert('Stopping server...');
            }
            </script>
        </body>
        </html>
        '''
        self.wfile.write(html.encode())
    
    def do_POST(self):
        if self.path == '/start':
            subprocess.Popen(['bash', '-c', 'cd ~/minecraft && ./start.sh > logs/minecraft.log 2>&1 &'])
        elif self.path == '/stop':
            subprocess.run(['pkill', '-f', 'paper.jar'])
        self.send_response(200)
        self.end_headers()

print("Starting manager on port 8081...")
HTTPServer(('0.0.0.0', 8081), Handler).serve_forever()
PYTHON

# Start manager
python3 ~/manage.py &

echo ""
echo "Services started!"
echo "VS Code: http://localhost:8080"
echo "Manager: http://localhost:8081"
echo "Minecraft: localhost:25565"
echo ""
echo "To start Minecraft: cd ~/minecraft && ./start.sh"

# Keep container running
tail -f /dev/null
EOF

RUN chmod +x ~/start_services.sh

# ============================================================================
# EXPOSE PORTS
# ============================================================================
EXPOSE 8080
EXPOSE 8081
EXPOSE 25565

# ============================================================================
# SET DEFAULT COMMAND
# ============================================================================
CMD ["bash", "-c", "~/start_services.sh"]
