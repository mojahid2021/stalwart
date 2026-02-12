# Multi-Service Setup - Implementation Summary

## ✅ Task Completed Successfully

This document summarizes the comprehensive updates made to enable and document PostgreSQL, Redis, and MinIO deployment together with Stalwart Mail Server.

---

## 🎯 Answer to Your Question

**YES, it is absolutely possible to use PostgreSQL, Redis, and MinIO together in this project!**

This is actually the **recommended configuration** for production deployments with 10,000+ users. The repository already had the infrastructure (`docker-compose.advanced.yml` and `config-advanced.toml`), but it needed comprehensive documentation and validation tooling - which we've now added.

---

## 📦 What Was Added

### 1. Comprehensive Documentation

#### **MULTI_SERVICE_SETUP.md** (38KB)
A complete guide covering everything you need to know:

- **Architecture Overview**: Diagrams showing how all services work together
- **Quick Start**: Step-by-step setup instructions with validation
- **Service Details**: Deep dive into PostgreSQL, Redis, and MinIO configuration
- **Environment Variables**: Complete reference for all configuration options
- **Troubleshooting**: 8+ common issues with detailed solutions
- **Production**: Security hardening, HA, and deployment strategies
- **Backup & Restore**: Complete procedures for all services
- **Scaling**: Vertical and horizontal scaling strategies
- **Monitoring**: Health checks, logging, and observability setup

### 2. Configuration Examples

#### **.env.example** (3.7KB)
A working example environment file with:
- All required environment variables
- Secure placeholder values (REPLACE_WITH_STRONG_RANDOM_PASSWORD)
- Inline documentation explaining each variable
- Resource configuration examples
- Security notes and best practices

### 3. Validation Tooling

#### **validate-setup.sh** (6.7KB)
An automated validation script that checks:
- ✅ Docker and Docker Compose installation
- ✅ Required files exist (.env, docker-compose files, configs)
- ✅ Environment variables are set and not using weak passwords
- ✅ Sufficient disk space (20GB+) and memory (4GB+)
- ✅ Required ports are available (25, 587, 8080, 9000, etc.)
- ✅ Docker Compose file syntax is valid
- ✅ Provides clear error messages and remediation steps

### 4. Documentation Updates

Updated existing files to reference the new multi-service setup:
- **README.md**: Added prominent link to multi-service guide
- **SETUP.md**: Added dedicated section linking to detailed guide
- **QUICKSTART.md**: Updated to include new documentation references
- **docker-compose.advanced.yml**: Enhanced with documentation links and quick start

---

## 🏗️ Architecture

Here's what the multi-service architecture looks like:

```
┌─────────────────────────────────────────────────────────────┐
│                   Stalwart Mail Server                       │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐           │
│  │ SMTP   │  │ IMAP   │  │ Admin  │  │  API   │           │
│  │ :25    │  │ :143   │  │ :8080  │  │        │           │
│  │ :587   │  │ :993   │  │ :443   │  │        │           │
│  └────────┘  └────────┘  └────────┘  └────────┘           │
└──────┬──────────────┬──────────────┬─────────────┬─────────┘
       │              │              │             │
       │ Data         │ Cache        │ Blobs       │ Search
       │              │              │             │
   ┌───▼────┐    ┌───▼────┐    ┌───▼────┐    ┌───▼────┐
   │PostgreSQL   │ Redis  │    │ MinIO  │    │PostgreSQL
   │  :5432 │    │ :6379  │    │ :9000  │    │  FTS   │
   └────────┘    └────────┘    └────────┘    └────────┘
```

**What Each Service Provides:**
- **PostgreSQL**: Primary data storage, full-text search, user directory
- **Redis**: Fast lookup cache for improved performance
- **MinIO**: S3-compatible blob storage for email attachments
- **Stalwart**: Mail server orchestrating all services

---

## 🚀 Quick Start Guide

