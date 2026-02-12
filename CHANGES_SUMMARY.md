# Changes Summary - Integrated Separate Domains Setup

## User Feedback Addressed

User requested:
1. ✅ Use ONE Docker Compose file (not separate files)
2. ✅ Admin domain handled via nginx (not Caddy)
3. ✅ Mail domain TLS handled via Stalwart's built-in ACME (configured in dashboard)

## Implementation

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   docker-compose.advanced.yml                │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │PostgreSQL│    │  Redis   │    │  MinIO   │              │
│  │ (internal)    │(internal)│    │(internal)│              │
│  └──────────┘    └──────────┘    └──────────┘              │
│                                                               │
│  ┌───────────────────────────────────────────────────┐      │
│  │              Stalwart Mail Server                  │      │
│  │  ┌──────────────┐         ┌──────────────────┐   │      │
│  │  │ Admin Panel  │         │  Mail Services   │   │      │
│  │  │ localhost:   │         │  (SMTP/IMAP/POP3)│   │      │
│  │  │   8080       │         │  with ACME TLS   │   │      │
│  │  └──────────────┘         └──────────────────┘   │      │
│  └───────────────────────────────────────────────────┘      │
│          ▲                              ▲                     │
│          │                              │                     │
│  ┌───────┴──────┐                      │                     │
│  │    nginx     │                      │                     │
│  │  (reverse    │                 Direct access              │
│  │   proxy)     │                 (all ports)                │
│  └──────────────┘                                            │
└─────────────────────────────────────────────────────────────┘
         ▲                                 ▲
         │                                 │
    Port 80/443                      Ports 25,587,465
 admin.yourdomain.com                143,993,110,995,4190
                                    mail.yourdomain.com
```

### Changes Made

**1. docker-compose.advanced.yml**
- Added nginx service with alpine image
- Admin bound to `127.0.0.1:8080` (localhost only)
- MinIO console bound to `127.0.0.1:9001` (localhost only)
- Fixed Redis health check (`redis-cli -a $PASSWORD`)
- Added MAIL_DOMAIN and ADMIN_DOMAIN environment variables
- Config-advanced.toml mounted by default
- Complete usage instructions included

**2. nginx Configuration**
- `nginx/nginx.conf` - Main nginx configuration
  - Auto worker processes
  - 100MB max body size
  - Gzip compression
  - TLS 1.2/1.3 support
  
- `nginx/conf.d/admin.conf` - Admin panel proxy
  - HTTP → HTTPS redirect
  - Reverse proxy to stalwart:8080
  - Security headers (HSTS, CSP, X-Frame-Options, etc.)
  - WebSocket support
  - Health check endpoint
  - Supports certbot or manual certificates

- `nginx/README.md` - Complete documentation
  - Certificate setup (certbot or manual)
  - Configuration examples
  - Troubleshooting guide
  - Customization options

**3. config-advanced.toml**
- Admin listener on `127.0.0.1:8080`
- Updated TLS section with ACME guidance
- Instructions for configuring Stalwart's ACME in dashboard
- Notes about separate domains architecture

**4. Removed Files**
- `docker-compose.advanced-separate-domains.yml`
- `config-advanced-separate-domains.toml`
- `caddy/` directory (Caddyfile, README)
- `ADVANCED_SEPARATE_DOMAINS_GUIDE.md`
- `DOCKER_COMPOSE_COMPARISON.md`
- `QUICK_REFERENCE.md`
- `REFACTORING_SUMMARY.md`

**5. Updated Files**
- `.gitignore` - nginx/certs/ and nginx/webroot/
- `README.md` - Removed reference to deleted guide

## Setup Instructions

### 1. Configure Environment

```bash
cp .env.example .env
nano .env
```

Required variables:
```bash
ADMIN_SECRET=your-secure-password
DB_PASSWORD=your-secure-password
REDIS_PASSWORD=your-secure-password
MINIO_PASSWORD=your-secure-password
MAIL_DOMAIN=mail.yourdomain.com
ADMIN_DOMAIN=admin.yourdomain.com
TZ=UTC
```

### 2. Configure nginx

Edit `nginx/conf.d/admin.conf`:
- Replace `admin.example.com` with your actual domain

### 3. Setup TLS Certificates

**Option A: Certbot (Recommended)**
```bash
sudo apt install certbot
mkdir -p nginx/webroot
sudo certbot certonly --webroot -w ./nginx/webroot -d admin.yourdomain.com
# Update nginx/conf.d/admin.conf to use Let's Encrypt paths
```

**Option B: Manual Certificates**
```bash
mkdir -p nginx/certs
cp fullchain.pem nginx/certs/admin.yourdomain.com.crt
cp privkey.pem nginx/certs/admin.yourdomain.com.key
chmod 644 nginx/certs/*.crt
chmod 600 nginx/certs/*.key
```

### 4. Deploy

```bash
docker compose -f docker-compose.advanced.yml up -d --build
```

### 5. Configure Mail Domain TLS

Access admin panel: https://admin.yourdomain.com
- Navigate to Settings → TLS
- Enable ACME for mail.yourdomain.com
- Stalwart will automatically obtain and renew certificates

## Security Features

✅ Admin panel isolated on localhost (127.0.0.1:8080)
✅ Admin accessed only via nginx reverse proxy
✅ Mail domain uses Stalwart's built-in ACME
✅ Security headers (HSTS, CSP, X-Frame-Options, etc.)
✅ Internal services on private network
✅ MinIO console restricted to localhost
✅ Separate domains for professional structure

## Benefits

1. **Single File**: Everything in docker-compose.advanced.yml
2. **nginx**: Industry-standard reverse proxy (as requested)
3. **Stalwart ACME**: Built-in TLS for mail domain (configured in dashboard)
4. **Security**: Admin isolated, accessed via reverse proxy only
5. **Flexibility**: Choose certbot or manual certificates for admin
6. **Documentation**: Complete nginx setup guide included

## Testing

```bash
# Validate Docker Compose
docker compose -f docker-compose.advanced.yml config --quiet

# Test nginx configuration
docker compose exec nginx nginx -t

# Check services
docker compose ps

# View logs
docker compose logs -f

# Test admin panel
curl -I https://admin.yourdomain.com

# Test mail services
telnet mail.yourdomain.com 25
```

## Commit

**Commit Hash**: `0f0fc97`

**Changes**:
- 15 files changed
- 611 insertions(+)
- 2387 deletions(-)
- Net reduction: Simplified by removing duplicate documentation

## Next Steps for Users

1. Follow setup instructions above
2. Configure DNS for both domains
3. Setup TLS certificates (certbot or manual)
4. Deploy with docker compose
5. Configure Stalwart ACME in admin dashboard
6. Test both admin and mail access

## Documentation

- `nginx/README.md` - Complete nginx setup guide
- `MULTI_SERVICE_SETUP.md` - Comprehensive deployment guide
- `config-advanced.toml` - Configuration with comments
- `docker-compose.advanced.yml` - Usage instructions included
