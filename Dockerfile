# ============================================================================
# MINECRAFT VS CODE ON RENDER - USER SPACE SETUP
# ============================================================================
FROM ubuntu:22.04

# Basic configuration
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV HOME=/home/coder
ENV PATH="$HOME/.local/java/jdk-21.0.2/bin:$HOME/.local/cloudflared:$HOME/.local/bin:$PATH"

# Install system dependencies (no sudo needed)
RUN apt-get update && \
    apt-get install -y \
    curl wget git python3 python3-pip \
    unzip zip nano vim htop \
    net-tools iputils-ping dnsutils \
    screen tmux \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder123" | chpasswd

# Switch to coder user
USER coder
WORKDIR /home/coder

# ============================================================================
# INSTALL VS CODE SERVER
# ============================================================================
RUN curl -fsSL https://code-server.dev/install.sh | sh

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
    wget -q "https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.tar.gz" && \
    tar -xzf jdk-21_linux-x64_bin.tar.gz --strip-components=1 && \
    rm jdk-21_linux-x64_bin.tar.gz && \
    echo "✅ Java 21 installed in ~/.local/java"

# ============================================================================
# MINECRAFT SERVER INSTALLATION
# ============================================================================
# Create Minecraft directory structure
RUN mkdir -p \
    ~/minecraft/{server,backup,plugins,logs,worlds,configs} \
    ~/minecraft/server/plugins

# Download PaperMC 1.21.10 build 127
RUN cd ~/minecraft/server && \
    echo "📥 Downloading PaperMC 1.21.10 build 127..." && \
    wget -q "https://api.papermc.io/v2/projects/paper/versions/1.21.10/builds/127/downloads/paper-1.21.10-127.jar" -O paper.jar && \
    echo "✅ Minecraft server downloaded"

# Create server.properties with optimized settings
RUN cat > ~/minecraft/server/server.properties << 'EOF'
# 🎮 Minecraft Server on Render
max-players=20
server-port=25565
online-mode=false
server-ip=0.0.0.0
motd=\u00A7bRender Minecraft \u00A7f\u2022 \u00A7a24/7 \u00A7f\u2022 \u00A7ePaper 1.21.10
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
network-compression-threshold=256
use-native-transport=true
enable-jmx-monitoring=false
enable-status=true
broadcast-rcon-to-ops=true
broadcast-console-to-ops=true
max-world-size=29999984
function-permission-level=2
entity-broadcast-range-percentage=100
rate-limit=0
hardcore=false
white-list=false
enforce-whitelist=false
spawn-npcs=true
spawn-animals=true
spawn-monsters=true
generate-structures=true
announce-player-achievements=true
max-build-height=256
force-gamemode=false
resource-pack=
resource-pack-sha1=
require-resource-pack=false
resource-pack-prompt=
allow-flight=true
allow-nether=true
enable-query=false
query.port=25565
prevent-proxy-connections=false
server-portv6=25566
use-native-transport=true
enable-rcon=false
rcon.port=25575
rcon.password=
level-seed=
level-type=minecraft\:normal
generator-settings=
op-permission-level=4
EOF

# Create eula.txt (auto-accept)
RUN echo "eula=true" > ~/minecraft/server/eula.txt

# Create ops.json with default op
RUN echo '[{"uuid":"00000000-0000-0000-0000-000000000000","name":"Admin","level":4,"bypassesPlayerLimit":false}]' > ~/minecraft/server/ops.json

# Create whitelist.json
RUN echo '[]' > ~/minecraft/server/whitelist.json

# Create banned-players.json
RUN echo '[]' > ~/minecraft/server/banned-players.json

# Create banned-ips.json
RUN echo '[]' > ~/minecraft/server/banned-ips.json

# ============================================================================
# MINECRAFT STARTUP SCRIPTS
# ============================================================================
# Main start script
RUN cat > ~/minecraft/start.sh << 'EOF'
#!/bin/bash
cd ~/minecraft/server

