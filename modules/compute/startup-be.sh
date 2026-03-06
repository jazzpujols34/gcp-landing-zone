#!/bin/bash
# Backend startup script — Flask API that connects to Cloud SQL

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

# Read project ID from metadata
PROJECT_ID=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/project/project-id || echo "unknown")

cat > app.py <<'PYEOF'
import os
import socket
import traceback
from flask import Flask, jsonify

app = Flask(__name__)

HOSTNAME = socket.gethostname()
DB_HOST = os.environ.get("DB_HOST", "127.0.0.1")
PROJECT_ID = os.environ.get("PROJECT_ID", "unknown")

def get_db_connection():
    """Try to connect to Cloud SQL via private IP."""
    try:
        import psycopg2
        conn = psycopg2.connect(
            host=DB_HOST,
            port=5432,
            dbname="app",
            user="app",
            password=get_db_password(),
            connect_timeout=5
        )
        return conn
    except Exception:
        return None

def get_db_password():
    """Read DB password from Secret Manager."""
    try:
        from google.cloud import secretmanager
        client = secretmanager.SecretManagerServiceClient()
        env = os.environ.get("ENVIRONMENT", "demo")
        name = f"projects/{PROJECT_ID}/secrets/db-password-{env}/versions/latest"
        response = client.access_secret_version(request={"name": name})
        return response.payload.data.decode("UTF-8")
    except Exception:
        return os.environ.get("DB_PASSWORD", "")

@app.route("/health")
def health():
    return jsonify({"status": "ok", "instance": HOSTNAME, "tier": "backend"})

@app.route("/api/health")
def api_health():
    result = {
        "status": "ok",
        "instance": HOSTNAME,
        "tier": "backend",
        "db_host": DB_HOST,
        "project": PROJECT_ID,
        "db_connected": False,
    }

    conn = get_db_connection()
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT version();")
            version = cur.fetchone()[0]
            result["db_connected"] = True
            result["db_version"] = version.split(",")[0]  # e.g. "PostgreSQL 15.x"
            cur.close()
            conn.close()
        except Exception as e:
            result["db_error"] = str(e)
    else:
        result["db_error"] = "Could not connect to Cloud SQL"

    return jsonify(result)

@app.route("/api/info")
def info():
    """Full system info — proves every tier is connected."""
    import platform
    return jsonify({
        "hostname": HOSTNAME,
        "platform": platform.platform(),
        "python": platform.python_version(),
        "db_host": DB_HOST,
        "project": PROJECT_ID,
        "architecture": {
            "frontend": "nginx on GCE (public subnet)",
            "backend": f"Flask on GCE (private subnet) - {HOSTNAME}",
            "database": f"Cloud SQL PostgreSQL (private IP: {DB_HOST})",
            "networking": "VPC + Cloud NAT + Global LB",
            "security": "IAM least-privilege + Secret Manager",
        }
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
PYEOF

# Set environment variables for the app
cat > /etc/systemd/system/backend.service <<SVCEOF
[Unit]
Description=Backend API
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/app
Environment=DB_HOST=${DB_HOST}
Environment=PROJECT_ID=${PROJECT_ID}
Environment=ENVIRONMENT=demo
ExecStart=/opt/app/venv/bin/python app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable backend
systemctl start backend
