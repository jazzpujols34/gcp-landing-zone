#!/bin/bash
# Backend startup script — simple Flask API that connects to Cloud SQL

set -e

apt-get update -y
apt-get install -y python3 python3-pip python3-venv

# Create app directory
mkdir -p /opt/app
cd /opt/app

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

pip install flask psycopg2-binary google-cloud-secret-manager

# Read DB IP from instance metadata
DB_HOST=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/db-private-ip || echo "127.0.0.1")

cat > app.py <<PYEOF
import os
import socket
from flask import Flask, jsonify

app = Flask(__name__)

HOSTNAME = socket.gethostname()

@app.route("/health")
def health():
    return jsonify({"status": "ok", "instance": HOSTNAME, "tier": "backend"})

@app.route("/api/health")
def api_health():
    return jsonify({"status": "ok", "instance": HOSTNAME, "db_host": "${DB_HOST}"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
PYEOF

# Run as systemd service
cat > /etc/systemd/system/backend.service <<SVCEOF
[Unit]
Description=Backend API
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/app
ExecStart=/opt/app/venv/bin/python app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable backend
systemctl start backend