echo "========================================"
echo "🎮 STARTING MINECRAFT SERVER"
echo "========================================"
echo "Version: PaperMC 1.21.10 build 127"
echo "Port: 25565"
echo "RAM: ${MC_RAM:-3G}"
echo "Java: $(java --version | head -1)"
echo "========================================"

# Use custom Java from user space
export JAVA_HOME="$HOME/.local/java"
export PATH="$JAVA_HOME/bin:$PATH"

# Start server with optimized flags
java -Xms1G -Xmx${MC_RAM:-3G} \
     -XX:+UseG1GC \
     -XX:+ParallelRefProcEnabled \
     -XX:MaxGCPauseMillis=200 \
     -XX:+UnlockExperimentalVMOptions \
     -XX:+DisableExplicitGC \
     -XX:+AlwaysPreTouch \
     -XX:G1NewSizePercent=30 \
     -XX:G1MaxNewSizePercent=40 \
     -XX:G1HeapRegionSize=8M \
     -XX:G1ReservePercent=20 \
     -XX:G1HeapWastePercent=5 \
     -XX:InitiatingHeapOccupancyPercent=15 \
     -Dusing.aikars.flags=true \
     -Daikars.new.flags=true \
     -jar paper.jar \
     --nogui
EOF

# Minecraft update script (checks for new builds)
RUN cat > ~/minecraft/update.sh << 'EOF'
#!/bin/bash
echo "🔄 Checking for Minecraft updates..."

cd ~/minecraft/server
BACKUP_FILE="paper_backup_$(date +%Y%m%d_%H%M%S).jar"

# Backup current server
if [ -f "paper.jar" ]; then
    cp paper.jar "$BACKUP_FILE"
    echo "📦 Backup created: $BACKUP_FILE"
fi

# Get latest build for Paper 1.21.10
echo "📡 Fetching latest build info..."
LATEST_BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/1.21.10" | grep -o '"builds":\[[0-9,]*\]' | grep -o '[0-9][0-9,]*' | tr ',' '\n' | tail -1)

if [ -n "$LATEST_BUILD" ] && [ "$LATEST_BUILD" -gt 127 ]; then
    echo "✅ New build available: $LATEST_BUILD (current: 127)"
    
    # Download new version
    echo "⬇️ Downloading PaperMC 1.21.10 build $LATEST_BUILD..."
    wget -q "https://api.papermc.io/v2/projects/paper/versions/1.21.10/builds/$LATEST_BUILD/downloads/paper-1.21.10-$LATEST_BUILD.jar" -O paper_new.jar
    
    if [ -f "paper_new.jar" ]; then
        # Test if jar is valid
        if java -jar paper_new.jar --version > /dev/null 2>&1; then
            mv paper_new.jar paper.jar
            echo "🎉 Updated to PaperMC 1.21.10 build $LATEST_BUILD"
            echo "🔄 Restart server to apply update"
            
            # Update server.properties version note
            sed -i "s/Paper 1.21.10/Paper 1.21.10 build $LATEST_BUILD/" server.properties
        else
            echo "❌ Downloaded file is corrupted, keeping version 127"
            rm -f paper_new.jar
        fi
    else
        echo "❌ Download failed, keeping version 127"
    fi
else
    echo "✅ Already on latest version (build 127)"
fi

echo "========================================"
echo "📊 Current files:"
ls -la paper*.jar 2>/dev/null || echo "No jar files found"
echo "========================================"
EOF

# Minecraft backup script
RUN cat > ~/minecraft/backup.sh << 'EOF'
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/minecraft/backup/world_$TIMESTAMP"

echo "💾 Creating backup..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup world if exists
if [ -d "world" ]; then
    cp -r world "$BACKUP_DIR/"
    echo "✅ World backed up to: $BACKUP_DIR"
fi

# Backup server configs
cp server.properties "$BACKUP_DIR/" 2>/dev/null
cp ops.json "$BACKUP_DIR/" 2>/dev/null
cp paper.jar "$BACKUP_DIR/" 2>/dev/null

