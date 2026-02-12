# Multi-Service Docker Setup Guide

## Complete Guide: PostgreSQL + Redis + MinIO Configuration

This guide provides comprehensive instructions for deploying Stalwart Mail Server with **PostgreSQL** (database), **Redis** (cache), and **MinIO** (S3-compatible object storage) using Docker Compose.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Why Use This Setup?](#why-use-this-setup)
3. [Architecture Diagram](#architecture-diagram)
4. [Prerequisites](#prerequisites)
5. [Quick Start](#quick-start)
6. [Detailed Configuration](#detailed-configuration)
7. [Service Details](#service-details)
8. [Environment Variables](#environment-variables)
9. [Storage Configuration](#storage-configuration)
10. [Health Checks & Monitoring](#health-checks--monitoring)
11. [Troubleshooting](#troubleshooting)
12. [Production Considerations](#production-considerations)
13. [Backup & Restore](#backup--restore)
14. [Scaling Strategies](#scaling-strategies)

---

## Overview

**YES, it is absolutely possible** to use PostgreSQL, Redis, and MinIO together in Stalwart Mail Server! This is actually the **recommended configuration** for production deployments with 10,000+ users.

### What Each Service Provides

- **PostgreSQL**: Primary data storage, full-text search, and user directory
- **Redis**: Fast lookup cache for improved performance
- **MinIO**: S3-compatible blob storage for email attachments and large files
- **Stalwart**: Mail server that orchestrates all services

### Benefits of This Architecture

✅ **Scalability**: Each component can be scaled independently  
✅ **Performance**: Redis caching + PostgreSQL indexing + distributed blob storage  
✅ **Reliability**: Separate services mean better fault isolation  
✅ **Flexibility**: Easy to migrate to cloud-managed services (RDS, ElastiCache, S3)  
✅ **Production-Ready**: Battle-tested architecture for large deployments  

---

## Why Use This Setup?

### Use This Multi-Service Setup When:

- 📊 **User count**: 10,000+ users
- 🌍 **Multi-region**: Need distributed storage
- 💾 **Large attachments**: Frequent large file transfers
- 🔄 **High availability**: Need replication and failover
- 📈 **Scalability**: Planning to grow significantly
- 🔍 **Advanced features**: Need SQL access to data for analytics

### Use Simple Setup (RocksDB only) When:

- 👥 **User count**: < 10,000 users
- 💰 **Simple deployment**: Want minimal complexity
- 🚀 **Quick start**: Getting started or testing
- 🏠 **Single server**: No distributed requirements

For the simple setup, see [docker-compose.yml](./docker-compose.yml) and [QUICKSTART.md](./QUICKSTART.md).

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Stalwart Mail Server                    │
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
   │        │    │        │    │ :9001  │    │        │
   └────────┘    └────────┘    └────────┘    └────────┘
   │        │    │        │    │        │
   │ Persist│    │ Memory │    │ S3     │
   │ Volume │    │ Volume │    │ Volume │
   └────────┘    └────────┘    └────────┘
```

**Data Flow:**
1. Emails arrive via SMTP/IMAP
2. **Metadata** stored in PostgreSQL
3. **Large attachments** stored in MinIO (S3)
4. **Lookups cached** in Redis for speed
5. **Full-text search** handled by PostgreSQL
6. Admin UI accesses all services via Stalwart

---

## Prerequisites

### Required Software

- **Docker**: Version 20.10 or later
- **Docker Compose**: Version 2.0 or later
- **Git**: For cloning the repository

### System Requirements

**Minimum (Testing/Development):**
- CPU: 4 cores
- RAM: 8 GB
- Disk: 50 GB SSD

**Recommended (Production):**
- CPU: 8+ cores
- RAM: 16+ GB
- Disk: 200+ GB SSD (NVMe preferred)
- Network: 1 Gbps+

### Install Docker & Docker Compose

```bash
# Install Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Verify installation
docker --version
docker compose version

# Logout and login again for group changes to take effect
```

---

## Quick Start

### Step 1: Clone the Repository

```bash
git clone https://github.com/stalwartlabs/stalwart.git
cd stalwart
```

### Step 2: Create Environment File

```bash
# Copy the template
cp .env.template .env

# Edit the file with your secure passwords
nano .env  # or use vim, code, etc.
```

**IMPORTANT**: Replace all `<CHANGE_ME_TO_STRONG_PASSWORD>` placeholders with actual strong passwords!

**Quick password generation:**
```bash
# Generate 4 secure passwords
echo "ADMIN_SECRET=$(openssl rand -base64 32)"
echo "DB_PASSWORD=$(openssl rand -base64 32)"
echo "REDIS_PASSWORD=$(openssl rand -base64 32)"
echo "MINIO_PASSWORD=$(openssl rand -base64 32)"
```

### Step 3: Update Configuration File (Optional)

The configuration file maps how Stalwart uses each service:

```bash
# The config file is already set up, but you can customize it
cat config-advanced.toml

# Key sections:
# - [storage] - Defines which service handles what
# - [store."postgres"] - PostgreSQL connection settings
# - [store."redis"] - Redis connection settings  
# - [store."s3"] - MinIO/S3 connection settings
```

**Note**: Environment variables from `.env` are automatically injected into the configuration using the `%{env:VAR_NAME}%` syntax.

### Step 4: Mount the Configuration (Optional)

If you want to use the advanced configuration:

```bash
# Edit docker-compose.advanced.yml and uncomment the config mount:
# volumes:
#   - ./config-advanced.toml:/opt/stalwart/etc/config.toml:ro
```

**Important**: If you don't mount a custom config, Stalwart will use its default configuration with RocksDB. To use PostgreSQL+Redis+MinIO, you **must** mount the advanced config file.

### Step 5: Start All Services

```bash
# Build and start all containers
docker compose -f docker-compose.advanced.yml up -d --build

# Watch the logs
docker compose -f docker-compose.advanced.yml logs -f

# Wait for all services to be healthy (may take 1-2 minutes)
```

### Step 6: Verify Services are Running

```bash
# Check container status
docker compose -f docker-compose.advanced.yml ps

# All services should show "healthy" or "running"
# Example output:
# NAME                    STATUS
# stalwart                healthy
# stalwart-postgres       healthy
# stalwart-redis          healthy  
# stalwart-minio          healthy
# stalwart-minio-init     exited (0)
```

### Step 7: Access Services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| **Stalwart Admin** | http://localhost:8080 | `admin` / Your `ADMIN_SECRET` |
| **MinIO Console** | http://localhost:9001 | `minioadmin` / Your `MINIO_PASSWORD` |
| **PostgreSQL** | `localhost:5432` | Database: `stalwart`, User: `stalwart`, Password: Your `DB_PASSWORD` |
| **Redis** | `localhost:6379` | Password: Your `REDIS_PASSWORD` |

### Step 8: Test Email Functionality

```bash
# Send a test email via SMTP
telnet localhost 25

# Or use the admin interface to create a user and send test emails
```

---

## Detailed Configuration

### Understanding the Configuration Flow

1. **docker-compose.advanced.yml**: Defines all services and their connections
2. **.env file**: Contains sensitive passwords and environment variables
3. **config-advanced.toml**: Tells Stalwart how to use PostgreSQL, Redis, and MinIO
4. **Stalwart**: Reads config and connects to all services

### Configuration File Breakdown

The `config-advanced.toml` file has these key sections:

```toml
# Tell Stalwart what to use for each purpose
[storage]
data = "postgres"      # User data, emails metadata
fts = "postgres"       # Full-text search
blob = "s3"           # Large files (attachments)
lookup = "redis"      # Fast cache lookups
directory = "internal" # User directory (backed by postgres)

# PostgreSQL connection
[store."postgres"]
type = "postgresql"
host = "%{env:DB_HOST}%"              # From docker-compose: postgres
port = "%{env:DB_PORT}%"              # From docker-compose: 5432
database = "%{env:DB_NAME}%"          # From docker-compose: stalwart
user = "%{env:DB_USER}%"              # From docker-compose: stalwart
password = "%{env:DB_PASSWORD}%"      # From .env file
pool.max-connections = 10

# Redis connection
[store."redis"]
type = "redis"
urls = ["redis://:%{env:REDIS_PASSWORD}%@%{env:REDIS_HOST}%:%{env:REDIS_PORT}%"]
pool.max-connections = 10

# MinIO (S3) connection
[store."s3"]
type = "s3"
endpoint = "%{env:S3_ENDPOINT}%"      # From docker-compose: http://minio:9000
bucket = "%{env:S3_BUCKET}%"          # From docker-compose: stalwart-blobs
region = "%{env:S3_REGION}%"          # Default: us-east-1
access-key = "%{env:S3_ACCESS_KEY}%"  # From .env: MINIO_USER
secret-key = "%{env:S3_SECRET_KEY}%"  # From .env: MINIO_PASSWORD
```

---

## Service Details

### PostgreSQL Database

**Purpose**: Stores all email metadata, user accounts, and provides full-text search.

**What's Stored:**
- User accounts and credentials
- Email metadata (headers, flags, labels)
- Folder structures
- Calendar/Contact data
- Full-text search indices

**Configuration:**
```yaml
postgres:
  image: postgres:16-alpine
  environment:
    POSTGRES_DB: stalwart
    POSTGRES_USER: stalwart
    POSTGRES_PASSWORD: ${DB_PASSWORD:?DB_PASSWORD required}
```

**Data Persistence:**
```bash
# Data is stored in a Docker volume
docker volume inspect stalwart_postgres-data

# Backup database
docker exec stalwart-postgres pg_dump -U stalwart stalwart > backup.sql

# Restore database
docker exec -i stalwart-postgres psql -U stalwart stalwart < backup.sql
```

**Connection from Outside Docker:**
```bash
# Using psql
psql -h localhost -p 5432 -U stalwart -d stalwart

# Using pgAdmin or other GUI tools
# Host: localhost
# Port: 5432
# Database: stalwart
# Username: stalwart
# Password: (your DB_PASSWORD)
```

---

### Redis Cache

**Purpose**: Provides high-speed caching for lookups and frequently accessed data.

**What's Cached:**
- User authentication tokens
- DNS lookups
- SPF/DKIM/DMARC records
- Rate limiting counters
- Temporary session data

**Configuration:**
```yaml
redis:
  image: redis:7-alpine
  command: redis-server --requirepass ${REDIS_PASSWORD:?REDIS_PASSWORD required}
```

**Monitoring Redis:**
```bash
# Connect to Redis CLI
docker exec -it stalwart-redis redis-cli -a "YOUR_REDIS_PASSWORD"

# Check stats
> INFO stats
> INFO memory

# View cached keys (use with caution in production!)
> KEYS *

# Get cache hit/miss ratio
> INFO stats | grep keyspace
```

**Cache Configuration Tips:**
- Redis uses memory only (no persistence by default in this setup)
- Data is rebuilt automatically if Redis restarts
- For production, consider enabling Redis persistence (RDB or AOF)

---

### MinIO Object Storage

**Purpose**: Stores large email attachments and binary files in S3-compatible format.

**What's Stored:**
- Email attachments > 100KB
- Large message bodies
- Backup archives
- Binary blobs

**Configuration:**
```yaml
minio:
  image: minio/minio:latest
  command: server /data --console-address ":9001"
  environment:
    MINIO_ROOT_USER: ${MINIO_USER:-minioadmin}
    MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD:?MINIO_PASSWORD required}
  ports:
    - "9000:9000"  # API
    - "9001:9001"  # Console
```

**MinIO Console Access:**

1. Open http://localhost:9001
2. Login with `minioadmin` / `YOUR_MINIO_PASSWORD`
3. View buckets, objects, and statistics

**Using MinIO CLI:**
```bash
# Install MinIO client
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Configure alias
mc alias set myminio http://localhost:9000 minioadmin YOUR_MINIO_PASSWORD

# List buckets
mc ls myminio

# List objects in stalwart-blobs bucket
mc ls myminio/stalwart-blobs

# Get bucket stats
mc admin info myminio
```

**Bucket Initialization:**

The `minio-init` service automatically creates the `stalwart-blobs` bucket on first startup:

```yaml
minio-init:
  image: minio/mc:latest
  entrypoint: >
    /bin/sh -c "
    /usr/bin/mc alias set myminio http://minio:9000 ${MINIO_USER} ${MINIO_PASSWORD} &&
    /usr/bin/mc mb myminio/stalwart-blobs --ignore-existing &&
    echo 'MinIO bucket initialized successfully'
    "
```

---

### Stalwart Mail Server

**Purpose**: Main mail server that orchestrates all services.

**Ports Exposed:**
- `25`: SMTP (incoming mail)
- `587`: Mail Submission (outgoing mail with auth)
- `465`: Mail Submissions (TLS)
- `143`: IMAP
- `993`: IMAPS (TLS)
- `110`: POP3
- `995`: POP3S (TLS)
- `4190`: ManageSieve
- `8080`: HTTP Admin UI
- `443`: HTTPS Admin UI

**Dependencies:**

Stalwart waits for all services to be healthy before starting:

```yaml
depends_on:
  postgres:
    condition: service_healthy
  redis:
    condition: service_healthy
  minio:
    condition: service_healthy
  minio-init:
    condition: service_completed_successfully
```

---

## Environment Variables

### Required Variables

These **must** be set in your `.env` file:

| Variable | Purpose | Example |
|----------|---------|---------|
| `ADMIN_SECRET` | Admin password for web UI | `MyS3cur3P@ssw0rd!2024` |
| `DB_PASSWORD` | PostgreSQL database password | `db_P@ssw0rd_2024!` |
| `REDIS_PASSWORD` | Redis authentication password | `redis_S3cur3!Pass` |
| `MINIO_PASSWORD` | MinIO root password | `minio_Str0ng!Key` |

### Optional Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `MINIO_USER` | MinIO root username | `minioadmin` |
| `TZ` | Server timezone | `UTC` |
| `STALWART_MEMORY_RESERVATION` | Minimum RAM for Stalwart | `1G` |
| `POSTGRES_MEMORY_RESERVATION` | Minimum RAM for PostgreSQL | `512M` |
| `REDIS_MEMORY_RESERVATION` | Minimum RAM for Redis | `256M` |
| `MINIO_MEMORY_RESERVATION` | Minimum RAM for MinIO | `512M` |

### Docker Environment Variables

These are automatically set by `docker-compose.advanced.yml`:

| Variable | Value | Purpose |
|----------|-------|---------|
| `DB_HOST` | `postgres` | PostgreSQL hostname (Docker network) |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | `stalwart` | Database name |
| `DB_USER` | `stalwart` | Database username |
| `REDIS_HOST` | `redis` | Redis hostname (Docker network) |
| `REDIS_PORT` | `6379` | Redis port |
| `S3_ENDPOINT` | `http://minio:9000` | MinIO API endpoint |
| `S3_BUCKET` | `stalwart-blobs` | S3 bucket name |
| `S3_REGION` | `us-east-1` | S3 region (required for S3 clients) |
| `S3_ACCESS_KEY` | `${MINIO_USER}` | MinIO access key |
| `S3_SECRET_KEY` | `${MINIO_PASSWORD}` | MinIO secret key |

---

## Storage Configuration

### Storage Hierarchy

Stalwart uses different storage backends for different data types:

```
Stalwart Storage Architecture:
│
├── Data Store (PostgreSQL)
│   ├── User accounts
│   ├── Email metadata
│   ├── Folders/Labels
│   └── Settings
│
├── Blob Store (MinIO/S3)
│   ├── Email bodies (> threshold)
│   ├── Attachments
│   └── Binary data
│
├── FTS Store (PostgreSQL)
│   ├── Full-text indices
│   ├── Search tokens
│   └── Stemmed words
│
├── Lookup Store (Redis)
│   ├── DNS cache
│   ├── Auth tokens
│   └── Rate limits
│
└── Directory Store (PostgreSQL)
    ├── User directory
    ├── Groups
    └── Domain config
```

### Why This Architecture?

1. **PostgreSQL**: Excellent for structured data and ACID transactions
2. **MinIO/S3**: Unlimited scalable storage for large files
3. **Redis**: Ultra-fast in-memory cache for hot data
4. **Combined**: Best of all worlds - speed, scale, and reliability

### Customizing Storage Thresholds

You can customize when to use blob storage vs database:

```toml
# In config-advanced.toml
[storage]
data = "postgres"
blob = "s3"

# Store emails > 50KB in S3, smaller ones in PostgreSQL
blob.threshold = 51200  # 50KB in bytes
```

---

## Health Checks & Monitoring

### Health Check Commands

All services include health checks:

```bash
# Check all services
docker compose -f docker-compose.advanced.yml ps

# Check individual service health
docker inspect stalwart --format='{{.State.Health.Status}}'
docker inspect stalwart-postgres --format='{{.State.Health.Status}}'
docker inspect stalwart-redis --format='{{.State.Health.Status}}'
docker inspect stalwart-minio --format='{{.State.Health.Status}}'

# View health check logs
docker inspect stalwart --format='{{json .State.Health}}' | jq
```

### Service-Specific Health Checks

**Stalwart:**
```bash
curl -f http://localhost:8080/health
```

**PostgreSQL:**
```bash
docker exec stalwart-postgres pg_isready -U stalwart
```

**Redis:**
```bash
docker exec stalwart-redis redis-cli -a "YOUR_REDIS_PASSWORD" ping
# Should return: PONG
```

**MinIO:**
```bash
curl -f http://localhost:9000/minio/health/live
```

### Monitoring Logs

```bash
# Follow all logs
docker compose -f docker-compose.advanced.yml logs -f

# Follow specific service
docker compose -f docker-compose.advanced.yml logs -f stalwart
docker compose -f docker-compose.advanced.yml logs -f postgres
docker compose -f docker-compose.advanced.yml logs -f redis
docker compose -f docker-compose.advanced.yml logs -f minio

# Show last 100 lines
docker compose -f docker-compose.advanced.yml logs --tail=100

# Show logs since timestamp
docker compose -f docker-compose.advanced.yml logs --since 2024-01-01T00:00:00
```

### Resource Monitoring

```bash
# Monitor resource usage
docker stats

# Monitor specific container
docker stats stalwart

# Monitor all stalwart containers
docker stats $(docker ps --filter name=stalwart -q)
```

### Setting Up Monitoring (Optional)

For production, consider adding monitoring:

```yaml
# Add to docker-compose.advanced.yml
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Services Won't Start

**Error**: `required variable DB_PASSWORD is missing a value`

**Solution**:
```bash
# Make sure .env file exists and has all required variables
cat .env

# If missing, create from template
cp .env.template .env

# Edit and set all passwords
nano .env
```

---

#### Issue 2: Stalwart Can't Connect to PostgreSQL

**Error in logs**: `Connection refused` or `could not connect to server`

**Solutions**:

1. Check PostgreSQL is running:
```bash
docker compose -f docker-compose.advanced.yml ps postgres
```

2. Verify PostgreSQL is healthy:
```bash
docker inspect stalwart-postgres --format='{{.State.Health.Status}}'
```

3. Test connection manually:
```bash
docker exec stalwart-postgres psql -U stalwart -d stalwart -c "SELECT 1;"
```

4. Check network connectivity:
```bash
docker exec stalwart ping -c 3 postgres
```

5. Verify environment variables:
```bash
docker exec stalwart env | grep DB_
```

---

#### Issue 3: Redis Authentication Failures

**Error**: `NOAUTH Authentication required`

**Solutions**:

1. Check Redis password is set:
```bash
docker exec stalwart env | grep REDIS_PASSWORD
```

2. Test Redis authentication:
```bash
docker exec stalwart-redis redis-cli -a "YOUR_PASSWORD" ping
```

3. Verify Redis configuration:
```bash
docker exec stalwart-redis cat /usr/local/etc/redis/redis.conf | grep requirepass
```

---

#### Issue 4: MinIO Bucket Not Created

**Error**: `Bucket does not exist` or `stalwart-blobs not found`

**Solutions**:

1. Check minio-init container completed:
```bash
docker compose -f docker-compose.advanced.yml ps minio-init
# Should show "Exited (0)"
```

2. Manually create bucket:
```bash
docker exec stalwart-minio mkdir -p /data/stalwart-blobs
```

3. Or use MinIO client:
```bash
# From host machine
mc alias set myminio http://localhost:9000 minioadmin YOUR_MINIO_PASSWORD
mc mb myminio/stalwart-blobs --ignore-existing
```

---

#### Issue 5: Configuration File Not Loading

**Error**: Stalwart using default config instead of advanced config

**Solutions**:

1. Verify config file is mounted:
```bash
docker inspect stalwart --format='{{json .Mounts}}' | jq
```

2. Uncomment the volume mount in docker-compose.advanced.yml:
```yaml
volumes:
  - ./stalwart-data:/opt/stalwart
  - ./config-advanced.toml:/opt/stalwart/etc/config.toml:ro  # <-- Uncomment this
```

3. Restart Stalwart:
```bash
docker compose -f docker-compose.advanced.yml restart stalwart
```

4. Verify config is being used:
```bash
docker exec stalwart cat /opt/stalwart/etc/config.toml | head -20
```

---

#### Issue 6: Permission Denied Errors

**Error**: `Permission denied` when accessing volumes

**Solutions**:

1. Check volume ownership:
```bash
ls -la ./stalwart-data
```

2. Fix permissions:
```bash
sudo chown -R 1000:1000 ./stalwart-data
# Or use your user ID:
sudo chown -R $USER:$USER ./stalwart-data
```

3. For Docker Desktop on Mac/Windows, ensure file sharing is enabled.

---

#### Issue 7: Out of Memory Errors

**Error**: Container killed due to OOM

**Solutions**:

1. Check current memory usage:
```bash
docker stats --no-stream
```

2. Increase memory reservations in `.env`:
```bash
STALWART_MEMORY_RESERVATION=2G
POSTGRES_MEMORY_RESERVATION=1G
REDIS_MEMORY_RESERVATION=512M
MINIO_MEMORY_RESERVATION=1G
```

3. Or add hard limits in docker-compose.advanced.yml:
```yaml
deploy:
  resources:
    limits:
      memory: 4G
```

4. Restart with new limits:
```bash
docker compose -f docker-compose.advanced.yml up -d
```

---

#### Issue 8: Port Already in Use

**Error**: `port is already allocated`

**Solutions**:

1. Check which process is using the port:
```bash
sudo lsof -i :8080  # Replace with your port
sudo netstat -tlnp | grep :8080
```

2. Stop conflicting service or change port in docker-compose.advanced.yml:
```yaml
ports:
  - "8081:8080"  # Map to different host port
```

---

### Debugging Tips

**Enable Debug Logging:**

Add to `config-advanced.toml`:
```toml
[tracer."stdout"]
type = "stdout"
level = "debug"  # Change from "info" to "debug"
enable = true
```

**View Detailed Service Logs:**
```bash
# Stalwart with timestamps
docker compose -f docker-compose.advanced.yml logs -f --timestamps stalwart

# All services with timestamps
docker compose -f docker-compose.advanced.yml logs -f --timestamps
```

**Check Network Connectivity:**
```bash
# Test from Stalwart to other services
docker exec stalwart ping -c 3 postgres
docker exec stalwart ping -c 3 redis
docker exec stalwart ping -c 3 minio

# Test DNS resolution
docker exec stalwart nslookup postgres
docker exec stalwart nslookup redis
docker exec stalwart nslookup minio
```

**Inspect Docker Network:**
```bash
# List networks
docker network ls

# Inspect stalwart network
docker network inspect stalwart_stalwart-net

# View connected containers
docker network inspect stalwart_stalwart-net --format='{{json .Containers}}' | jq
```

---

## Production Considerations

### Security Hardening

#### 1. Use Strong Passwords

```bash
# Generate cryptographically secure passwords
openssl rand -base64 32

# Or use a password manager to generate random passwords
# Minimum 20 characters with mixed case, numbers, and symbols
```

#### 2. Secure Environment File

```bash
# Set strict permissions on .env file
chmod 600 .env
chown root:root .env  # Or your user

# Never commit .env to version control
echo ".env" >> .gitignore
```

#### 3. Use TLS/SSL

Update `config-advanced.toml`:
```toml
[server.listener."https"]
bind = ["0.0.0.0:443"]
protocol = "http"
tls.implicit = true

[server.tls]
certificate = "/path/to/fullchain.pem"
private-key = "/path/to/privkey.pem"

# Or use Let's Encrypt ACME
[acme]
directory = "https://acme-v02.api.letsencrypt.org/directory"
contact = ["mailto:admin@example.com"]
```

#### 4. Firewall Configuration

```bash
# Ubuntu/Debian with UFW
sudo ufw allow 25/tcp    # SMTP
sudo ufw allow 587/tcp   # Submission
sudo ufw allow 465/tcp   # Submissions
sudo ufw allow 143/tcp   # IMAP
sudo ufw allow 993/tcp   # IMAPS
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable

# Do NOT expose PostgreSQL, Redis, or MinIO to the internet
# They should only be accessible via Docker network
```

#### 5. Limit Network Exposure

Modify docker-compose.advanced.yml to not expose internal ports:

```yaml
postgres:
  # Remove or comment out the ports section
  # ports:
  #   - "5432:5432"
  # PostgreSQL only accessible from Docker network

redis:
  # Remove or comment out the ports section
  # Redis only accessible from Docker network

minio:
  ports:
    # Only expose console for admin access
    - "9001:9001"
    # Don't expose API port 9000 to host
```

---

### High Availability

#### Database Replication

For PostgreSQL HA:

```yaml
# Add a replica (simplified example)
postgres-replica:
  image: postgres:16-alpine
  environment:
    POSTGRES_PRIMARY_HOST: postgres
    POSTGRES_PRIMARY_PORT: 5432
    # ... replication settings
```

See [PostgreSQL Replication Docs](https://www.postgresql.org/docs/current/high-availability.html)

#### Redis Sentinel

For Redis HA:

```yaml
# Add Redis Sentinel nodes
redis-sentinel-1:
  image: redis:7-alpine
  command: redis-sentinel /etc/redis/sentinel.conf
```

See [Redis Sentinel Docs](https://redis.io/docs/management/sentinel/)

#### Load Balancing

Use HAProxy or Nginx to load balance across multiple Stalwart instances:

```nginx
# Nginx config example
upstream stalwart_smtp {
    server stalwart1:25;
    server stalwart2:25;
    server stalwart3:25;
}

server {
    listen 25;
    proxy_pass stalwart_smtp;
}
```

---

### Backup Strategies

#### Automated Backup Script

```bash
#!/bin/bash
# backup.sh - Complete backup script

BACKUP_DIR="/backup/stalwart-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL
echo "Backing up PostgreSQL..."
docker exec stalwart-postgres pg_dump -U stalwart stalwart | gzip > "$BACKUP_DIR/postgres.sql.gz"

# Backup MinIO bucket
echo "Backing up MinIO..."
mc mirror myminio/stalwart-blobs "$BACKUP_DIR/minio-blobs/"

# Backup Redis (optional, as it's just cache)
echo "Backing up Redis..."
docker exec stalwart-redis redis-cli -a "$REDIS_PASSWORD" BGSAVE

# Backup Stalwart config
echo "Backing up configuration..."
cp -r ./stalwart-data/etc "$BACKUP_DIR/config/"

# Compress everything
echo "Compressing backup..."
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "Backup complete: $BACKUP_DIR.tar.gz"
```

#### Set Up Cron Job

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /opt/stalwart/backup.sh >> /var/log/stalwart-backup.log 2>&1
```

---

### Performance Tuning

#### PostgreSQL Optimization

```toml
# In config-advanced.toml
[store."postgres"]
pool.max-connections = 20      # Increase for high load
pool.min-connections = 10
pool.max-lifetime = "30m"
```

Add to docker-compose.advanced.yml:
```yaml
postgres:
  command: 
    - "postgres"
    - "-c"
    - "shared_buffers=256MB"
    - "-c"
    - "effective_cache_size=1GB"
    - "-c"
    - "maintenance_work_mem=64MB"
    - "-c"
    - "max_connections=200"
```

#### Redis Optimization

```yaml
redis:
  command: >
    redis-server
    --requirepass ${REDIS_PASSWORD}
    --maxmemory 2gb
    --maxmemory-policy allkeys-lru
    --save ""  # Disable persistence for pure cache
```

#### MinIO Performance

```yaml
minio:
  environment:
    MINIO_ROOT_USER: ${MINIO_USER}
    MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD}
    MINIO_CACHE: "on"
    MINIO_CACHE_SIZE: 10GB
```

---

## Backup & Restore

### Full Backup Procedure

#### 1. Stop Services (Recommended)

```bash
# Stop Stalwart to ensure consistency
docker compose -f docker-compose.advanced.yml stop stalwart

# Keep databases running for backup
```

#### 2. Backup PostgreSQL

```bash
# Create SQL dump
docker exec stalwart-postgres pg_dump -U stalwart stalwart > backup-$(date +%Y%m%d).sql

# Or use pg_dumpall for all databases
docker exec stalwart-postgres pg_dumpall -U stalwart > backup-all-$(date +%Y%m%d).sql

# Compress the backup
gzip backup-$(date +%Y%m%d).sql
```

#### 3. Backup MinIO Data

```bash
# Using MinIO client
mc mirror myminio/stalwart-blobs ./backup-minio-$(date +%Y%m%d)

# Or backup the entire Docker volume
docker run --rm -v stalwart_minio-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/minio-data-$(date +%Y%m%d).tar.gz /data
```

#### 4. Backup Configuration

```bash
# Backup Stalwart configuration and data directory
tar czf stalwart-config-$(date +%Y%m%d).tar.gz ./stalwart-data/

# Backup docker-compose and .env (without exposing secrets)
cp docker-compose.advanced.yml backup-docker-compose-$(date +%Y%m%d).yml
# Note: Don't backup .env with secrets to public locations
```

#### 5. Restart Services

```bash
docker compose -f docker-compose.advanced.yml start stalwart
```

---

### Restore Procedure

#### 1. Stop All Services

```bash
docker compose -f docker-compose.advanced.yml down
```

#### 2. Restore PostgreSQL

```bash
# Start only PostgreSQL
docker compose -f docker-compose.advanced.yml up -d postgres

# Wait for it to be ready
sleep 10

# Restore from backup
gunzip < backup-20240101.sql.gz | docker exec -i stalwart-postgres psql -U stalwart stalwart

# Or restore from uncompressed file
docker exec -i stalwart-postgres psql -U stalwart stalwart < backup-20240101.sql
```

#### 3. Restore MinIO Data

```bash
# Start MinIO
docker compose -f docker-compose.advanced.yml up -d minio

# Restore using MinIO client
mc mirror ./backup-minio-20240101/ myminio/stalwart-blobs

# Or restore Docker volume
docker run --rm -v stalwart_minio-data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/minio-data-20240101.tar.gz -C /
```

#### 4. Restore Configuration

```bash
# Extract configuration backup
tar xzf stalwart-config-20240101.tar.gz

# Ensure correct permissions
chmod 600 .env
chown -R $USER:$USER ./stalwart-data
```

#### 5. Start All Services

```bash
docker compose -f docker-compose.advanced.yml up -d

# Verify all services are healthy
docker compose -f docker-compose.advanced.yml ps
```

---

### Backup to Cloud Storage

#### AWS S3 Backup

```bash
# Install AWS CLI
apt-get install awscli

# Configure credentials
aws configure

# Backup to S3
#!/bin/bash
BACKUP_FILE="stalwart-backup-$(date +%Y%m%d).tar.gz"

# Create comprehensive backup
docker exec stalwart-postgres pg_dump -U stalwart stalwart | gzip > postgres.sql.gz
mc mirror myminio/stalwart-blobs ./minio-backup
tar czf "$BACKUP_FILE" postgres.sql.gz minio-backup/ stalwart-data/

# Upload to S3
aws s3 cp "$BACKUP_FILE" s3://your-bucket/stalwart-backups/

# Clean up local files
rm -f postgres.sql.gz "$BACKUP_FILE"
rm -rf minio-backup/
```

---

## Scaling Strategies

### When to Scale

Monitor these metrics:

- **CPU Usage**: Consistently > 70%
- **Memory Usage**: Consistently > 80%
- **Disk I/O**: High wait times
- **Queue Length**: Growing email queues
- **Response Time**: Slow IMAP/SMTP responses

### Vertical Scaling (Scale Up)

Increase resources for existing containers:

```yaml
# In .env file
STALWART_MEMORY_RESERVATION=4G
STALWART_CPU_RESERVATION=4
POSTGRES_MEMORY_RESERVATION=2G
REDIS_MEMORY_RESERVATION=1G
```

### Horizontal Scaling (Scale Out)

#### 1. Multiple Stalwart Instances

```yaml
# docker-compose.scale.yml
services:
  stalwart-1:
    extends: stalwart
    container_name: stalwart-1

  stalwart-2:
    extends: stalwart
    container_name: stalwart-2

  stalwart-3:
    extends: stalwart
    container_name: stalwart-3

  # Load balancer
  haproxy:
    image: haproxy:latest
    ports:
      - "25:25"
      - "587:587"
      - "143:143"
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
```

#### 2. PostgreSQL Read Replicas

Set up PostgreSQL replication:

```yaml
postgres-primary:
  image: postgres:16-alpine
  environment:
    POSTGRES_PRIMARY: "true"

postgres-replica-1:
  image: postgres:16-alpine
  environment:
    POSTGRES_PRIMARY_HOST: postgres-primary

postgres-replica-2:
  image: postgres:16-alpine
  environment:
    POSTGRES_PRIMARY_HOST: postgres-primary
```

#### 3. Redis Cluster

For Redis clustering:

```yaml
redis-1:
  image: redis:7-alpine
  command: redis-server --cluster-enabled yes

redis-2:
  image: redis:7-alpine
  command: redis-server --cluster-enabled yes

redis-3:
  image: redis:7-alpine
  command: redis-server --cluster-enabled yes
```

#### 4. MinIO Distributed Mode

MinIO supports distributed deployment:

```yaml
# Requires 4+ nodes for erasure coding
minio-1:
  image: minio/minio:latest
  command: server http://minio-{1...4}/data{1...4}

minio-2:
  image: minio/minio:latest
  command: server http://minio-{1...4}/data{1...4}

# ... up to minio-4
```

See [MinIO Distributed Setup](https://min.io/docs/minio/linux/operations/install-deploy-manage/deploy-minio-multi-node-multi-drive.html)

---

### Cloud Migration

#### Migrate to Managed Services

Replace Docker containers with cloud-managed services:

```toml
# config-cloud.toml

# Use Amazon RDS instead of Docker PostgreSQL
[store."postgres"]
type = "postgresql"
host = "stalwart.abc123.us-east-1.rds.amazonaws.com"
port = 5432
database = "stalwart"
user = "stalwart"
password = "%{env:DB_PASSWORD}%"

# Use Amazon ElastiCache instead of Docker Redis
[store."redis"]
type = "redis"
urls = ["redis://:PASSWORD@stalwart.abc123.cache.amazonaws.com:6379"]

# Use Amazon S3 instead of MinIO
[store."s3"]
type = "s3"
bucket = "stalwart-production-blobs"
region = "us-east-1"
# Uses AWS IAM role or credentials from environment
```

#### Benefits of Managed Services:

✅ Automatic backups  
✅ Automatic failover  
✅ Managed updates and patches  
✅ Built-in monitoring  
✅ Multi-AZ availability  
✅ Better SLAs  

---

## Summary

### What We've Covered

✅ **Confirmed**: YES, PostgreSQL + Redis + MinIO work perfectly together  
✅ **Architecture**: Understanding how services interact  
✅ **Setup**: Complete step-by-step installation  
✅ **Configuration**: Detailed configuration options  
✅ **Monitoring**: Health checks and logging  
✅ **Troubleshooting**: Common issues and solutions  
✅ **Production**: Security, HA, and scaling strategies  
✅ **Backups**: Comprehensive backup and restore procedures  

### Quick Command Reference

```bash
# Start services
docker compose -f docker-compose.advanced.yml up -d --build

# Stop services
docker compose -f docker-compose.advanced.yml down

# View logs
docker compose -f docker-compose.advanced.yml logs -f

# Check health
docker compose -f docker-compose.advanced.yml ps

# Restart a service
docker compose -f docker-compose.advanced.yml restart stalwart

# Backup PostgreSQL
docker exec stalwart-postgres pg_dump -U stalwart stalwart > backup.sql

# Access MinIO console
# http://localhost:9001

# Access Stalwart admin
# http://localhost:8080
```

### Next Steps

1. ✅ Complete the [Quick Start](#quick-start) section
2. ✅ Test email functionality
3. ✅ Set up TLS certificates
4. ✅ Configure DNS records (MX, SPF, DKIM)
5. ✅ Set up automated backups
6. ✅ Configure monitoring
7. ✅ Review security hardening
8. ✅ Test disaster recovery

---

## Additional Resources

- **Main Setup Guide**: [SETUP.md](./SETUP.md)
- **Quick Start**: [QUICKSTART.md](./QUICKSTART.md)
- **Scaling Guide**: [SCALING_GUIDE.md](./SCALING_GUIDE.md)
- **Official Docs**: https://stalw.art/docs
- **GitHub**: https://github.com/stalwartlabs/stalwart
- **Community**: Discord, Reddit, Mastodon

---

## Support

If you encounter issues:

1. Check [Troubleshooting](#troubleshooting) section
2. Search [GitHub Issues](https://github.com/stalwartlabs/stalwart/issues)
3. Join the [Discord community](https://discord.com/servers/stalwart-923615863037390889)
4. Post on [r/stalwartlabs](https://www.reddit.com/r/stalwartlabs/)

---

**Happy Mailing! 📧**
