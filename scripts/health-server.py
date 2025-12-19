#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import subprocess

class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            try:
                result = subprocess.run(['pgrep', '-x', 'code-server'], 
                                      capture_output=True, text=True)
                if result.returncode == 0:
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    response = {"status": "healthy", "service": "VS Code Terminal"}
                    self.wfile.write(json.dumps(response).encode())
                else:
                    self.send_response(503)
                    self.end_headers()
            except:
                self.send_response(500)
                self.end_headers()
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>VS Code Cloud Terminal</h1><p>Health check OK</p>')
    
    def log_message(self, format, *args):
        pass

if __name__ == "__main__":
    server = HTTPServer(('0.0.0.0', 8081), HealthHandler)
    server.serve_forever()