### Prerequisites
- Docker 20.10+ installed
- Docker Compose 2.0+ installed
- At least 8GB RAM and 50GB disk space

### Steps

1. **Clone the repository** (if not already):
   ```bash
   git clone https://github.com/stalwartlabs/stalwart.git
   cd stalwart
   ```

2. **Create environment file**:
   ```bash
   cp .env.example .env
   nano .env  # Edit and set secure passwords
   ```

3. **Generate secure passwords**:
   ```bash
   # Generate 4 strong passwords
   echo "ADMIN_SECRET=$(openssl rand -base64 32)"
   echo "DB_PASSWORD=$(openssl rand -base64 32)"
   echo "REDIS_PASSWORD=$(openssl rand -base64 32)"
   echo "MINIO_PASSWORD=$(openssl rand -base64 32)"
   ```

4. **Validate your setup** (recommended):
   ```bash
   chmod +x validate-setup.sh
   ./validate-setup.sh
   ```

5. **Start all services**:
   ```bash
   docker compose -f docker-compose.advanced.yml up -d --build
   ```

6. **Monitor startup**:
   ```bash
   docker compose -f docker-compose.advanced.yml logs -f
   # Wait for all services to be healthy (1-2 minutes)
   ```

7. **Verify services are running**:
   ```bash
   docker compose -f docker-compose.advanced.yml ps
   # All should show "healthy" status
   ```

8. **Access services**:
   - **Stalwart Admin**: http://localhost:8080 (login: admin / your ADMIN_SECRET)
   - **MinIO Console**: http://localhost:9001 (login: minioadmin / your MINIO_PASSWORD)

---

## 📊 Service Configuration

### Storage Hierarchy

Stalwart uses different backends for different data types:

```toml
[storage]
data = "postgres"      # User data, email metadata
fts = "postgres"       # Full-text search
blob = "s3"           # Large files (attachments)
lookup = "redis"      # Fast cache lookups
directory = "internal" # User directory (backed by postgres)
```

### Connection Details

All services are configured via environment variables:

```bash
# PostgreSQL
DB_HOST=postgres
DB_PORT=5432
DB_NAME=stalwart
DB_USER=stalwart
DB_PASSWORD=${DB_PASSWORD}  # From .env

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}  # From .env

# MinIO/S3
S3_ENDPOINT=http://minio:9000
S3_BUCKET=stalwart-blobs
S3_ACCESS_KEY=${MINIO_USER}
S3_SECRET_KEY=${MINIO_PASSWORD}  # From .env
```

---

## 🔧 Configuration Files

### Files in Repository

1. **docker-compose.advanced.yml** - Defines all services and connections
2. **config-advanced.toml** - Tells Stalwart how to use each service
3. **.env.example** - Template for environment variables
4. **validate-setup.sh** - Pre-deployment validation script

### How They Work Together

```
.env → docker-compose.advanced.yml → Stalwart Container
                                    → config-advanced.toml
                                    → Connects to services
```

---

## 🛠️ Common Commands

```bash
# Validate setup
./validate-setup.sh

# Start services
docker compose -f docker-compose.advanced.yml up -d --build

# View logs
docker compose -f docker-compose.advanced.yml logs -f

# Check status
docker compose -f docker-compose.advanced.yml ps

# Restart a service
docker compose -f docker-compose.advanced.yml restart stalwart

# Stop all services
docker compose -f docker-compose.advanced.yml down

# Stop and remove all data (WARNING: destructive!)
docker compose -f docker-compose.advanced.yml down -v

# Backup PostgreSQL
docker exec stalwart-postgres pg_dump -U stalwart stalwart > backup.sql

# Restore PostgreSQL
docker exec -i stalwart-postgres psql -U stalwart stalwart < backup.sql
```

---

## 🔒 Security Notes

### Password Security

✅ **DO**:
- Use `openssl rand -base64 32` to generate passwords
- Set file permissions: `chmod 600 .env`
- Use different passwords for each service
- Rotate passwords regularly

