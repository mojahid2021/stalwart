# Stalwart Configuration - Separate Admin and Mail Subdomains

This configuration example shows how to set up Stalwart with:
- Admin panel on: `admin.yourdomain.com`
- Mail services on: `mail.yourdomain.com`

## Prerequisites

- DNS records for both `admin.yourdomain.com` and `mail.yourdomain.com`
- TLS certificates for both domains
- Reverse proxy (Caddy or nginx)

## Configuration Files

### 1. Stalwart Configuration (`/opt/stalwart/etc/config.toml`)

```toml
#############################################
# Stalwart Configuration
# Mail: mail.yourdomain.com
# Admin: admin.yourdomain.com (via reverse proxy)
#############################################

# Server hostname for mail services
[server]
hostname = "mail.yourdomain.com"

# SMTP Listeners
[server.listener."smtp"]
bind = ["0.0.0.0:25"]
protocol = "smtp"

[server.listener."submission"]
bind = ["0.0.0.0:587"]
protocol = "smtp"

[server.listener."submissions"]
bind = ["0.0.0.0:465"]
protocol = "smtp"
tls.implicit = true

# IMAP Listeners
[server.listener."imap"]
bind = ["0.0.0.0:143"]
protocol = "imap"

[server.listener."imaptls"]
bind = ["0.0.0.0:993"]
protocol = "imap"
tls.implicit = true

# POP3 Listeners
[server.listener."pop3"]
bind = ["0.0.0.0:110"]
protocol = "pop3"

[server.listener."pop3s"]
bind = ["0.0.0.0:995"]
protocol = "pop3"
tls.implicit = true

# ManageSieve
[server.listener."sieve"]
bind = ["0.0.0.0:4190"]
protocol = "managesieve"

# HTTP Admin Interface (localhost only - behind reverse proxy)
[server.listener."http-admin"]
bind = ["127.0.0.1:8080"]
protocol = "http"
# Note: TLS handled by reverse proxy (Caddy/nginx)

# Storage Configuration
[storage]
data = "rocksdb"
fts = "rocksdb"
blob = "rocksdb"
lookup = "rocksdb"
directory = "internal"

[store."rocksdb"]
type = "rocksdb"
path = "/opt/stalwart/data"
compression = "lz4"

[directory."internal"]
type = "internal"
store = "rocksdb"

# Authentication
[authentication.fallback-admin]
user = "admin"
secret = "%{env:ADMIN_SECRET}%"

# Logging
[tracer."stdout"]
type = "stdout"
level = "info"
enable = true
```

### 2. Caddy Configuration (Recommended - `/etc/caddy/Caddyfile`)

```caddy
# Admin Panel - admin.yourdomain.com
admin.yourdomain.com {
    # Automatic HTTPS with Let's Encrypt
    reverse_proxy localhost:8080
    
    # Optional: Add security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
    }
    
    # Optional: Enable logging
    log {
        output file /var/log/caddy/admin.log
    }
}

# Mail services on mail.yourdomain.com use standard ports
# No proxy needed - Stalwart handles them directly
```

### 3. Nginx Configuration (Alternative - `/etc/nginx/sites-available/stalwart`)

```nginx
# Admin Panel - admin.yourdomain.com
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name admin.yourdomain.com;
    
    # TLS Configuration
    ssl_certificate /etc/letsencrypt/live/admin.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/admin.yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Reverse proxy to Stalwart admin
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name admin.yourdomain.com;
    return 301 https://$server_name$request_uri;
}
```

### 4. Docker Compose Configuration (`docker-compose.yml`)

```yaml
services:
  stalwart:
    build:
      context: .
      dockerfile: Dockerfile
    image: stalwart:production
    container_name: stalwart-production
    hostname: mail.yourdomain.com
    restart: always
    
    ports:
      # Admin on localhost only (behind reverse proxy)
      - "127.0.0.1:8080:8080"
      
      # Mail services on all interfaces
      - "25:25"      # SMTP
      - "587:587"    # Submission
      - "465:465"    # Submissions (TLS)
      - "143:143"    # IMAP
      - "993:993"    # IMAPS
      - "110:110"    # POP3
      - "995:995"    # POP3S
      - "4190:4190"  # ManageSieve
    
    volumes:
      - ./stalwart-data:/opt/stalwart/data
      - ./stalwart-logs:/opt/stalwart/logs
      - ./stalwart-config:/opt/stalwart/etc
      - ./config-separate-domains.toml:/opt/stalwart/etc/config.toml:ro
    
    environment:
      - ADMIN_SECRET=${ADMIN_SECRET:?ADMIN_SECRET required}
      - STALWART_PATH=/opt/stalwart
      - TZ=${TZ:-UTC}
    
    networks:
      - stalwart-net

networks:
  stalwart-net:
    driver: bridge
```

## DNS Configuration

