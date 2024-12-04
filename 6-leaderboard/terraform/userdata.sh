#!/bin/bash
# Update packages
apt-get update -y
apt-get upgrade -y

# Install Nginx and Node.js
apt-get install -y nginx
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt-get install -y nodejs
mkdir -p /var/www/html

# Configure Nginx
cat > /etc/nginx/sites-available/default <<-EOL
server {
    listen 80;

    # Serve HTML
    location / {
        root /var/www/html;
        index index.html;
    }

    # Proxy Node.js
    location /api/ {
        rewrite ^/api(/.*)$ \$1 break;
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL
systemctl restart nginx
npm install -g pm2
