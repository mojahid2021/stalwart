# Advanced Docker Compose - Separate Domains Deployment Guide

This guide explains the benefits and implementation of the separate domains approach for deploying Stalwart Mail Server with PostgreSQL, Redis, and MinIO.

## Overview

The **Advanced Separate Domains Setup** (`docker-compose.advanced-separate-domains.yml`) provides a production-ready deployment architecture that separates the admin panel from mail services using different domains.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                 │
└───────────┬─────────────────────────────────┬───────────────────┘
            │                                 │
            │ Mail Services                   │ Admin Panel
            │ (Direct Access)                 │ (Via Reverse Proxy)
            │                                 │
    ┌───────▼──────────┐             ┌───────▼──────────┐
    │ mail.example.com │             │admin.example.com │
    │  Ports: 25,587,  │             │   Port: 443      │
    │  465,143,993,etc │             │   (HTTPS)        │
    └───────┬──────────┘             └───────┬──────────┘
            │                                 │
            │                        ┌────────▼─────────┐
            │                        │  Caddy Proxy     │
            │                        │  - Auto HTTPS    │
            │                        │  - Security      │
            │                        │  - Headers       │
            │                        └────────┬─────────┘
            │                                 │
    ┌───────▼─────────────────────────────────▼──────────┐
    │             Stalwart Mail Server                    │
    │  ┌──────────┐  ┌──────────┐  ┌──────────────┐    │
    │  │   SMTP   │  │   IMAP   │  │    Admin     │    │
    │  │  (Mail)  │  │  (Mail)  │  │ (localhost)  │    │
    │  └──────────┘  └──────────┘  └──────────────┘    │
    └───────┬────────────┬────────────┬──────────────────┘
            │            │            │
    ┌───────▼────┐ ┌────▼─────┐ ┌───▼──────┐
    │ PostgreSQL │ │  Redis   │ │  MinIO   │
    │  (Internal)│ │(Internal)│ │(Internal)│
    └────────────┘ └──────────┘ └──────────┘
```

## Why Separate Domains?

### Security Benefits

1. **Isolation**: Admin panel not directly exposed to the internet
2. **Access Control**: Admin accessible only via reverse proxy with HTTPS
3. **Network Separation**: Admin bound to localhost (127.0.0.1:8080)
4. **Attack Surface**: Reduced exposure of admin interface
5. **Security Headers**: Additional protection from Caddy (HSTS, CSP, etc.)

### Operational Benefits

1. **Professional Structure**: Clear separation (mail.example.com vs admin.example.com)
2. **Scalability**: Admin can be moved to different server if needed
3. **Monitoring**: Separate access logs for mail and admin
4. **Maintenance**: Update admin without affecting mail services
5. **Compliance**: Better separation for security audits

### Technical Benefits

1. **Automatic HTTPS**: Let's Encrypt certificates managed by Caddy
2. **Zero Config TLS**: No manual certificate management
3. **Certificate Renewal**: Automatic renewal every 60 days
4. **Modern TLS**: TLS 1.2 and 1.3 with secure ciphers
5. **HTTP/3 Support**: Caddy includes HTTP/3 (QUIC) support

## What's Included

### Services

1. **Stalwart Mail Server**
   - Mail services on mail.example.com (direct access)
   - Admin panel on localhost:8080 (internal only)

2. **PostgreSQL**
   - Primary data storage
   - Full-text search
   - Internal network only

3. **Redis**
   - Caching and lookups
   - Internal network only

4. **MinIO**
   - S3-compatible blob storage
   - Console on localhost:9001 (internal only)
   - Internal network only

5. **Caddy Reverse Proxy**
   - Serves admin.example.com
   - Automatic HTTPS with Let's Encrypt
   - Security headers
   - Access logging

### Configuration Files

1. **docker-compose.advanced-separate-domains.yml**
   - Docker Compose configuration with all services
   - Network isolation
   - Health checks
   - Resource limits

2. **config-advanced-separate-domains.toml**
   - Stalwart configuration for separate domains
   - PostgreSQL, Redis, MinIO integration
   - Admin listener on localhost only

3. **caddy/Caddyfile**
   - Caddy reverse proxy configuration
   - Automatic HTTPS
   - Security headers
   - Error handling

4. **.env.example**
   - Environment variables template
   - Domain configuration
   - Passwords and secrets

## Prerequisites

### DNS Configuration

You need **both domains** pointing to your server:

```dns
# A Records
mail.example.com      A      YOUR_SERVER_IP
admin.example.com     A      YOUR_SERVER_IP

