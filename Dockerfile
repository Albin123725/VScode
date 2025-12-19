# ============================================================================
# MINECRAFT VS CODE - WORKING VERSION
# ============================================================================
FROM ubuntu:22.04

# ============================================================================
# SYSTEM SETUP (AS ROOT)
# ============================================================================
RUN apt-get update && \
    apt-get install -y \
    curl wget git \
    python3 python3-pip \
    openjdk-17-jre-headless \
    unzip zip \
    htop nano vim \
    net-tools iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# INSTALL CODE-SERVER (AS ROOT)
# ============================================================================
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ============================================================================
# CREATE USER AND SWITCH
# ============================================================================
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder123" | chpasswd

USER coder
WORKDIR /home/coder

# ============================================================================
# CREATE DIRECTORIES
# ============================================================================
RUN mkdir -p \
    .local/bin \
    .config/code-server \
    minecraft/server \
    minecraft/backup \
    minecraft/logs \
    logs

# ============================================================================
# DOWNLOAD MINECRAFT SERVER
# ============================================================================
RUN cd minecraft/server && \
    wget -q "https://api.papermc.io/v2/projects/paper/versions/1.21.10/builds/127/downloads/paper-1.21.10-127.jar" -O paper.jar && \
    echo "eula=true" > eula.txt

# Create server.properties
RUN cat > minecraft/server/server.properties << 'EOF'
max-players=20
server-port=25565
online-mode=false
motd=Render Minecraft Server
gamemode=survival
difficulty=normal
view-distance=10
EOF

# ============================================================================
# CREATE MINECRAFT START SCRIPT
# ============================================================================
RUN cat > start_minecraft.sh << 'EOF'
#!/bin/bash
echo "========================================"
echo "STARTING MINECRAFT SERVER"
echo "========================================"
echo "Version: PaperMC 1.21.10"
echo "Port: 25565"
echo "RAM: ${MC_RAM:-2G}"
echo "========================================"

cd ~/minecraft/server
java -Xms1G -Xmx${MC_RAM:-2G} -jar paper.jar --nogui
EOF

RUN chmod +x start_minecraft.sh

# ============================================================================
# CREATE MINECRAFT UPDATE SCRIPT
# ============================================================================
RUN cat > update_minecraft.sh << 'EOF'
#!/bin/bash
echo "Checking for Minecraft updates..."
cd ~/minecraft/server

# Backup current
if [ -f "paper.jar" ]; then
    cp paper.jar "paper_backup_$(date +%Y%m%d_%H%M%S).jar"
fi

# Get latest build
LATEST_BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/1.21.10" | \
    grep -o '"builds":\[[0-9,]*\]' | grep -o '[0-9][0-9,]*' | tr ',' '\n' | tail -1)

if [ -n "$LATEST_BUILD" ]; then
    echo "Latest build: $LATEST_BUILD"
    
    # Download new version
    wget -q "https://api.papermc.io/v2/projects/paper/versions/1.21.10/builds/$LATEST_BUILD/downloads/paper-1.21.10-$LATEST_BUILD.jar" -O paper_new.jar
    
    if [ -f "paper_new.jar" ]; then
        mv paper_new.jar paper.jar
        echo "Updated to PaperMC 1.21.10 build $LATEST_BUILD"
    else
        echo "Download failed"
    fi
else
    echo "Could not fetch latest version"
fi
EOF

RUN chmod +x update_minecraft.sh

# ============================================================================
# DOWNLOAD CLOUDFLARED
# ============================================================================
# Download cloudflared to user bin directory
RUN wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -O .local/bin/cloudflared && \
    chmod +x .local/bin/cloudflared

# Create tunnel setup script
RUN cat > setup_tunnel.sh << 'EOF'
#!/bin/bash
echo "CLOUDFLARE TUNNEL SETUP"
echo "========================"
echo ""
echo "1. To login to Cloudflare:"
echo "   ~/.local/bin/cloudflared tunnel login"
echo ""
echo "2. To create a tunnel:"
echo "   ~/.local/bin/cloudflared tunnel create minecraft-tunnel"
echo ""
echo "3. Create config file:"
echo "   mkdir -p ~/.cloudflared"
echo "   cat > ~/.cloudflared/config.yml << 'CONFIG'"
echo "   tunnel: YOUR_TUNNEL_ID"
echo "   credentials-file: /home/coder/.cloudflared/cert.pem"
echo "   ingress:"
echo "     - hostname: minecraft.example.com"
echo "       service: tcp://localhost:25565"
echo "     - hostname: vscode.example.com"
echo "       service: http://localhost:8080"
echo "     - service: http_status:404"
echo "   CONFIG"
echo ""
echo "4. Run the tunnel:"
echo "   ~/.local/bin/cloudflared tunnel run minecraft-tunnel"
EOF

RUN chmod +x setup_tunnel.sh

