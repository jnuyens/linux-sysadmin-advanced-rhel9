#!/usr/bin/env python3
"""
Simple Python web server for container exercises.
Returns system information and a greeting.
No external dependencies - uses only the standard library.
"""

import http.server
import json
import os
import socket
from datetime import datetime

PORT = 5000

class AppHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "healthy"}).encode())
            return

        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()

        hostname = socket.gethostname()
        response = f"""<html>
<head><title>Container App</title></head>
<body style="font-family: Georgia, serif; max-width: 600px; margin: 40px auto;">
    <h1>Hello from a Container!</h1>
    <p><strong>Hostname:</strong> {hostname}</p>
    <p><strong>Time:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
    <p><strong>Python:</strong> {os.sys.version.split()[0]}</p>
    <p><strong>User:</strong> {os.getuid()}</p>
    <p><strong>Working dir:</strong> {os.getcwd()}</p>
    <hr>
    <p><em>Advanced Linux Sysadmin - RHEL 9 - Chapter 4</em></p>
</body>
</html>"""
        self.wfile.write(response.encode())

    def log_message(self, format, *args):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {args[0]}")

if __name__ == '__main__':
    server = http.server.HTTPServer(('0.0.0.0', PORT), AppHandler)
    print(f"Server running on port {PORT}")
    server.serve_forever()