# MX Record (for receiving email)
example.com           MX 10  mail.example.com

# Optional: Additional records
@                     A      YOUR_SERVER_IP
www                   CNAME  example.com
```

### Firewall Requirements

Open the following ports:

```bash
# Mail Services
25      # SMTP (incoming mail)
587     # Submission (authenticated sending)
465     # Submissions (SMTP over TLS)
143     # IMAP (email access)
993     # IMAPS (IMAP over TLS)
110     # POP3 (email access)
995     # POP3S (POP3 over TLS)
4190    # ManageSieve (filter management)

# Admin & ACME
80      # HTTP (Let's Encrypt ACME challenge)
443     # HTTPS (Admin panel)
```

### System Requirements

**Minimum** (Testing):
- CPU: 4 cores
- RAM: 8 GB
- Disk: 50 GB SSD

**Recommended** (Production):
- CPU: 8+ cores
- RAM: 16+ GB
- Disk: 200+ GB SSD (NVMe preferred)
- Network: 1 Gbps+

## Step-by-Step Deployment

### 1. Clone Repository

```bash
git clone https://github.com/stalwartlabs/stalwart.git
cd stalwart
```

### 2. Configure Environment

```bash
# Copy template
cp .env.example .env

# Edit with your values
nano .env
```

Required environment variables:

```bash
# Passwords (generate with: openssl rand -base64 32)
ADMIN_SECRET=your-secure-admin-password
DB_PASSWORD=your-secure-db-password
REDIS_PASSWORD=your-secure-redis-password
MINIO_PASSWORD=your-secure-minio-password

# Domains (REPLACE WITH YOUR DOMAINS)
MAIL_DOMAIN=mail.example.com
ADMIN_DOMAIN=admin.example.com

# ACME Email (for Let's Encrypt notifications)
ACME_EMAIL=admin@example.com

# System
TZ=UTC

# Optional: Resource limits
STALWART_MEMORY_RESERVATION=1G
STALWART_CPU_RESERVATION=1
POSTGRES_MEMORY_RESERVATION=512M
POSTGRES_CPU_RESERVATION=0.5
REDIS_MEMORY_RESERVATION=256M
REDIS_CPU_RESERVATION=0.25
MINIO_MEMORY_RESERVATION=512M
MINIO_CPU_RESERVATION=0.5
```

### 3. Secure Environment File

```bash
chmod 600 .env
chown $USER:$USER .env
```

### 4. Review Caddy Configuration (Optional)

```bash
# Check Caddyfile
cat caddy/Caddyfile

# The default configuration includes:
# - Automatic HTTPS
# - Security headers
# - Reverse proxy to Stalwart
# - Health checks
# - Access logging
```

### 5. Start Services

```bash
# Start all services
docker compose -f docker-compose.advanced-separate-domains.yml up -d --build

# Monitor startup logs
docker compose -f docker-compose.advanced-separate-domains.yml logs -f

# Wait for services to be healthy (1-2 minutes)
```

### 6. Verify Deployment

```bash
# Check service status
docker compose -f docker-compose.advanced-separate-domains.yml ps

# All services should show "healthy" or "running":
# - stalwart (healthy)
# - stalwart-postgres (healthy)
# - stalwart-redis (healthy)
# - stalwart-minio (healthy)
# - stalwart-caddy (healthy)
# - stalwart-minio-init (exited 0)
```

### 7. Test Services

```bash
# Test admin panel (HTTPS)
curl -I https://admin.example.com

# Test SMTP
telnet mail.example.com 25

# Test IMAP
openssl s_client -connect mail.example.com:993

# Check Caddy certificate
docker exec stalwart-caddy caddy list-certificates
```

### 8. Access Admin Panel

Open browser and navigate to:

```
https://admin.example.com
```

Login credentials:
- **Username**: admin
- **Password**: Your ADMIN_SECRET from .env

## Security Best Practices

### 1. Strong Passwords

```bash
# Generate secure passwords
openssl rand -base64 32