❌ **DON'T**:
- Use the placeholder passwords in production
- Commit `.env` to version control
- Use common or weak passwords
- Reuse passwords across services

### Network Security

For production:
- Don't expose PostgreSQL, Redis ports to the internet
- Use TLS/SSL for all external connections
- Configure firewall rules properly
- Enable UFW or iptables

---

## 📈 When to Use This Setup

### Use Multi-Service Setup (PostgreSQL + Redis + MinIO) When:

✅ User count: 10,000+ users
✅ Need distributed storage
✅ Large attachments common
✅ High availability required
✅ Planning to scale significantly
✅ Need SQL access for analytics

### Use Simple Setup (RocksDB) When:

✅ User count: < 10,000 users
✅ Want minimal complexity
✅ Getting started or testing
✅ Single server deployment

---

## 🐛 Troubleshooting

See **MULTI_SERVICE_SETUP.md** for comprehensive troubleshooting, including:

- Services won't start
- Connection failures (PostgreSQL, Redis, MinIO)
- Authentication issues
- Bucket not created
- Configuration not loading
- Permission denied errors
- Out of memory
- Port conflicts

Each issue includes:
- Error symptoms
- Root causes
- Step-by-step solutions
- Verification steps

---

## 📚 Documentation Structure

```
stalwart/
├── README.md                     # Project overview + quick links
├── QUICKSTART.md                 # 5-minute quick start
├── MULTI_SERVICE_SETUP.md        # ⭐ NEW: Complete multi-service guide
├── SETUP.md                      # Comprehensive setup guide
├── SCALING_GUIDE.md              # Scaling strategies
├── docker-compose.yml            # Simple setup (RocksDB)
├── docker-compose.advanced.yml   # Multi-service setup
├── config-advanced.toml          # Advanced configuration
├── .env.template                 # Environment template (existing)
├── .env.example                  # ⭐ NEW: Working example
└── validate-setup.sh             # ⭐ NEW: Validation script
```

---

## ✅ Validation Results

All configurations have been validated:

- ✅ **docker-compose.advanced.yml**: Syntax valid
- ✅ **docker-compose.yml**: Syntax valid
- ✅ **config-advanced.toml**: Format valid
- ✅ **validate-setup.sh**: Tested and working
- ✅ **Code Review**: Completed, feedback addressed
- ✅ **Security Review**: Completed (no code changes)

---

## 🎓 Next Steps

1. **Read the Guide**: Start with [MULTI_SERVICE_SETUP.md](./MULTI_SERVICE_SETUP.md)
2. **Try It Out**: Follow the Quick Start above
3. **Production Deployment**: Review the Production Considerations section
4. **Join Community**: Get help on Discord, Reddit, or GitHub

---

## 📞 Support

If you need help:

1. Check [MULTI_SERVICE_SETUP.md](./MULTI_SERVICE_SETUP.md) troubleshooting section
2. Run `./validate-setup.sh` to diagnose issues
3. Search [GitHub Issues](https://github.com/stalwartlabs/stalwart/issues)
4. Join [Discord community](https://discord.com/servers/stalwart-923615863037390889)
5. Post on [r/stalwartlabs](https://www.reddit.com/r/stalwartlabs/)

---

## 🌟 Summary

**You now have everything you need to deploy Stalwart with PostgreSQL, Redis, and MinIO!**

The complete infrastructure was already present in the repository - we've added comprehensive documentation, validation tooling, and examples to make it easy to use.

**Key Features Added:**
- ✅ 38KB comprehensive setup guide
- ✅ Automated validation script
- ✅ Secure configuration examples
- ✅ Architecture diagrams
- ✅ Troubleshooting guide with 8+ scenarios
- ✅ Production best practices
- ✅ Backup and scaling strategies

**Happy Mailing! 📧**

---

*Document created: 2024-02-12*
*Repository: stalwartlabs/stalwart*
*Branch: copilot/update-docs-and-docker-compose*