echo "📦 Backup complete!"
echo "📁 Location: $BACKUP_DIR"
EOF

# Make scripts executable
RUN chmod +x ~/minecraft/*.sh

# ============================================================================
# CLOUDFLARED INSTALLATION (USER SPACE)
# ============================================================================
RUN cd ~/.local/cloudflared && \
    echo "📥 Downloading cloudflared..." && \
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" && \
    chmod +x cloudflared && \
    ~/.local/cloudflared/cloudflared --version && \
    echo "✅ Cloudflared installed"

# Create tunnel setup script
RUN cat > ~/setup_tunnel.sh << 'EOF'
#!/bin/bash
echo "🌐 CLOUDFLARE TUNNEL SETUP"
echo "=========================="

# Create config directory
mkdir -p ~/.cloudflared

# Create config file
cat > ~/.cloudflared/config.yml << 'CONFIG'
tunnel: minecraft-tunnel
credentials-file: /home/coder/.cloudflared/cert.pem

ingress:
  # Minecraft server (TCP)
  - hostname: minecraft.yourdomain.com
    service: tcp://localhost:25565

  # VS Code (HTTP)
  - hostname: vscode.yourdomain.com
    service: http://localhost:8080
    originRequest:
      noTLSVerify: true

  # Catch-all rule
  - service: http_status:404
CONFIG

echo "✅ Config created: ~/.cloudflared/config.yml"
echo ""
echo "📋 SETUP INSTRUCTIONS:"
echo "1. Login to Cloudflare:"
echo "   ~/.local/cloudflared/cloudflared tunnel login"
echo ""
echo "2. Create tunnel (if not exists):"
echo "   ~/.local/cloudflared/cloudflared tunnel create minecraft-tunnel"
echo ""
echo "3. Configure DNS (in Cloudflare dashboard):"
echo "   Add CNAME: minecraft -> tunnel-id.cfargotunnel.com"
echo "   Add CNAME: vscode -> tunnel-id.cfargotunnel.com"
echo ""
echo "4. Run tunnel:"
echo "   ~/.local/cloudflared/cloudflared tunnel run minecraft-tunnel"
echo ""
echo "🌐 Your services will be available at:"
echo "   Minecraft: minecraft.yourdomain.com:25565"
echo "   VS Code:   https://vscode.yourdomain.com"
EOF

RUN chmod +x ~/setup_tunnel.sh

# ============================================================================
# MANAGEMENT DASHBOARD
# ============================================================================
RUN cat > ~/manage_server.py << 'EOF'
#!/usr/bin/env python3
"""
Minecraft Server Manager Dashboard
Access at: http://localhost:8082
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import subprocess
import json
import os
import threading
import time

SERVER_PROCESS = None
SERVER_STATUS = "stopped"

class ManagerHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            html = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>🎮 Minecraft Server Manager</title>
                <style>
                    body { font-family: Arial; margin: 40px; background: #1a1a2e; color: white; }
                    .container { max-width: 800px; margin: 0 auto; }
                    .card { background: #162447; padding: 20px; border-radius: 10px; margin: 20px 0; }
                    button { padding: 12px 24px; margin: 5px; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; }
                    .start { background: #2ecc71; color: white; }
                    .stop { background: #e74c3c; color: white; }
                    .update { background: #3498db; color: white; }
                    .backup { background: #9b59b6; color: white; }
                    .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
                    .online { background: #27ae60; }
                    .offline { background: #7f8c8d; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>🎮 Minecraft Server Manager</h1>
                    
                    <div class="card">
                        <h2>Server Control</h2>
                        <div id="status" class="status offline">Status: Stopped</div>
                        <button class="start" onclick="controlServer('start')">▶ Start Server</button>
                        <button class="stop" onclick="controlServer('stop')">⏹ Stop Server</button>
                        <button class="update" onclick="controlServer('update')">🔄 Check Updates</button>
                        <button class="backup" onclick="controlServer('backup')">💾 Create Backup</button>
                    </div>
                    
                    <div class="card">
                        <h2>Quick Commands</h2>
                        <button onclick="runCommand('status')">📊 Check Status</button>
                        <button onclick="runCommand('logs')">📋 View Logs</button>
                        <button onclick="runCommand('players')">👥 Online Players</button>
                    </div>
                    
                    <div class="card">
                        <h2>Connection Info</h2>
                        <p><strong>Server Address:</strong> <code>localhost:25565</code></p>
                        <p><strong>VS Code:</strong> <a href="http://localhost:8080" target="_blank">http://localhost:8080</a></p>
                        <p><strong>RAM Allocation:</strong> <input type="text" id="ram" value="3G" placeholder="e.g., 2G, 4G"></p>
                    </div>
                    
                    <div id="output" style="background: #0f3460; padding: 15px; border-radius: 5px; margin-top: 20px; min-height: 100px;"></div>
                </div>
                
                <script>
                async function controlServer(action) {
                    const ram = document.getElementById('ram').value;
                    const response = await fetch('/' + action, {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({ram: ram})
                    });
                    const result = await response.json();
                    document.getElementById('output').innerHTML = '<pre>' + result.message + '</pre>';
                    updateStatus();
                }
                
                async function runCommand(cmd) {
                    const response = await fetch('/command', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({command: cmd})
                    });
                    const result = await response.json();
                    document.getElementById('output').innerHTML = '<pre>' + result.message + '</pre>';
                }
                
                async function updateStatus() {
                    const response = await fetch('/status');
                    const data = await response.json();
                    const statusDiv = document.getElementById('status');
                    statusDiv.textContent = 'Status: ' + data.status;
                    statusDiv.className = 'status ' + (data.status === 'online' ? 'online' : 'offline');
                }
                
                // Update status every 10 seconds
                setInterval(updateStatus, 10000);
                updateStatus();
                </script>
            </body>
            </html>
            """
            self.wfile.write(html.encode())
            
        elif self.path == '/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            # Check if server is running
            status = "offline"
            try:
                result = subprocess.run(['pgrep', '-f', 'paper.jar'], capture_output=True)
                if result.returncode == 0:
                    status = "online"
            except:
                pass
                
            self.wfile.write(json.dumps({'status': status}).encode())
            
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.read_body(content_length)
        
        response = {'success': False, 'message': 'Unknown command'}
        
        if self.path == '/start':
            ram = post_data.get('ram', '3G')
            os.environ['MC_RAM'] = ram
            subprocess.Popen(['bash', '-c', 'cd ~/minecraft && ./start.sh > ~/logs/minecraft.log 2>&1 &'])
            response = {'success': True, 'message': f'🚀 Starting Minecraft server with {ram} RAM...\nCheck logs: tail -f ~/logs/minecraft.log'}
            
        elif self.path == '/stop':
            subprocess.run(['pkill', '-f', 'paper.jar'])
            response = {'success': True, 'message': '🛑 Stopping Minecraft server...'}
            
        elif self.path == '/update':
            result = subprocess.run(['bash', '-c', 'cd ~/minecraft && ./update.sh'], capture_output=True, text=True)
            response = {'success': True, 'message': result.stdout}
            
        elif self.path == '/backup':
            result = subprocess.run(['bash', '-c', 'cd ~/minecraft && ./backup.sh'], capture_output=True, text=True)
            response = {'success': True, 'message': result.stdout}
            
        elif self.path == '/command':
            cmd = post_data.get('command', '')
            if cmd == 'status':
                result = subprocess.run(['ps', 'aux', '|', 'grep', 'paper.jar'], capture_output=True, text=True, shell=True)
                response = {'success': True, 'message': result.stdout or 'No server process found'}
            elif cmd == 'logs':
                result = subprocess.run(['tail', '-20', '~/logs/minecraft.log'], capture_output=True, text=True, shell=True)
                response = {'success': True, 'message': result.stdout or 'No logs found'}
            elif cmd == 'players':
                response = {'success': True, 'message': 'Player list feature requires server to be running with RCON enabled'}
                
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())
    
    def read_body(self, length):
        data = self.rfile.read(length)
        return json.loads(data.decode()) if data else {}

def start_manager():
    server = HTTPServer(('0.0.0.0', 8082), ManagerHandler)
    print("✅ Minecraft Manager running on http://localhost:8082")
    server.serve_forever()

if __name__ == '__main__':
    start_manager()
EOF

RUN chmod +x ~/manage_server.py

# ============================================================================
# VS CODE CONFIGURATION
# ============================================================================
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
# STARTUP SCRIPT
# ============================================================================
RUN cat > ~/start_services.sh << 'EOF'
#!/bin/bash
echo "========================================"
echo "🚀 MINECRAFT VS CODE - RENDER DEPLOYMENT"
echo "========================================"

# Start code-server (VS Code)
echo "💻 Starting VS Code..."
code-server --bind-addr 0.0.0.0:8080 --auth none > ~/logs/vscode.log 2>&1 &

# Start Minecraft manager dashboard
echo "📊 Starting Manager Dashboard..."
python3 ~/manage_server.py > ~/logs/manager.log 2>&1 &

# Create startup info
cat > ~/STARTUP_INFO.md << 'INFO'
# 🎮 Minecraft VS Code on Render

## 🔗 Access URLs:
- **VS Code Interface:** http://localhost:8080
- **Manager Dashboard:** http://localhost:8082
- **Minecraft Server:** localhost:25565

## 📋 Available Commands:

### Minecraft Server:
- Start: `cd ~/minecraft && MC_RAM=3G ./start.sh`
- Update: `cd ~/minecraft && ./update.sh`
- Backup: `cd ~/minecraft && ./backup.sh`
- Check status: `ps aux | grep paper.jar`

### Cloudflare Tunnel:
- Setup: `./setup_tunnel.sh`
- Run tunnel: `~/.local/cloudflared/cloudflared tunnel run minecraft-tunnel`

### Management:
- View logs: `tail -f ~/logs/minecraft.log`
- Manager UI: Open http://localhost:8082

## ⚙️ Configuration:
- Server RAM: Set with `MC_RAM` variable (default: 3G)
- Port: 25565 (internal), use Cloudflare for external access
- Auto-update: Run update.sh to get latest PaperMC builds

## 📞 Support:
- Check logs: ~/logs/
- Minecraft data: ~/minecraft/
- Config files: ~/minecraft/server/

INFO

echo ""
echo "✅ SERVICES STARTED SUCCESSFULLY!"
echo ""
echo "🌐 Access Points:"
echo "   VS Code:      http://localhost:8080"
echo "   Manager:      http://localhost:8082"
echo "   Minecraft:    localhost:25565"
echo ""
echo "📁 Files & Directories:"
echo "   Minecraft:    ~/minecraft/"
echo "   Server:       ~/minecraft/server/"
echo "   Logs:         ~/logs/"
echo "   Cloudflare:   ~/.local/cloudflared/"
echo ""
echo "🛠️  Quick Start:"
echo "   1. Open VS Code at: http://localhost:8080"
echo "   2. Open terminal (Ctrl+`)"
echo "   3. Start Minecraft: cd ~/minecraft && ./start.sh"
echo "   4. Setup tunnel: ./setup_tunnel.sh"
echo ""
echo "========================================"

# Keep container running
tail -f /dev/null
EOF

RUN chmod +x ~/start_services.sh

# ============================================================================
# EXPOSE PORTS - NO COMMENTS AFTER NUMBERS!
# ============================================================================
EXPOSE 8080
EXPOSE 8082
EXPOSE 25565

# ============================================================================
# SET DEFAULT COMMAND
# ============================================================================
CMD ["bash", "-c", "~/start_services.sh"]
