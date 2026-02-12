# Nginx Configuration for Stalwart Admin Panel

This directory contains nginx configuration files for serving the Stalwart admin panel on a separate domain with TLS.

## Directory Structure

```
nginx/
├── nginx.conf           # Main nginx configuration
├── conf.d/
│   └── admin.conf      # Admin panel reverse proxy configuration
├── certs/              # TLS certificates (if using manual certs)
└── README.md           # This file
```

## Quick Setup

### 1. Configure Domain

Edit `nginx/conf.d/admin.conf` and replace `admin.example.com` with your actual admin domain.

### 2. Choose Certificate Method

**Option A: Certbot (Recommended)**

```bash
# Install certbot on host
sudo apt install certbot python3-certbot-nginx

# Create webroot directory
mkdir -p nginx/webroot

# Update docker-compose.yml to add volumes:
# - ./nginx/webroot:/var/www/certbot
# - /etc/letsencrypt:/etc/letsencrypt:ro

# Obtain certificate
sudo certbot certonly --webroot -w ./nginx/webroot -d admin.example.com

# Update nginx/conf.d/admin.conf to use Let's Encrypt paths
# Uncomment Option 1 lines in the config
```

**Option B: Manual Certificates**

```bash
# Create certs directory
mkdir -p nginx/certs

# Place your certificates
cp /path/to/fullchain.pem nginx/certs/admin.example.com.crt
cp /path/to/privkey.pem nginx/certs/admin.example.com.key

# Set permissions
chmod 644 nginx/certs/*.crt
chmod 600 nginx/certs/*.key

# nginx/conf.d/admin.conf already configured for Option 2
```

### 3. Start Services

```bash
# Build and start
docker compose -f docker-compose.advanced.yml up -d --build

# Check nginx status
docker compose logs nginx

# Test configuration
docker compose exec nginx nginx -t
```

### 4. Verify Setup

```bash
# Test HTTPS
curl -I https://admin.example.com

# Check certificate
openssl s_client -connect admin.example.com:443 -servername admin.example.com
```

## Configuration Details

### Main Configuration (nginx.conf)

- Worker processes set to auto
- Client max body size: 100MB
- Gzip compression enabled
- SSL/TLS best practices
- Logging configuration

### Admin Panel Config (conf.d/admin.conf)

- HTTP to HTTPS redirect
- TLS 1.2 and 1.3 support
- Security headers (HSTS, CSP, X-Frame-Options, etc.)
- Reverse proxy to Stalwart on localhost:8080
- WebSocket support
- Health check endpoint

## Security Headers

The configuration includes:

- **HSTS**: Force HTTPS for 1 year
- **X-Content-Type-Options**: Prevent MIME sniffing
- **X-Frame-Options**: Prevent clickjacking
- **X-XSS-Protection**: XSS filter for legacy browsers
- **Referrer-Policy**: Control referrer information
- **Content-Security-Policy**: Restrict resource loading

## Certificate Renewal

### Certbot (Automatic)

```bash
# Test renewal
sudo certbot renew --dry-run

# Setup cron job (certbot usually does this automatically)
sudo crontab -e
# Add: 0 0 * * 0 certbot renew --quiet
```

### Manual Certificates

```bash
# Update certificates when renewed
cp /path/to/new/fullchain.pem nginx/certs/admin.example.com.crt
cp /path/to/new/privkey.pem nginx/certs/admin.example.com.key

# Reload nginx
docker compose exec nginx nginx -s reload
```

## Troubleshooting

### Nginx won't start

```bash
# Check configuration syntax
docker compose exec nginx nginx -t

# View nginx logs
docker compose logs nginx

# Check if port 80/443 is in use
sudo netstat -tulpn | grep -E ':(80|443)'
```

### Certificate errors

```bash
# Verify certificate files exist
ls -la nginx/certs/

# Check certificate validity
openssl x509 -in nginx/certs/admin.example.com.crt -text -noout

# Check certificate matches key
openssl x509 -noout -modulus -in nginx/certs/admin.example.com.crt | openssl md5
openssl rsa -noout -modulus -in nginx/certs/admin.example.com.key | openssl md5
```

### Admin panel not accessible

```bash
# Check if Stalwart is running
docker ps | grep stalwart

# Test backend connection
docker compose exec nginx curl http://stalwart:8080/health

# Check nginx proxy settings
docker compose exec nginx cat /etc/nginx/conf.d/admin.conf
```

### 502 Bad Gateway

```bash
# Check Stalwart health
docker compose logs stalwart

# Verify network connectivity
docker compose exec nginx ping stalwart

# Check if admin is bound to correct interface
docker compose exec stalwart netstat -tlnp | grep 8080
```

## Customization

### Add Rate Limiting

Add to `conf.d/admin.conf` inside the `http` block:

```nginx
limit_req_zone $binary_remote_addr zone=admin:10m rate=10r/s;
limit_req zone=admin burst=20 nodelay;
```

### Add IP Whitelisting

Add to `conf.d/admin.conf` inside the `server` block:

```nginx
# Allow specific IPs
allow 203.0.113.0/24;
allow 198.51.100.0/24;
deny all;
```

### Add Basic Authentication

```bash
# Install apache2-utils on host
sudo apt install apache2-utils

# Create password file
htpasswd -c nginx/.htpasswd admin

# Add to conf.d/admin.conf location block:
auth_basic "Admin Access";
auth_basic_user_file /etc/nginx/.htpasswd;

# Add to docker-compose.yml nginx volumes:
- ./nginx/.htpasswd:/etc/nginx/.htpasswd:ro
```

## Resources

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Certbot Documentation](https://certbot.eff.org/)
- [SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [HSTS Preload List](https://hstspreload.org/)

## Support

For issues or questions:
- Check `docker compose logs nginx`
- Review MULTI_SERVICE_SETUP.md
- Check Stalwart documentation
- GitHub Issues: https://github.com/stalwartlabs/stalwart/issues
