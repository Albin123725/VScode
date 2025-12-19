#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import os
import json

class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            # Check if code-server is running
            if os.system("pgrep -x code-server > /dev/null") == 0:
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = {
                    "status": "healthy",
                    "services": {
                        "code-server": "running",
                        "system": "operational"
                    }
                }
                self.wfile.write(json.dumps(response).encode())
            else:
                self.send_response(503)
                self.end_headers()
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>Cloud Terminal</h1><p>VS Code Server is running</p>')
    
    def log_message(self, format, *args):
        # Disable logging to keep console clean
        pass

# Create health check directory
os.makedirs("/home/coder/health-check", exist_ok=True)
with open("/home/coder/health-check/index.html", "w") as f:
    f.write("<h1>Cloud Terminal Health Check</h1><p>Service is running</p>")

# Start server
server = HTTPServer(('0.0.0.0', 8081), HealthHandler)
print("Health check server running on port 8081")
server.serve_forever()
