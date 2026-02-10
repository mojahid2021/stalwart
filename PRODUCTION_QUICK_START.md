# Quick Production Deployment Guide

**For the complete guide, see [SETUP.md - Production Deployment Guide](./SETUP.md#production-deployment-guide)**

This is a condensed reference for deploying Stalwart in production using Docker with RocksDB.

## Prerequisites

- Docker and Docker Compose installed
- Domain name configured
- Server with 2GB+ RAM, 2+ CPU cores
- Ports 25, 587, 465, 143, 993, 443 open

## Quick Start (5 Minutes)

### 1. Prepare Server

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Create directory
sudo mkdir -p /opt/stalwart && cd /opt/stalwart
git clone https://github.com/stalwartlabs/stalwart.git
cd stalwart
```

### 2. Configure Environment

```bash
# Create .env file
cat > .env << 'EOF'
ADMIN_SECRET=YOUR_SECURE_PASSWORD_HERE  # Change this!
TZ=America/New_York
EOF
chmod 600 .env
```

### 3. Deploy

```bash
# Build and start
docker compose -f docker-compose.production.yml up -d

# View logs
docker compose -f docker-compose.production.yml logs -f
```

### 4. Access

- Admin UI: https://YOUR_SERVER_IP or https://mail.yourdomain.com
- Login: admin / YOUR_ADMIN_SECRET

## Why RocksDB?

RocksDB is the **default and recommended** storage backend because:

1. ✅ **Embedded** - No separate database server needed
2. ✅ **Fast** - Millions of operations per second on SSDs
3. ✅ **Simple** - Zero configuration, just works
4. ✅ **Reliable** - Powers Facebook, LinkedIn, Netflix
5. ✅ **Efficient** - Lower memory than PostgreSQL/MySQL
6. ✅ **Easy Backups** - Just copy the data directory
7. ✅ **Scales** - Handles 10,000+ users on single server

**Use RocksDB unless:**
- You need multi-server deployment (use PostgreSQL)
- You need SQL access to mail data (use PostgreSQL)
- You're on network storage like NFS (use PostgreSQL)

## Production Docker Compose File

Create `docker-compose.production.yml`:

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
      - "25:25"      # SMTP
      - "587:587"    # Submission
      - "465:465"    # Submissions (TLS)
      - "143:143"    # IMAP
      - "993:993"    # IMAPS
      - "4190:4190"  # ManageSieve
      - "443:443"    # HTTPS Admin
    
    volumes:
      - /opt/stalwart/data:/opt/stalwart/data
      - /opt/stalwart/logs:/opt/stalwart/logs
      - /opt/stalwart/config:/opt/stalwart/etc
      - /etc/letsencrypt:/etc/letsencrypt:ro
    
    environment:
      - ADMIN_SECRET=${ADMIN_SECRET:?ADMIN_SECRET required}
      - STALWART_PATH=/opt/stalwart
      - TZ=${TZ:-UTC}
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '4'
        reservations:
          memory: 2G
          cpus: '2'
    
    security_opt:
      - no-new-privileges:true
```

## DNS Configuration

```dns
# A Record
mail.yourdomain.com.        A       YOUR_SERVER_IP

# MX Record
yourdomain.com.             MX 10   mail.yourdomain.com.

# SPF Record
yourdomain.com.             TXT     "v=spf1 mx ~all"

# DKIM (generate in admin panel first)
default._domainkey.yourdomain.com. TXT "v=DKIM1; k=rsa; p=YOUR_PUBLIC_KEY"

# DMARC
_dmarc.yourdomain.com.      TXT     "v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"
```

### Separate Admin Subdomain (Optional)

To use `admin.yourdomain.com` for admin panel and `mail.yourdomain.com` for mail:

```dns
# Add admin subdomain
admin.yourdomain.com.       A       YOUR_SERVER_IP
```

**Quick setup with Caddy (recommended):**

```bash
# Install Caddy
sudo apt install caddy

# Configure (/etc/caddy/Caddyfile)
admin.yourdomain.com {
    reverse_proxy localhost:8080
}

# Restart
sudo systemctl restart caddy
```

Now access admin panel at `https://admin.yourdomain.com` and mail stays at `mail.yourdomain.com`.

For detailed configuration with nginx or direct SNI setup, see [SETUP.md - Section 7a](./SETUP.md#production-deployment-guide).

## TLS/SSL Setup

```bash
# Install Certbot
sudo apt install certbot

# Get certificate
sudo certbot certonly --standalone -d mail.yourdomain.com

# Auto-renew (add to crontab)
0 3 * * * certbot renew --quiet && docker compose -f /opt/stalwart/stalwart/docker-compose.production.yml restart
```

## Firewall

```bash
sudo ufw allow 25/tcp    # SMTP
sudo ufw allow 587/tcp   # Submission
sudo ufw allow 465/tcp   # Submissions
sudo ufw allow 143/tcp   # IMAP
sudo ufw allow 993/tcp   # IMAPS
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

## Backup

```bash
# Create backup script
cat > /opt/stalwart/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/stalwart/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"
tar -czf "${BACKUP_DIR}/stalwart-backup-${DATE}.tar.gz" \
  -C /opt/stalwart data/ config/ logs/
find "$BACKUP_DIR" -name "stalwart-backup-*.tar.gz" -mtime +7 -delete
EOF

chmod +x /opt/stalwart/backup.sh

# Add to crontab (daily at 2 AM)
echo "0 2 * * * /opt/stalwart/backup.sh" | sudo crontab -
```

## Production Checklist

Before going live:

- [ ] DNS records configured (MX, SPF, DKIM, DMARC)
- [ ] TLS certificates installed
- [ ] Firewall configured
- [ ] Strong admin password set
- [ ] Backups configured
- [ ] Monitoring in place
- [ ] Resource limits set
- [ ] Reverse DNS (PTR) record
- [ ] Port 25 unblocked by hosting provider

## Maintenance

**Daily:**
```bash
docker logs stalwart-production --since 24h
df -h /opt/stalwart
```

**Weekly:**
- Review spam filter performance
- Check queue status

**Monthly:**
```bash
cd /opt/stalwart/stalwart
git pull
docker compose -f docker-compose.production.yml build
docker compose -f docker-compose.production.yml up -d
```

## Monitoring

```bash
# Check health
curl http://localhost:8080/health

# View logs
docker logs -f stalwart-production

# Check resources
docker stats stalwart-production
```

## Storage Backend Options

| Users | Recommended | Alternative |
|-------|-------------|-------------|
| < 1,000 | RocksDB | - |
| 1,000 - 10,000 | RocksDB | PostgreSQL |
| 10,000+ | PostgreSQL + S3 | - |
| Multi-server | PostgreSQL + S3 + Redis | - |

## Common Commands

```bash
# Start
docker compose -f docker-compose.production.yml up -d

# Stop
docker compose -f docker-compose.production.yml down

# Restart
docker compose -f docker-compose.production.yml restart

# View logs
docker compose -f docker-compose.production.yml logs -f

# Update
docker compose -f docker-compose.production.yml pull
docker compose -f docker-compose.production.yml up -d --build

# Backup
/opt/stalwart/backup.sh

# Shell access
docker compose -f docker-compose.production.yml exec stalwart /bin/bash
```

## Troubleshooting

**Service won't start:**
```bash
docker logs stalwart-production
docker compose -f docker-compose.production.yml ps
```

**Check configuration:**
```bash
docker compose -f docker-compose.production.yml config
```

**Reset admin password:**
```bash
# Stop service
docker compose -f docker-compose.production.yml down

# Edit config
nano /opt/stalwart/config/config.toml
# Change authentication.fallback-admin.secret

# Restart
docker compose -f docker-compose.production.yml up -d
```

## Performance Tuning

Edit `/opt/stalwart/config/config.toml`:

```toml
[store."rocksdb"]
compression = "lz4"         # or "zstd"
cache.size = "4GB"          # Increase for more RAM
optimize.writes = true      # For high write loads
```

## For More Information

- **Complete Guide**: [SETUP.md](./SETUP.md)
- **Storage Selection**: [SETUP.md - Storage Backend Selection](./SETUP.md#storage-backend-selection)
- **Quick Start**: [QUICKSTART.md](./QUICKSTART.md)
- **Official Docs**: https://stalw.art/docs

---

**Note:** This is a quick reference. For detailed explanations, security hardening, disaster recovery, and advanced configurations, see the complete [SETUP.md](./SETUP.md).
