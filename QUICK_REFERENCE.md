# Quick Reference: Stalwart Docker Compose Setups

## Three Available Setups

| Setup | File | Use Case | Admin Access |
|-------|------|----------|--------------|
| **Basic** | `docker-compose.yml` | Development, < 100 users | `http://localhost:8080` |
| **Advanced** | `docker-compose.advanced.yml` | Production, manual security | `http://localhost:8080` |
| **Secure Advanced** | `docker-compose.advanced-separate-domains.yml` | Production, auto security | `https://admin.example.com` ⭐ |

## Quick Start Commands

### Basic Setup
```bash
# Simple single-container deployment
cp .env.example .env
nano .env  # Set ADMIN_SECRET
docker compose up -d --build
```

### Advanced Setup
```bash
# Multi-service with PostgreSQL + Redis + MinIO
cp .env.example .env
nano .env  # Set all passwords
docker compose -f docker-compose.advanced.yml up -d --build
```

### Secure Advanced Setup ⭐ RECOMMENDED
```bash
# Production-ready with separate domains & auto HTTPS
cp .env.example .env
nano .env  # Set passwords + domains
docker compose -f docker-compose.advanced-separate-domains.yml up -d --build
```

## Environment Variables Comparison

### Basic Setup (.env)
```bash
ADMIN_SECRET=<password>
TZ=UTC
```

### Advanced Setup (.env)
```bash
ADMIN_SECRET=<password>
DB_PASSWORD=<password>
REDIS_PASSWORD=<password>
MINIO_PASSWORD=<password>
TZ=UTC
```

### Secure Advanced Setup (.env)
```bash
# All advanced variables PLUS:
MAIL_DOMAIN=mail.example.com
ADMIN_DOMAIN=admin.example.com
ACME_EMAIL=admin@example.com
```

## DNS Requirements

### Basic & Advanced
- None (uses localhost)

### Secure Advanced ⭐
```dns
mail.example.com      A      YOUR_SERVER_IP
admin.example.com     A      YOUR_SERVER_IP
example.com           MX 10  mail.example.com
```

## Port Requirements

### Basic
```
25, 587, 465  (SMTP)
143, 993      (IMAP)
4190          (ManageSieve)
8080, 443     (Admin)
```

### Advanced
```
Basic ports PLUS:
9000          (MinIO API)
9001          (MinIO Console)
```

### Secure Advanced ⭐
```
Mail: 25, 587, 465, 143, 993, 110, 995, 4190
Admin: 80, 443 (Caddy)
MinIO Console: 9001 (localhost only)
```

## Access URLs

### Basic Setup
- Admin: `http://localhost:8080`
- Login: admin / ADMIN_SECRET

### Advanced Setup
- Admin: `http://localhost:8080`
- MinIO: `http://localhost:9001`
- Login: admin / ADMIN_SECRET

### Secure Advanced Setup ⭐
- Admin: `https://admin.example.com` (auto HTTPS)
- Mail: mail.example.com (for email clients)
- MinIO: `http://localhost:9001` (local only)
- Login: admin / ADMIN_SECRET

## Resource Requirements

| Setup | Memory | CPU | Containers | Disk |
|-------|--------|-----|------------|------|
| Basic | 0.5-1 GB | 0.5-1 | 1 | 10-50 GB |
| Advanced | 3-4 GB | 2-4 | 5 | 100-500 GB |
| Secure Advanced | 3.5-4.5 GB | 2-4 | 6 | 100-500 GB |

## Security Comparison

| Feature | Basic | Advanced | Secure Advanced |
|---------|-------|----------|-----------------|
| Admin Isolation | ❌ | ❌ | ✅ |
| Auto HTTPS | ❌ | ❌ | ✅ |
| Security Headers | ❌ | ❌ | ✅ |
| Reverse Proxy | ❌ | ❌ | ✅ |
| Internal Network | ❌ | ✅ | ✅ |

## Common Commands

### View Logs
```bash
# Basic
docker logs stalwart

# Advanced
docker compose -f docker-compose.advanced.yml logs -f

# Secure Advanced
docker compose -f docker-compose.advanced-separate-domains.yml logs -f
docker logs stalwart-caddy  # Admin proxy logs
```

### Restart Services
```bash
# Basic
docker restart stalwart

# Advanced
docker compose -f docker-compose.advanced.yml restart

# Secure Advanced
docker compose -f docker-compose.advanced-separate-domains.yml restart
```

### Stop Services
```bash
# Basic
docker stop stalwart

# Advanced
docker compose -f docker-compose.advanced.yml down

# Secure Advanced
docker compose -f docker-compose.advanced-separate-domains.yml down
```

### Check Status
```bash
# Basic
docker ps | grep stalwart

# Advanced
docker compose -f docker-compose.advanced.yml ps

# Secure Advanced
docker compose -f docker-compose.advanced-separate-domains.yml ps
```

## Troubleshooting Quick Fixes

### Admin Not Accessible
```bash
# Check if container is running
docker ps | grep stalwart

# Check logs
docker logs stalwart

# For Secure Advanced: Check Caddy
docker logs stalwart-caddy
```

### Cannot Send/Receive Email
```bash
# Test SMTP
telnet mail.example.com 25

# Check logs
docker logs stalwart

# Verify DNS
dig -t MX example.com
```

### Certificate Issues (Secure Advanced)
```bash
# Check certificates
docker exec stalwart-caddy caddy list-certificates

# View ACME logs
docker logs stalwart-caddy 2>&1 | grep -i acme

# Verify DNS
dig admin.example.com
```

## Documentation Links

- **[Complete Comparison](./DOCKER_COMPOSE_COMPARISON.md)** - Detailed comparison
- **[Basic Setup](./QUICKSTART.md)** - Quick start guide
- **[Advanced Setup](./MULTI_SERVICE_SETUP.md)** - Multi-service guide
- **[Secure Advanced](./ADVANCED_SEPARATE_DOMAINS_GUIDE.md)** - Secure setup guide
- **[Separate Domains](./SEPARATE_DOMAINS_SETUP.md)** - Manual domain config
- **[Refactoring Summary](./REFACTORING_SUMMARY.md)** - What changed and why

## Recommendations

### Choose Basic If:
- ✅ Testing or evaluating
- ✅ Personal use (< 100 users)
- ✅ Want simplicity

### Choose Advanced If:
- ✅ Need PostgreSQL/Redis/MinIO
- ✅ 1,000+ users
- ✅ Comfortable with manual security

### Choose Secure Advanced If: ⭐ RECOMMENDED
- ✅ Production deployment
- ✅ Want automatic HTTPS
- ✅ Need maximum security
- ✅ Professional domain structure
- ✅ Enterprise requirements

## Security Checklist

For production deployments:

- [ ] Use Secure Advanced setup
- [ ] Set strong passwords (use `openssl rand -base64 32`)
- [ ] Configure proper DNS records
- [ ] Set up firewall rules
- [ ] Enable regular backups
- [ ] Monitor service health
- [ ] Keep images updated
- [ ] Review access logs regularly

## Getting Help

- GitHub Issues: https://github.com/stalwartlabs/stalwart/issues
- Documentation: https://stalw.art/docs
- Community: https://stalw.art/community
- Discord: https://discord.com/servers/stalwart-923615863037390889
- Reddit: https://www.reddit.com/r/stalwartlabs/
