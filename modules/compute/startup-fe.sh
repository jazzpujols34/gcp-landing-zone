#!/bin/bash
# Frontend startup script — installs nginx with a styled dashboard

set -e

apt-get update -y
apt-get install -y nginx

INSTANCE_NAME=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name || echo "unknown")
INSTANCE_ZONE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | awk -F/ '{print $NF}' || echo "unknown")
PROJECT_ID=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id || echo "unknown")

cat > /var/www/html/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>GCP Landing Zone</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
      background: #0a0f1e;
      color: #e2e8f0;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 2rem 1rem;
    }
    .header {
      text-align: center;
      margin-bottom: 2.5rem;
    }
    .header h1 {
      font-size: 2rem;
      font-weight: 700;
      background: linear-gradient(135deg, #60a5fa, #a78bfa);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 0.5rem;
    }
    .header p {
      color: #64748b;
      font-size: 0.95rem;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 1.25rem;
      max-width: 900px;
      width: 100%;
      margin-bottom: 2rem;
    }
    .card {
      background: #111827;
      border: 1px solid rgba(255,255,255,0.06);
      border-radius: 12px;
      padding: 1.5rem;
      transition: border-color 0.2s;
    }
    .card:hover { border-color: rgba(96,165,250,0.3); }
    .card-label {
      font-size: 0.75rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: #64748b;
      margin-bottom: 0.75rem;
    }
    .card-value {
      font-size: 1.1rem;
      font-weight: 600;
      color: #f1f5f9;
      word-break: break-all;
    }
    .card-sub {
      font-size: 0.8rem;
      color: #475569;
      margin-top: 0.35rem;
    }
    .status-dot {
      display: inline-block;
      width: 8px;
      height: 8px;
      border-radius: 50%;
      margin-right: 6px;
      position: relative;
      top: -1px;
    }
    .status-green { background: #22c55e; box-shadow: 0 0 6px rgba(34,197,94,0.4); }
    .status-yellow { background: #eab308; box-shadow: 0 0 6px rgba(234,179,8,0.4); }
    .status-red { background: #ef4444; box-shadow: 0 0 6px rgba(239,68,68,0.4); }
    .arch {
      max-width: 900px;
      width: 100%;
      background: #111827;
      border: 1px solid rgba(255,255,255,0.06);
      border-radius: 12px;
      padding: 1.5rem;
      margin-bottom: 2rem;
    }
    .arch h2 {
      font-size: 0.85rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: #64748b;
      margin-bottom: 1rem;
    }
    .arch pre {
      font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
      font-size: 0.8rem;
      color: #94a3b8;
      line-height: 1.6;
      overflow-x: auto;
    }
    .arch .highlight { color: #60a5fa; }
    .arch .highlight-green { color: #22c55e; }
    .arch .highlight-purple { color: #a78bfa; }
    .footer {
      color: #334155;
      font-size: 0.8rem;
      text-align: center;
      margin-top: auto;
      padding-top: 2rem;
    }
    .footer a { color: #475569; text-decoration: none; }
    .footer a:hover { color: #60a5fa; }
    @media (max-width: 640px) {
      .header h1 { font-size: 1.5rem; }
      .grid { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>

  <div class="header">
    <h1>GCP Landing Zone</h1>
    <p>3-tier architecture deployed with Terraform</p>
  </div>

  <div class="grid">
    <div class="card">
      <div class="card-label">Frontend Tier</div>
      <div class="card-value">
        <span class="status-dot status-green"></span>nginx
      </div>
      <div class="card-sub" id="fe-instance">Loading...</div>
    </div>

    <div class="card">
      <div class="card-label">Backend Tier</div>
      <div class="card-value">
        <span class="status-dot status-yellow" id="be-dot"></span>
        <span id="be-status">Checking...</span>
      </div>
      <div class="card-sub" id="be-instance">Connecting to /api/health</div>
    </div>

    <div class="card">
      <div class="card-label">Database Tier</div>
      <div class="card-value">
        <span class="status-dot status-yellow" id="db-dot"></span>
        <span id="db-status">Checking...</span>
      </div>
      <div class="card-sub" id="db-info">Cloud SQL (PostgreSQL 15)</div>
    </div>

    <div class="card">
      <div class="card-label">Load Balancer</div>
      <div class="card-value">
        <span class="status-dot status-green"></span>Global HTTPS LB
      </div>
      <div class="card-sub">Cloud CDN enabled</div>
    </div>

    <div class="card">
      <div class="card-label">Network</div>
      <div class="card-value">VPC + Cloud NAT</div>
      <div class="card-sub">Public + Private subnets</div>
    </div>

    <div class="card">
      <div class="card-label">Security</div>
      <div class="card-value">IAM + Secret Manager</div>
      <div class="card-sub">Least-privilege service accounts</div>
    </div>
  </div>

  <div class="arch">
    <h2>Architecture</h2>
    <pre>
  <span class="highlight">Internet</span>
      |
  <span class="highlight">Global HTTPS Load Balancer</span> + Cloud CDN
      |
  +---+---+
  |       |
<span class="highlight-green">nginx</span>   <span class="highlight-purple">Flask API</span>        &lt;-- You are here
  |       |
  |   +---+---+
  |   |       |
  | <span class="highlight-purple">Cloud SQL</span> <span class="highlight-green">Cloud Storage</span>
  | (private)  (IAM-controlled)
  |   |
  +---+
  <span class="highlight">Cloud NAT</span> (outbound)</pre>
  </div>

  <div class="footer">
    <p>Deployed with Terraform &middot; 7 modules &middot; 54 resources</p>
    <p style="margin-top: 0.4rem;">
      <a href="https://github.com/jazzpujols34/gcp-landing-zone" target="_blank">View on GitHub</a>
    </p>
  </div>

  <script>
    // Populate frontend instance info from page (set by startup script)
    document.getElementById('fe-instance').textContent =
      document.querySelector('meta[name="instance"]')?.content || 'Instance metadata unavailable';

    // Check backend health
    fetch('/api/health')
      .then(r => r.json())
      .then(data => {
        document.getElementById('be-dot').className = 'status-dot status-green';
        document.getElementById('be-status').textContent = 'Flask API';
        document.getElementById('be-instance').textContent = data.instance || 'Connected';

        if (data.db_host && data.db_host !== '127.0.0.1') {
          document.getElementById('db-dot').className = 'status-dot status-green';
          document.getElementById('db-status').textContent = 'PostgreSQL 15';
          document.getElementById('db-info').textContent = 'Private IP: ' + data.db_host;
        }

        if (data.db_connected) {
          document.getElementById('db-dot').className = 'status-dot status-green';
          document.getElementById('db-status').textContent = 'PostgreSQL 15';
          document.getElementById('db-info').textContent = data.db_version || ('Private IP: ' + data.db_host);
        }
      })
      .catch(() => {
        document.getElementById('be-dot').className = 'status-dot status-red';
        document.getElementById('be-status').textContent = 'Unreachable';
        document.getElementById('be-instance').textContent = 'Backend may still be starting up';
        document.getElementById('db-dot').className = 'status-dot status-red';
        document.getElementById('db-status').textContent = 'Unknown';
      });
  </script>

</body>
</html>
HTMLEOF

# Inject instance metadata into the page
sed -i "s|Loading...</div>|${INSTANCE_NAME} (${INSTANCE_ZONE})</div>\n  <meta name=\"instance\" content=\"${INSTANCE_NAME}\">|" /var/www/html/index.html

systemctl enable nginx
systemctl restart nginx
