# Docker Compose Configuration Comparison

This document compares the three Docker Compose configurations available for Stalwart Mail Server and helps you choose the right one for your deployment.

## Available Configurations

### 1. Basic Setup (`docker-compose.yml`)

**Purpose**: Simple single-container deployment for development and small deployments.

**Architecture**:
- Single Stalwart container
- RocksDB embedded storage
- All services in one container
- Direct port exposure

**Use Cases**:
- Development and testing
- Personal mail server
- Small deployments (< 100 users)
- Quick evaluation

**Pros**:
- ✅ Simple to set up
- ✅ Minimal resource usage
- ✅ Single container to manage
- ✅ Fast startup

**Cons**:
- ❌ Limited scalability
- ❌ Single point of failure
- ❌ Cannot scale components independently
- ❌ Admin panel exposed directly

### 2. Advanced Setup (`docker-compose.advanced.yml`)

**Purpose**: Multi-service deployment with separate database, cache, and storage.

**Architecture**:
- Stalwart container
- PostgreSQL (database)
- Redis (cache)
- MinIO (S3-compatible storage)
- All services on internal network

**Use Cases**:
- Production deployments
- Medium to large deployments (1,000-10,000+ users)
- Need for external services
- Scalability requirements

**Pros**:
- ✅ Scalable architecture
- ✅ Separate service components
- ✅ Better performance with caching
- ✅ Can scale components independently
- ✅ Production-ready

**Cons**:
- ⚠️ Admin panel exposed on port 8080 (all interfaces)
- ⚠️ No automatic HTTPS for admin
- ⚠️ Requires manual reverse proxy setup for HTTPS
- ⚠️ More complex configuration

### 3. Advanced Separate Domains (`docker-compose.advanced-separate-domains.yml`)

**Purpose**: Enterprise-grade deployment with isolated admin panel and automatic HTTPS.

**Architecture**:
- Stalwart container (admin on localhost only)
- PostgreSQL (database)
- Redis (cache)
- MinIO (S3-compatible storage)
- Caddy reverse proxy (automatic HTTPS)
- All internal services on private network

**Use Cases**:
- Production deployments
- Security-focused deployments
- Enterprise environments
- Compliance requirements
- Professional setup with separate domains

**Pros**:
- ✅ Maximum security (admin on localhost only)
- ✅ Automatic HTTPS with Let's Encrypt
- ✅ Separate admin domain (admin.example.com)
- ✅ Security headers included
- ✅ Professional domain structure
- ✅ Zero manual certificate management
- ✅ All benefits of advanced setup
- ✅ Built-in reverse proxy

**Cons**:
- ⚠️ Requires two domains (mail + admin)
- ⚠️ Slightly more complex setup
- ⚠️ One additional container (Caddy)

## Feature Comparison Matrix

| Feature | Basic | Advanced | Advanced Separate Domains |
|---------|-------|----------|---------------------------|
| **Storage** |
| RocksDB | ✅ | ❌ | ❌ |
| PostgreSQL | ❌ | ✅ | ✅ |
| Redis Cache | ❌ | ✅ | ✅ |
| MinIO/S3 | ❌ | ✅ | ✅ |
| **Security** |
| Admin Panel Security | Direct Exposure | Direct Exposure | Localhost Only |
| Automatic HTTPS | ❌ | ❌ | ✅ |
| Reverse Proxy | ❌ | ❌ | ✅ |
| Security Headers | ❌ | ❌ | ✅ |
| Separate Admin Domain | ❌ | ❌ | ✅ |
| **Operations** |
| Setup Complexity | Simple | Medium | Medium-High |
| Container Count | 1 | 5 | 6 |
| Auto Certificate | ❌ | ❌ | ✅ |
| Scalability | Low | High | High |
| Health Checks | Basic | Complete | Complete |
| **Performance** |
| Recommended Users | < 100 | 1,000-10,000+ | 1,000-10,000+ |
| Caching | ❌ | ✅ | ✅ |
| Blob Storage | Embedded | S3 | S3 |
| Database | Embedded | External | External |

## Decision Tree

```
Do you need PostgreSQL/Redis/MinIO?
│
├─ No ──► Use Basic Setup (docker-compose.yml)
│         • Simple deployment
│         • Small user count
│         • Development/testing
│
└─ Yes ──► Do you need separate admin domain?
           │
           ├─ No ──► Use Advanced Setup (docker-compose.advanced.yml)
           │         • Production deployment
           │         • Manual reverse proxy setup OK
           │         • Don't need automatic HTTPS
           │
           └─ Yes ──► Use Advanced Separate Domains
                     (docker-compose.advanced-separate-domains.yml)
                     • Maximum security
                     • Automatic HTTPS required
                     • Professional domain structure
                     • Enterprise deployment
```

## Security Comparison

### Admin Panel Access

**Basic Setup**:
```
Internet ──► Port 8080 ──► Stalwart Admin (HTTP)
```
- Direct exposure
- HTTP only (unless manually configured)
- Anyone can access port 8080

**Advanced Setup**:
```
Internet ──► Port 8080 ──► Stalwart Admin (HTTP)
```
- Direct exposure
- HTTP only (unless manually configured)
- Requires manual reverse proxy for HTTPS

**Advanced Separate Domains** (Recommended):
```
Internet ──► Port 443 ──► Caddy (HTTPS) ──► Stalwart Admin (localhost)
```
- Admin bound to localhost only
- Automatic HTTPS with Let's Encrypt
- Security headers included
- Cannot access admin directly

### Security Headers Comparison