# Use unique passwords for each service
# Never use default or example passwords
```

### 2. Regular Updates

```bash
# Update images
docker compose -f docker-compose.advanced-separate-domains.yml pull

# Restart with new images
docker compose -f docker-compose.advanced-separate-domains.yml up -d
```

### 3. Firewall Configuration

```bash
# Use UFW (Ubuntu/Debian)
sudo ufw allow 25/tcp
sudo ufw allow 587/tcp
sudo ufw allow 465/tcp
sudo ufw allow 143/tcp
sudo ufw allow 993/tcp
sudo ufw allow 110/tcp
sudo ufw allow 995/tcp
sudo ufw allow 4190/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Check status
sudo ufw status
```

### 4. Fail2ban (Optional)

```bash
# Install Fail2ban
sudo apt install fail2ban

# Configure for Stalwart
sudo nano /etc/fail2ban/jail.local

# Add:
[stalwart-smtp]
enabled = true
port = 25,587,465
filter = stalwart
logpath = /var/log/stalwart/smtp.log
maxretry = 5
bantime = 3600
```

### 5. Regular Backups

```bash
# Backup script
cat > backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/stalwart_$DATE"

mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL
docker exec stalwart-postgres pg_dump -U stalwart stalwart > "$BACKUP_DIR/postgres.sql"

# Backup configuration
cp -r stalwart-data "$BACKUP_DIR/"
cp .env "$BACKUP_DIR/"

# Create tarball
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "Backup completed: $BACKUP_DIR.tar.gz"
EOF

chmod +x backup.sh
```

## Monitoring

### Health Checks

```bash
# Check all services
docker compose -f docker-compose.advanced-separate-domains.yml ps

# Check specific service health
docker inspect stalwart --format='{{.State.Health.Status}}'
docker inspect stalwart-postgres --format='{{.State.Health.Status}}'
```

### Logs

```bash
# View all logs
docker compose -f docker-compose.advanced-separate-domains.yml logs -f

# View specific service logs
docker logs stalwart
docker logs stalwart-caddy
docker logs stalwart-postgres

# View Caddy access logs
docker exec stalwart-caddy cat /var/log/caddy/admin-access.log
```

### Metrics

```bash
# Container stats
docker stats

# Disk usage
docker system df

# Network inspection
docker network inspect stalwart-advanced-separate-domains_stalwart-internal
```

## Maintenance

### Update Services

```bash
# Pull latest images
docker compose -f docker-compose.advanced-separate-domains.yml pull

# Recreate containers with new images
docker compose -f docker-compose.advanced-separate-domains.yml up -d

# Remove old images
docker image prune -a
```

### Restart Services

```bash
# Restart all
docker compose -f docker-compose.advanced-separate-domains.yml restart

# Restart specific service
docker compose -f docker-compose.advanced-separate-domains.yml restart stalwart
docker compose -f docker-compose.advanced-separate-domains.yml restart caddy
```

### Stop Services

```bash
# Stop all services
docker compose -f docker-compose.advanced-separate-domains.yml stop

# Start again
docker compose -f docker-compose.advanced-separate-domains.yml start
```

### Clean Up

```bash
# Remove containers (keeps volumes)
docker compose -f docker-compose.advanced-separate-domains.yml down

# Remove containers and volumes (WARNING: Deletes all data)
docker compose -f docker-compose.advanced-separate-domains.yml down -v

# Clean up unused resources
docker system prune -a
```

## Troubleshooting

See [MULTI_SERVICE_SETUP.md](./MULTI_SERVICE_SETUP.md#separate-domains-configuration-option-2) for detailed troubleshooting steps.

## Alternative: Nginx Instead of Caddy

If you prefer Nginx over Caddy, see [SEPARATE_DOMAINS_SETUP.md](./SEPARATE_DOMAINS_SETUP.md) for complete Nginx configuration.

## Resources

- [Stalwart Documentation](https://stalw.art/docs)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/docs/)
- [MinIO Documentation](https://min.io/docs/)

## Support

For questions or issues:
- GitHub Issues: https://github.com/stalwartlabs/stalwart/issues
- Documentation: https://stalw.art/docs
- Community: https://stalw.art/community
