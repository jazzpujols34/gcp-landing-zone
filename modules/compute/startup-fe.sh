#!/bin/bash
# Frontend startup script — installs nginx with a simple landing page

set -e

apt-get update -y
apt-get install -y nginx

cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>GCP Landing Zone - Frontend</title></head>
<body>
  <h1>GCP Landing Zone Demo</h1>
  <p>Frontend tier running on GCE behind Global HTTPS Load Balancer.</p>
  <p>Instance: <span id="instance"></span></p>
  <script>
    fetch('/api/health').then(r => r.json()).then(d => {
      document.getElementById('instance').textContent = d.instance || 'N/A';
    }).catch(() => {
      document.getElementById('instance').textContent = 'Backend unreachable';
    });
  </script>
</body>
</html>
EOF

systemctl enable nginx
systemctl restart nginx
