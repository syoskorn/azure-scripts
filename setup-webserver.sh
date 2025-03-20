#!/bin/bash

# Create a log directory
mkdir -p /var/log/azure
echo "$(date): Starting web server installation and hardening" > /var/log/azure/webserver-setup.log

# Update packages
echo "$(date): Updating package lists" >> /var/log/azure/webserver-setup.log
apt-get update -y

# Install Nginx
echo "$(date): Installing Nginx" >> /var/log/azure/webserver-setup.log
apt-get install -y nginx

# Enable Nginx to start on boot
echo "$(date): Enabling Nginx to start on boot" >> /var/log/azure/webserver-setup.log
systemctl enable nginx

# Create a custom index page
echo "$(date): Creating custom index page" >> /var/log/azure/webserver-setup.log
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Secure Azure VM</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        h1 { color: #0066cc; }
        .container { max-width: 800px; margin: 0 auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Hello from Secure Azure VM!</h1>
        <p>This server was deployed using an ARM template with security hardening.</p>
        <p>Deployment time: $(date)</p>
    </div>
</body>
</html>
EOF

# Security hardening steps

# 1. Configure firewall (UFW)
echo "$(date): Installing and configuring UFW firewall" >> /var/log/azure/webserver-setup.log
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
echo "y" | ufw enable

# 2. Secure Nginx configuration
echo "$(date): Hardening Nginx configuration" >> /var/log/azure/webserver-setup.log
cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;  # Don't show Nginx version

    # MIME types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip settings
    gzip on;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";

    # Virtual host configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# 3. Create a specific server configuration
echo "$(date): Creating server configuration" >> /var/log/azure/webserver-setup.log
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Deny access to .htaccess files
    location ~ /\.ht {
        deny all;
    }
}
EOF

# 4. Apply system security hardening
echo "$(date): Applying system security hardening" >> /var/log/azure/webserver-setup.log

# Update sshd_config to disable root login
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Install fail2ban to protect against brute force attacks
apt-get install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# Install unattended-upgrades for automatic security updates
apt-get install -y unattended-upgrades apt-listchanges
echo 'Unattended-Upgrade::Allowed-Origins:: "Ubuntu bionic-security";' > /etc/apt/apt.conf.d/51unattended-upgrades-custom
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

# Restart Nginx to apply changes
echo "$(date): Restarting Nginx" >> /var/log/azure/webserver-setup.log
systemctl restart nginx

# Final status check
echo "$(date): Checking Nginx status" >> /var/log/azure/webserver-setup.log
nginx_status=$(systemctl is-active nginx)
if [ "$nginx_status" = "active" ]; then
    echo "$(date): INSTALLATION SUCCESSFUL - Nginx is running" >> /var/log/azure/webserver-setup.log
else
    echo "$(date): INSTALLATION FAILED - Nginx is not running" >> /var/log/azure/webserver-setup.log
fi

echo "$(date): Web server setup complete" >> /var/log/azure/webserver-setup.log