# ============================================================================
# CREATE MANAGEMENT DASHBOARD
# ============================================================================
RUN cat > manage.py << 'EOF'
#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler
import subprocess
import json
import os

class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            html = '''
            <!DOCTYPE html>
            <html>
            <head>
                <title>Minecraft Server Manager</title>
                <style>
                    body { font-family: Arial; margin: 40px; background: #f0f0f0; }
                    .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }
                    button { padding: 10px 20px; margin: 5px; background: #4CAF50; color: white; border: none; border-radius: 5px; cursor: pointer; }
                    button:hover { background: #45a049; }
                    .log { background: #333; color: #0f0; padding: 10px; border-radius: 5px; font-family: monospace; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>🎮 Minecraft Server Control Panel</h1>
                    
                    <div>
                        <h2>Server Control</h2>
                        <button onclick="sendCommand('start')">▶ Start Server</button>
                        <button onclick="sendCommand('stop')">⏹ Stop Server</button>
                        <button onclick="sendCommand('update')">🔄 Update Server</button>
                        <button onclick="sendCommand('status')">📊 Check Status</button>
                    </div>
                    
                    <div style="margin-top: 20px;">
                        <h2>Connection Info</h2>
                        <p><strong>VS Code:</strong> <a href="http://localhost:8080" target="_blank">http://localhost:8080</a></p>
                        <p><strong>Minecraft Server:</strong> localhost:25565</p>
                        <p><strong>RAM:</strong> <input type="text" id="ram" value="2G" placeholder="e.g., 2G, 3G"></p>
                    </div>
                    
                    <div id="output" class="log"></div>
                </div>
                
                <script>
                async function sendCommand(cmd) {
                    const ram = document.getElementById('ram').value;
                    const response = await fetch('/command', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({command: cmd, ram: ram})
                    });
                    const data = await response.json();
                    document.getElementById('output').textContent = data.message;
                }
                </script>
            </body>
            </html>
            '''
            self.wfile.write(html.encode())
        else:
            super().do_GET()
    
    def do_POST(self):
        if self.path == '/command':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode())
            
            response = {'success': True, 'message': 'Command executed'}
            
            if data['command'] == 'start':
                ram = data.get('ram', '2G')
                os.environ['MC_RAM'] = ram
                subprocess.Popen(['bash', '-c', 'cd ~ && ./start_minecraft.sh > ~/logs/minecraft.log 2>&1 &'])
                response['message'] = f'Starting Minecraft server with {ram} RAM...'
            
            elif data['command'] == 'stop':
                subprocess.run(['pkill', '-f', 'paper.jar'])
                response['message'] = 'Stopping Minecraft server...'
            
            elif data['command'] == 'update':
                result = subprocess.run(['bash', '-c', './update_minecraft.sh'], capture_output=True, text=True)
                response['message'] = result.stdout
            
            elif data['command'] == 'status':
                result = subprocess.run(['ps', 'aux', '|', 'grep', 'paper.jar'], capture_output=True, text=True, shell=True)
                if 'paper.jar' in result.stdout:
                    response['message'] = 'Server is running\n' + result.stdout
                else:
                    response['message'] = 'Server is not running'
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())

print("Starting Minecraft Manager on http://localhost:8081")
HTTPServer(('0.0.0.0', 8081), Handler).serve_forever()
EOF

RUN chmod +x manage.py

# ============================================================================
# VS CODE CONFIGURATION
# ============================================================================
RUN cat > .config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080
auth: none
cert: false
disable-telemetry: true
disable-update-check: true
EOF

# ============================================================================
# STARTUP SCRIPT
# ============================================================================
RUN cat > start_services.sh << 'EOF'
#!/bin/bash
echo "========================================"
echo "MINECRAFT VS CODE SERVER"
echo "========================================"

# Start code-server
echo "Starting VS Code..."
code-server --bind-addr 0.0.0.0:8080 --auth none &

# Start management dashboard
echo "Starting Manager Dashboard..."
python3 manage.py &

echo ""
echo "✅ Services Started Successfully!"
echo ""
echo "🔗 Access URLs:"
echo "   VS Code:      http://localhost:8080"
echo "   Manager:      http://localhost:8081"
echo "   Minecraft:    localhost:25565"
echo ""
echo "🛠️  Quick Commands:"
echo "   Start Minecraft:  ./start_minecraft.sh"
echo "   Update Server:    ./update_minecraft.sh"
echo "   Setup Tunnel:     ./setup_tunnel.sh"
echo "   View Logs:        tail -f ~/logs/minecraft.log"
echo ""
echo "========================================"

# Keep container running
tail -f /dev/null
EOF

RUN chmod +x start_services.sh

# ============================================================================
# EXPOSE PORTS
# ============================================================================
EXPOSE 8080
EXPOSE 8081
EXPOSE 25565

# ============================================================================
# DEFAULT COMMAND
# ============================================================================
CMD ["bash", "-c", "./start_services.sh"]
