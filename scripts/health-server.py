#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import os
import json
import subprocess

class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            # Check if code-server is running
            try:
                result = subprocess.run(['pgrep', '-x', 'code-server'], 
                                      capture_output=True, text=True)
                if result.returncode == 0:
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    response = {
                        "status": "healthy",
                        "service": "VS Code Cloud Terminal",
                        "timestamp": __import__('datetime').datetime.now().isoformat()
                    }
                    self.wfile.write(json.dumps(response).encode())
                else:
                    self.send_response(503)
                    self.end_headers()
            except:
                self.send_response(500)
                self.end_headers()
        elif self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>VS Code Cloud Terminal</h1><p>Service is running</p>')
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass

if __name__ == "__main__":
    port = 8081
    server = HTTPServer(('0.0.0.0', port), HealthHandler)
    print(f"Health check server running on port {port}")
    server.serve_forever()