```dns
# A Records
mail.yourdomain.com.        A       YOUR_SERVER_IP
admin.yourdomain.com.       A       YOUR_SERVER_IP
yourdomain.com.             A       YOUR_SERVER_IP

# MX Record (points to mail subdomain)
yourdomain.com.             MX 10   mail.yourdomain.com.

# SPF Record
yourdomain.com.             TXT     "v=spf1 mx ~all"

# DKIM Record (generate in admin panel)
default._domainkey.yourdomain.com. TXT "v=DKIM1; k=rsa; p=YOUR_PUBLIC_KEY"

# DMARC Record
_dmarc.yourdomain.com.      TXT     "v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"

# Autodiscover (points to mail subdomain)
autoconfig.yourdomain.com.  CNAME   mail.yourdomain.com.
autodiscover.yourdomain.com. CNAME  mail.yourdomain.com.
```

## Deployment Steps

### Step 1: Install Prerequisites

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Caddy (recommended)
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy

# OR install nginx (alternative)
# sudo apt install nginx
```

### Step 2: Configure DNS

Add all DNS records listed above to your DNS provider.

### Step 3: Deploy Stalwart

```bash
# Create directory structure
sudo mkdir -p /opt/stalwart
cd /opt/stalwart

# Clone repository
git clone https://github.com/stalwartlabs/stalwart.git
cd stalwart

# Copy this configuration
cp config-separate-domains.toml /opt/stalwart/config/

# Create environment file
cat > .env << 'EOF'
ADMIN_SECRET=YOUR_SECURE_PASSWORD_HERE
TZ=UTC
EOF

# Build and start
docker compose up -d
```

### Step 4: Configure Reverse Proxy

**For Caddy:**

```bash
# Edit Caddyfile
sudo nano /etc/caddy/Caddyfile
# Add the admin.yourdomain.com configuration shown above

# Restart Caddy
sudo systemctl restart caddy
```

**For nginx:**

```bash
# Create configuration
sudo nano /etc/nginx/sites-available/stalwart
# Add the nginx configuration shown above

# Enable site
sudo ln -s /etc/nginx/sites-available/stalwart /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx
```

### Step 5: Configure Firewall

```bash
sudo ufw allow 80/tcp    # HTTP (for Let's Encrypt)
sudo ufw allow 443/tcp   # HTTPS (admin panel)
sudo ufw allow 25/tcp    # SMTP
sudo ufw allow 587/tcp   # Submission
sudo ufw allow 465/tcp   # Submissions
sudo ufw allow 143/tcp   # IMAP
sudo ufw allow 993/tcp   # IMAPS
sudo ufw allow 110/tcp   # POP3
sudo ufw allow 995/tcp   # POP3S
sudo ufw allow 4190/tcp  # ManageSieve
sudo ufw enable
```

### Step 6: Verify Setup

```bash
# Test admin panel
curl -I https://admin.yourdomain.com

# Test SMTP
telnet mail.yourdomain.com 25

# Test IMAP
openssl s_client -connect mail.yourdomain.com:993 -servername mail.yourdomain.com

# Check Caddy/nginx logs
sudo journalctl -u caddy -f
# or
sudo tail -f /var/log/nginx/access.log
```

### Step 7: Access Admin Panel

- **Admin Panel**: https://admin.yourdomain.com
- **Login**: admin / YOUR_ADMIN_SECRET
- **Mail Server**: mail.yourdomain.com (for email clients)

## Benefits of This Setup

1. **Clear separation**: Admin and mail use different subdomains
2. **Better security**: Admin panel behind reverse proxy with additional security headers
3. **Easy TLS management**: Caddy handles certificates automatically
4. **Scalability**: Can move admin to different server if needed
5. **Professional appearance**: Users see different domains for different purposes

## Troubleshooting

**Admin panel not accessible:**
```bash
# Check if Stalwart is listening
docker ps
curl http://localhost:8080

# Check reverse proxy
sudo systemctl status caddy
# or
sudo systemctl status nginx

# Check logs
docker logs stalwart-production
```

**Mail not working:**
```bash
# Check DNS records
dig mail.yourdomain.com
dig -t MX yourdomain.com

# Test SMTP
telnet mail.yourdomain.com 25

# Check Stalwart logs
docker logs stalwart-production
```

**Certificate issues:**
```bash
# For Caddy (automatic)
sudo journalctl -u caddy -f

# For nginx (manual with certbot)
sudo certbot renew --dry-run
```

## Security Recommendations

1. **Use strong passwords** in .env file
2. **Enable rate limiting** in Caddy/nginx
3. **Configure Fail2ban** for brute force protection
4. **Regular updates**: Update Stalwart, Caddy/nginx regularly
5. **Monitor logs**: Check for suspicious activity
6. **Backup regularly**: Backup /opt/stalwart/data daily

## Additional Resources

- [Complete Setup Guide](./SETUP.md)
- [Production Quick Start](./PRODUCTION_QUICK_START.md)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Stalwart Documentation](https://stalw.art/docs)