| Header | Basic | Advanced | Separate Domains |
|--------|-------|----------|------------------|
| HSTS | ❌ | ❌ | ✅ |
| CSP | ❌ | ❌ | ✅ |
| X-Frame-Options | ❌ | ❌ | ✅ |
| X-Content-Type-Options | ❌ | ❌ | ✅ |
| Referrer-Policy | ❌ | ❌ | ✅ |
| Permissions-Policy | ❌ | ❌ | ✅ |

## Port Exposure Comparison

### Basic Setup Ports

```
25     (SMTP)       - Direct to Stalwart
587    (Submission) - Direct to Stalwart
465    (Submissions)- Direct to Stalwart
143    (IMAP)       - Direct to Stalwart
993    (IMAPS)      - Direct to Stalwart
4190   (ManageSieve)- Direct to Stalwart
8080   (Admin HTTP) - Direct to Stalwart ⚠️
443    (Admin HTTPS)- Direct to Stalwart (manual TLS)
```

### Advanced Setup Ports

```
25     (SMTP)       - Direct to Stalwart
587    (Submission) - Direct to Stalwart
465    (Submissions)- Direct to Stalwart
143    (IMAP)       - Direct to Stalwart
993    (IMAPS)      - Direct to Stalwart
110    (POP3)       - Direct to Stalwart
995    (POP3S)      - Direct to Stalwart
4190   (ManageSieve)- Direct to Stalwart
8080   (Admin HTTP) - Direct to Stalwart ⚠️
9000   (MinIO API)  - Direct to MinIO
9001   (MinIO UI)   - Direct to MinIO
```

### Advanced Separate Domains Ports

```
25     (SMTP)       - Direct to Stalwart
587    (Submission) - Direct to Stalwart
465    (Submissions)- Direct to Stalwart
143    (IMAP)       - Direct to Stalwart
993    (IMAPS)      - Direct to Stalwart
110    (POP3)       - Direct to Stalwart
995    (POP3S)      - Direct to Stalwart
4190   (ManageSieve)- Direct to Stalwart
80     (HTTP)       - Caddy (ACME challenge)
443    (HTTPS)      - Caddy ──► Stalwart (localhost) ✅
9001   (MinIO UI)   - MinIO (localhost only)
```

## Resource Usage Comparison

### Basic Setup

```
Memory: ~512 MB - 1 GB
CPU: 0.5-1 cores
Containers: 1
Disk: 10-50 GB
```

### Advanced Setup

```
Memory: ~3-4 GB
CPU: 2-4 cores
Containers: 5
Disk: 100-500 GB
```

### Advanced Separate Domains

```
Memory: ~3.5-4.5 GB (includes Caddy)
CPU: 2-4 cores
Containers: 6
Disk: 100-500 GB
```

## Migration Path

### From Basic to Advanced

1. Export data from RocksDB
2. Set up PostgreSQL/Redis/MinIO
3. Import data to PostgreSQL
4. Switch to advanced compose file

### From Advanced to Advanced Separate Domains

1. Stop services
2. Add domain configuration to .env
3. Switch to separate domains compose file
4. Start services

No data migration needed!

## Recommendations

### Choose Basic Setup If:
- You're testing or evaluating Stalwart
- You have < 100 users
- You don't need external services
- You want minimal complexity

### Choose Advanced Setup If:
- You need PostgreSQL/Redis/MinIO
- You have 1,000+ users
- You're comfortable with manual reverse proxy
- You don't need automatic HTTPS

### Choose Advanced Separate Domains If:
- You need maximum security ⭐ RECOMMENDED
- You want automatic HTTPS
- You need professional domain structure
- You're deploying in production
- You have compliance requirements
- You want best practices out of the box

## Related Documentation

- [Basic Setup - QUICKSTART.md](./QUICKSTART.md)
- [Advanced Setup - MULTI_SERVICE_SETUP.md](./MULTI_SERVICE_SETUP.md)
- [Separate Domains - ADVANCED_SEPARATE_DOMAINS_GUIDE.md](./ADVANCED_SEPARATE_DOMAINS_GUIDE.md)
- [Separate Domains Configuration - SEPARATE_DOMAINS_SETUP.md](./SEPARATE_DOMAINS_SETUP.md)
- [Production Guide - PRODUCTION_QUICK_START.md](./PRODUCTION_QUICK_START.md)

## FAQ

**Q: Can I use Advanced Separate Domains without two domains?**
A: No, this setup requires both mail.example.com and admin.example.com domains.

**Q: Is Advanced Separate Domains slower than Advanced?**
A: No, the only difference is the Caddy reverse proxy for admin, which adds negligible latency.

**Q: Can I migrate from Advanced to Advanced Separate Domains?**
A: Yes! Just stop services, add domain configuration, and switch compose files. No data migration needed.

**Q: Do I need Caddy? Can I use Nginx?**
A: Caddy is included for automatic HTTPS. You can use Nginx instead - see SEPARATE_DOMAINS_SETUP.md.

**Q: What about the cost of an extra container?**
A: Caddy uses ~50-100 MB RAM and minimal CPU. The security benefits far outweigh the cost.

**Q: Can I use Advanced Separate Domains for small deployments?**
A: Yes! It's actually the most secure option regardless of size.

## Conclusion

For **production deployments**, we recommend **Advanced Separate Domains** (`docker-compose.advanced-separate-domains.yml`) because it provides:

- ✅ Maximum security with isolated admin panel
- ✅ Automatic HTTPS with zero configuration
- ✅ Professional domain structure
- ✅ All benefits of advanced setup
- ✅ Production-ready out of the box

The small additional complexity is worth the security and operational benefits.
