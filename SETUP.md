# Stalwart Mail Server - Complete Setup Guide

This comprehensive guide covers everything you need to know about running, building, and deploying **Stalwart Mail Server** from source. This guide focuses on building from the codebase without downloading pre-built images from Docker Hub.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Prerequisites](#prerequisites)
3. [Running Locally (Native Build)](#running-locally-native-build)
4. [Building Docker Images from Source](#building-docker-images-from-source)
5. [Running in Docker Container](#running-in-docker-container)
6. [Docker Compose Setup](#docker-compose-setup)
7. [Configuration Guide](#configuration-guide)
8. [Testing](#testing)
9. [Pros and Cons](#pros-and-cons)
10. [Troubleshooting](#troubleshooting)

---

## Project Overview

**Stalwart** is a modern, open-source mail and collaboration server written in Rust. It's feature-complete and supports:

- **Email protocols**: SMTP, IMAP, POP3, JMAP, ManageSieve
- **Collaboration protocols**: CalDAV, CardDAV, WebDAV
- **Storage backends**: RocksDB, PostgreSQL, MySQL, SQLite, S3, Redis, Azure, FoundationDB
- **Security**: Built-in spam filtering, DMARC, DKIM, SPF, ARC, MTA-STS, DANE
- **Enterprise features**: Multi-tenancy, clustering, OAuth 2.0, OIDC, LDAP

### Project Structure

```
stalwart/
├── crates/           # Rust workspace with 20+ crates
│   ├── main/        # Main stalwart binary
│   ├── cli/         # CLI tool
│   ├── smtp/        # SMTP server implementation
│   ├── imap/        # IMAP server implementation
│   ├── jmap/        # JMAP server implementation
│   └── ...          # Other protocol and utility crates
├── tests/           # Integration tests
├── resources/       # Configuration templates and resources
│   ├── config/     # Default configuration files
│   └── docker/     # Docker-related scripts
├── Dockerfile       # Standard multi-arch Docker build
├── Dockerfile.build # Advanced build with zig cross-compilation
├── docker-bake.hcl  # Docker buildx bake configuration
├── Cargo.toml       # Rust workspace configuration
└── install.sh       # Production installation script
```

---

## Prerequisites

### For Local Development (Native Build)

1. **Rust Toolchain** (1.75.0 or later)
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   ```

2. **System Dependencies**
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y build-essential pkg-config libssl-dev libclang-dev

   # macOS
   brew install openssl pkg-config

   # Fedora/RHEL
   sudo dnf install -y gcc gcc-c++ openssl-devel clang-devel
   ```

3. **Optional: FoundationDB Client** (if using FoundationDB backend)
   ```bash
   # Download from https://github.com/apple/foundationdb/releases
   # Example for Ubuntu:
   wget https://github.com/apple/foundationdb/releases/download/7.1.38/foundationdb-clients_7.1.38-1_amd64.deb
   sudo dpkg -i foundationdb-clients_7.1.38-1_amd64.deb
   ```

### For Docker Build

1. **Docker** (20.10 or later)
   ```bash
   # Install Docker Engine
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   ```

2. **Docker Buildx** (for multi-architecture builds)
   ```bash
   # Usually included with Docker Desktop
   # Or install manually:
   docker buildx version
   ```

3. **Docker Compose** (v2.0 or later)
   ```bash
   # Usually included with Docker Desktop
   # Or install standalone:
   sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

---

## Running Locally (Native Build)

### Step 1: Clone the Repository

```bash
git clone https://github.com/stalwartlabs/stalwart.git
cd stalwart
```

### Step 2: Choose Your Build Features

Stalwart supports multiple storage backends via Cargo features:

**Available features:**
- `rocks` - RocksDB storage (default, recommended for most users)
- `sqlite` - SQLite storage
- `postgres` - PostgreSQL storage
- `mysql` - MySQL/MariaDB storage
- `foundationdb` - FoundationDB storage
- `s3` - S3-compatible blob storage
- `redis` - Redis support for caching/queuing
- `azure` - Azure blob storage
- `nats` - NATS message broker
- `kafka` - Kafka message broker
- `zenoh` - Zenoh protocol
- `enterprise` - Enterprise features (enabled by default)

**Default features:** `rocks` and `enterprise`

### Step 3: Build the Project

#### Option A: Build with Default Features (RocksDB + Enterprise)

```bash
# Debug build (faster compilation, slower runtime)
cargo build -p stalwart

# Release build (optimized, recommended for production)
cargo build --release -p stalwart
```

#### Option B: Build with All Storage Backends

```bash
cargo build --release -p stalwart --features "sqlite,postgres,mysql,rocks,s3,redis,azure,nats,enterprise"
```

#### Option C: Build with Specific Features

```bash
# Example: PostgreSQL + S3 + Redis
cargo build --release -p stalwart --no-default-features --features "postgres,s3,redis,enterprise"
```

#### Build the CLI Tool

```bash
cargo build --release -p stalwart-cli
```

**Build output location:**
- Debug: `target/debug/stalwart`
- Release: `target/release/stalwart`

### Step 4: Initialize Configuration

```bash
# Create directory structure
mkdir -p /tmp/stalwart-data

# Initialize with default configuration
./target/release/stalwart --init /tmp/stalwart-data

# This creates:
# /tmp/stalwart-data/etc/config.toml
# /tmp/stalwart-data/data/
# /tmp/stalwart-data/logs/
```

### Step 5: Configure the Server

Edit the configuration file:

```bash
nano /tmp/stalwart-data/etc/config.toml
```

**Minimal configuration example:**

```toml
[server.listener."smtp"]
bind = ["0.0.0.0:25"]
protocol = "smtp"

[server.listener."submission"]
bind = ["0.0.0.0:587"]
protocol = "smtp"

[server.listener."imap"]
bind = ["0.0.0.0:143"]
protocol = "imap"

[server.listener."https"]
bind = ["0.0.0.0:8080"]  # Use 8080 for non-root or change to 443
protocol = "http"
tls.implicit = false  # Set to true for HTTPS on port 443

[storage]
data = "rocksdb"
fts = "rocksdb"
blob = "rocksdb"
lookup = "rocksdb"
directory = "internal"

[store."rocksdb"]
type = "rocksdb"
path = "/tmp/stalwart-data/data"

[directory."internal"]
type = "internal"
store = "rocksdb"

[authentication.fallback-admin]
user = "admin"
secret = "CHANGE_ME_TO_STRONG_PASSWORD"  # Change this!

[tracer."stdout"]
type = "stdout"
level = "info"
enable = true
```

### Step 6: Run the Server

```bash
# Run with custom config
./target/release/stalwart --config /tmp/stalwart-data/etc/config.toml

# Or use environment variable for admin password
ADMIN_SECRET=mysecurepassword ./target/release/stalwart --config /tmp/stalwart-data/etc/config.toml
```

### Step 7: Access the Admin Interface

Open your browser and navigate to:
- **Web Admin UI**: http://localhost:8080
- **Default credentials**: admin / CHANGE_ME_TO_STRONG_PASSWORD (or your ADMIN_SECRET from config)

**Security Note**: Always change the default admin password before exposing the server to the network!

### Step 8: Testing the Installation

```bash
# Run the test suite
cargo test --workspace --all-features

# Run specific test suites
cargo test -p jmap_proto      # JMAP protocol tests
cargo test -p imap_proto      # IMAP protocol tests
cargo test -p tests smtp      # SMTP tests
cargo test -p tests imap      # IMAP tests
cargo test -p tests jmap      # JMAP tests
```

---

## Building Docker Images from Source

Stalwart provides two Dockerfiles with different approaches:

### Option 1: Standard Dockerfile (Recommended for Most Users)

This uses `cargo-chef` for efficient layer caching and builds for multiple architectures.

```bash
# Build for your current architecture
docker build -t stalwart:local -f Dockerfile .

# This will take 15-30 minutes on first build
# Subsequent builds are faster due to cargo-chef caching
```

**What this Dockerfile does:**
1. Uses cargo-chef to prepare dependency cache
2. Builds all dependencies first (cached layer)
3. Builds stalwart with features: `sqlite postgres mysql rocks s3 redis azure nats enterprise`
4. Builds stalwart-cli
5. Creates minimal Debian-based runtime image
6. Exposes ports: 443, 25, 110, 587, 465, 143, 993, 995, 4190, 8080

### Option 2: Advanced Dockerfile.build (For Advanced Users)

This uses Zig for cross-compilation and supports additional features.

```bash
# Setup buildx builder
docker buildx create --name stalwart-builder --use
docker buildx inspect --bootstrap

# Build for specific architecture
docker buildx build \
  --file Dockerfile.build \
  --target gnu \
  --build-arg TARGET=x86_64-unknown-linux-gnu \
  --tag stalwart:local-advanced \
  --load \
  .

# Build for ARM64
docker buildx build \
  --file Dockerfile.build \
  --target gnu \
  --build-arg TARGET=aarch64-unknown-linux-gnu \
  --tag stalwart:local-arm64 \
  --load \
  .

# Build multi-architecture image
docker buildx build \
  --file Dockerfile.build \
  --target gnu \
  --platform linux/amd64,linux/arm64 \
  --tag stalwart:local-multi \
  --push \
  .
```

### Option 3: Using docker-bake.hcl (CI/CD Style)

This is what the official CI uses:

```bash
# Build binaries only
TARGET=x86_64-unknown-linux-gnu \
GHCR_REPO=local/stalwart \
docker buildx bake --file docker-bake.hcl build

# Build complete image
TARGET=x86_64-unknown-linux-gnu \
GHCR_REPO=local/stalwart \
DOCKER_PLATFORM=linux/amd64 \
docker buildx bake --file docker-bake.hcl image --load
```

### Verify Your Built Image

```bash
# Check image size and details
docker images stalwart:local

# Test the image
docker run --rm stalwart:local /usr/local/bin/stalwart --version

# Check included binaries
docker run --rm stalwart:local ls -lh /usr/local/bin/
```

---

## Running in Docker Container

### Quick Start with Built Image

```bash
# Create directories for persistent data
mkdir -p ./stalwart-data

# Run container with automatic initialization
docker run -d \
  --name stalwart \
  -p 25:25 \
  -p 587:587 \
  -p 465:465 \
  -p 143:143 \
  -p 993:993 \
  -p 443:443 \
  -p 8080:8080 \
  -v ./stalwart-data:/opt/stalwart \
  -e ADMIN_SECRET=MyS3cur3P@ssw0rd!2024 \
  stalwart:local

# Check logs
docker logs -f stalwart

# The entrypoint script will:
# 1. Initialize /opt/stalwart if empty
# 2. Create default config.toml
# 3. Start the server
```

### Port Mapping Explanation

| Port | Protocol | Description |
|------|----------|-------------|
| 25 | SMTP | Mail transfer (MTA) |
| 587 | SMTP | Mail submission (MSA) |
| 465 | SMTP | Mail submission over TLS |
| 143 | IMAP | IMAP email access |
| 993 | IMAP | IMAP over TLS |
| 110 | POP3 | POP3 email access |
| 995 | POP3 | POP3 over TLS |
| 4190 | ManageSieve | Sieve script management |
| 443 | HTTPS | Web admin interface (with TLS) |
| 8080 | HTTP | Web admin interface (no TLS) |

### Advanced Docker Run Options

```bash
docker run -d \
  --name stalwart \
  --hostname mail.example.com \
  --restart unless-stopped \
  \
  # Port mappings
  -p 25:25 \
  -p 587:587 \
  -p 465:465 \
  -p 143:143 \
  -p 993:993 \
  -p 443:443 \
  \
  # Volume mounts
  -v ./stalwart-data:/opt/stalwart \
  -v ./custom-config.toml:/opt/stalwart/etc/config.toml:ro \
  \
  # Environment variables
  -e ADMIN_SECRET=mysecurepassword \
  -e STALWART_PATH=/opt/stalwart \
  -e TZ=America/New_York \
  \
  # Resource limits
  --memory=2g \
  --cpus=2 \
  \
  # Health check
  --health-cmd="curl -f http://localhost:8080/health || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  \
  stalwart:local
```

### Container Management Commands

```bash
# View logs
docker logs -f stalwart

# Execute commands in container
docker exec -it stalwart /bin/bash

# Use stalwart-cli
docker exec -it stalwart stalwart-cli --help

# Stop container
docker stop stalwart

# Start container
docker start stalwart

# Remove container (data persists in volume)
docker rm -f stalwart

# Update configuration without restart (if supported)
docker exec stalwart stalwart-cli config reload
```

---

## Docker Compose Setup

### Basic Docker Compose Configuration

Create a `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  stalwart:
    build:
      context: .
      dockerfile: Dockerfile
    image: stalwart:local
    container_name: stalwart
    hostname: mail.example.com
    restart: unless-stopped
    
    ports:
      - "25:25"      # SMTP
      - "587:587"    # Submission
      - "465:465"    # Submissions (TLS)
      - "143:143"    # IMAP
      - "993:993"    # IMAPS
      - "110:110"    # POP3
      - "995:995"    # POP3S
      - "4190:4190"  # ManageSieve
      - "8080:8080"  # HTTP Admin
      - "443:443"    # HTTPS Admin
    
    volumes:
      - ./stalwart-data:/opt/stalwart
    
    environment:
      - ADMIN_SECRET=${ADMIN_SECRET:?ADMIN_SECRET required - set in .env file}
      - STALWART_PATH=/opt/stalwart
      - TZ=UTC
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    
    networks:
      - stalwart-net
    
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2'
        reservations:
          memory: 512M
          cpus: '0.5'

networks:
  stalwart-net:
    driver: bridge
```

### Advanced Docker Compose with External Databases

Create `docker-compose.full.yml`:

```yaml
version: '3.8'

services:
  # PostgreSQL database
  postgres:
    image: postgres:16-alpine
    container_name: stalwart-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: stalwart
      POSTGRES_USER: stalwart
      POSTGRES_PASSWORD: ${DB_PASSWORD:?Database password required}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - stalwart-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U stalwart"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis for caching
  redis:
    image: redis:7-alpine
    container_name: stalwart-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD:?Redis password required}
    volumes:
      - redis-data:/data
    networks:
      - stalwart-net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # MinIO (S3-compatible storage)
  minio:
    image: minio/minio:latest
    container_name: stalwart-minio
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD:?MinIO password required}
    volumes:
      - minio-data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      - stalwart-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Stalwart with PostgreSQL + Redis + S3
  stalwart:
    build:
      context: .
      dockerfile: Dockerfile
    image: stalwart:local
    container_name: stalwart
    hostname: mail.example.com
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
    
    ports:
      - "25:25"
      - "587:587"
      - "465:465"
      - "143:143"
      - "993:993"
      - "110:110"
      - "995:995"
      - "4190:4190"
      - "8080:8080"
      - "443:443"
    
    volumes:
      - ./stalwart-data:/opt/stalwart
      - ./custom-config.toml:/opt/stalwart/etc/config.toml:ro
    
    environment:
      - ADMIN_SECRET=${ADMIN_SECRET:?Admin password required}
      - STALWART_PATH=/opt/stalwart
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=stalwart
      - DB_USER=stalwart
      - DB_PASSWORD=${DB_PASSWORD:?Database password required}
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=${REDIS_PASSWORD:?Redis password required}
      - S3_ENDPOINT=http://minio:9000
      - S3_ACCESS_KEY=${MINIO_USER:-minioadmin}
      - S3_SECRET_KEY=${MINIO_PASSWORD:?MinIO password required}
      - TZ=UTC
    
    networks:
      - stalwart-net
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

networks:
  stalwart-net:
    driver: bridge

volumes:
  postgres-data:
  redis-data:
  minio-data:
```

### Environment Variables File

Create `.env` file:

```bash
# Admin credentials
ADMIN_SECRET=your-secure-admin-password-here

# Database credentials
DB_PASSWORD=your-secure-db-password-here

# Redis password
REDIS_PASSWORD=your-secure-redis-password-here

# MinIO credentials
MINIO_USER=minioadmin
MINIO_PASSWORD=your-secure-minio-password-here

# Timezone
TZ=UTC
```

### Docker Compose Commands

```bash
# Build and start services
docker-compose up -d

# Build with no cache
docker-compose build --no-cache

# View logs
docker-compose logs -f stalwart

# Stop services
docker-compose stop

# Stop and remove containers
docker-compose down

# Stop and remove containers + volumes
docker-compose down -v

# Rebuild and restart
docker-compose up -d --build

# Scale service (if configured)
docker-compose up -d --scale stalwart=3

# Use specific compose file
docker-compose -f docker-compose.full.yml up -d

# View service status
docker-compose ps

# Execute command in service
docker-compose exec stalwart /bin/bash
```

### Production Docker Compose Tips

1. **Always use secrets for passwords**: Never hardcode passwords in compose files
2. **Use health checks**: Ensure services are ready before dependent services start
3. **Configure resource limits**: Prevent any service from consuming all resources
4. **Use restart policies**: Ensure services auto-recover from failures
5. **Enable logging**: Configure logging drivers for log management
6. **Network isolation**: Use custom networks to isolate services
7. **Volume backups**: Regularly backup named volumes

---

## Configuration Guide

### Custom Configuration for PostgreSQL Backend

Create `custom-config-postgres.toml`:

```toml
[server.listener."smtp"]
bind = ["0.0.0.0:25"]
protocol = "smtp"

[server.listener."submission"]
bind = ["0.0.0.0:587"]
protocol = "smtp"

[server.listener."https"]
bind = ["0.0.0.0:443"]
protocol = "http"
tls.implicit = true

[storage]
data = "postgres"
fts = "postgres"
blob = "s3"
lookup = "redis"
directory = "internal"

[store."postgres"]
type = "postgresql"
host = "%{env:DB_HOST}%"
port = "%{env:DB_PORT}%"
database = "%{env:DB_NAME}%"
user = "%{env:DB_USER}%"
password = "%{env:DB_PASSWORD}%"

[store."s3"]
type = "s3"
endpoint = "%{env:S3_ENDPOINT}%"
bucket = "stalwart-blobs"
region = "us-east-1"
access-key = "%{env:S3_ACCESS_KEY}%"
secret-key = "%{env:S3_SECRET_KEY}%"

[store."redis"]
type = "redis"
urls = ["redis://:%{env:REDIS_PASSWORD}%@%{env:REDIS_HOST}%:%{env:REDIS_PORT}%"]

[directory."internal"]
type = "internal"
store = "postgres"

[authentication.fallback-admin]
user = "admin"
secret = "%{env:ADMIN_SECRET}%"

[tracer."stdout"]
type = "stdout"
level = "info"
enable = true
```

### Environment Variable Substitution

Stalwart supports environment variable substitution in config files:
- `%{env:VARIABLE_NAME}%` - Required variable (fails if not set)
- `%{env:VARIABLE_NAME:default_value}%` - Optional with default

### Configuration Validation

```bash
# Validate configuration locally
./target/release/stalwart --config /path/to/config.toml --validate

# Validate in Docker
docker run --rm -v ./config.toml:/tmp/config.toml stalwart:local \
  /usr/local/bin/stalwart --config /tmp/config.toml --validate
```

---

## Testing

### Run All Tests Locally

```bash
# Full test suite (requires external services)
cargo test --workspace --all-features -- --nocapture

# Tests by component
cargo test -p jmap_proto -- --nocapture
cargo test -p imap_proto -- --nocapture
cargo test -p tests smtp -- --nocapture
cargo test -p tests imap -- --nocapture
cargo test -p tests jmap -- --nocapture
```

### Setup Test Environment

```bash
# Start test dependencies
docker run -d --name test-postgres -p 5432:5432 \
  -e POSTGRES_PASSWORD=test postgres:16-alpine

docker run -d --name test-redis -p 6379:6379 \
  redis:7-alpine

docker run -d --name test-minio -p 9000:9000 \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=minioadmin \
  minio/minio server /data

# Run tests
cargo test --all-features
```

### Code Style Check

```bash
# Check formatting
cargo fmt --all --check

# Format code
cargo fmt --all
```

### Linting

```bash
# Install clippy
rustup component add clippy

# Run clippy
cargo clippy --all-features -- -D warnings
```

---

## Pros and Cons

### Pros ✅

#### Architecture & Performance
1. **Written in Rust**: Memory-safe, no garbage collection, excellent performance
2. **Modern async I/O**: Built on Tokio for high concurrency
3. **Efficient resource usage**: Low memory footprint compared to traditional mail servers
4. **Scalable**: Designed for both small deployments and large clusters

#### Features
5. **Feature-complete**: Supports all major email and collaboration protocols
6. **Built-in security**: Spam filtering, virus scanning, authentication out of the box
7. **Modern standards**: Full JMAP support (modern alternative to IMAP)
8. **Web admin interface**: No need for command-line configuration
9. **Multiple storage backends**: Choose what fits your infrastructure

#### Deployment
10. **Single binary**: No complex dependencies to manage
11. **Docker-ready**: Official images and easy containerization
12. **Easy configuration**: TOML-based with environment variable support
13. **Cloud-native**: Kubernetes, S3, Redis, external DB support

#### Security & Reliability
14. **Security audited**: Professional security audit completed
15. **Active development**: Regular updates and bug fixes
16. **AGPL-3.0 licensed**: Open source with enterprise option
17. **Built-in monitoring**: OpenTelemetry, Prometheus integration

### Cons ❌

#### Maturity
1. **Not yet 1.0**: Still in 0.x versions, database schema may change
2. **Relatively new**: Less battle-tested than Postfix, Dovecot, or Cyrus
3. **Smaller community**: Fewer resources, guides, and troubleshooting help
4. **Limited ecosystem**: Fewer plugins and extensions compared to established servers

#### Migration & Compatibility
5. **Migration complexity**: Moving from existing mail servers requires planning
6. **Breaking changes**: Database migrations needed between some versions
7. **Limited compatibility layers**: May require client configuration changes

#### Documentation & Support
8. **Documentation gaps**: Some advanced features lack detailed documentation
9. **Community support only**: Free version relies on GitHub Discussions/Discord
10. **Enterprise features**: Some features only available in paid version

#### Technical Limitations
11. **Resource usage during build**: Rust compilation is memory-intensive (2GB+ RAM)
12. **Long build times**: Initial compilation takes 15-30 minutes
13. **Database flexibility**: Switching backends requires data migration
14. **Clustering complexity**: Advanced clustering requires external message brokers

#### Operational
15. **Learning curve**: Different from traditional mail server setups
16. **Limited GUI tools**: Fewer third-party admin tools compared to established servers
17. **Backup complexity**: Depends on storage backend chosen
18. **No hot reload**: Some config changes require restart

### When to Choose Stalwart

**Choose Stalwart if:**
- Starting a new mail infrastructure
- Want modern protocols (JMAP, CalDAV, CardDAV)
- Need tight container/Kubernetes integration
- Value single-binary deployment
- Want built-in web admin interface
- Prefer Rust's memory safety and performance
- Need flexible storage backend options

**Consider alternatives if:**
- Migrating large existing mail infrastructure
- Require extensive third-party plugin ecosystem
- Need 100% feature parity with Postfix/Dovecot
- Require immediate enterprise support without license
- Have very specific compliance requirements
- Team lacks Rust expertise for contributions

---

## Troubleshooting

### Build Issues

#### Error: Cannot find libclang

```bash
# Ubuntu/Debian
sudo apt-get install libclang-dev

# macOS
brew install llvm
export LIBCLANG_PATH=/usr/local/opt/llvm/lib
```

#### Error: Out of memory during build

```bash
# Reduce parallel jobs
cargo build --release -j 2

# Or use cargo with low memory mode
export CARGO_BUILD_JOBS=2
cargo build --release
```

#### Error: Linker not found

```bash
# Ubuntu/Debian
sudo apt-get install build-essential

# macOS
xcode-select --install
```

### Runtime Issues

#### Error: Permission denied on ports < 1024

```bash
# Option 1: Use higher ports (8080 instead of 80, 8025 instead of 25)
# Edit config.toml to change port bindings

# Option 2: Give binary permission
sudo setcap 'cap_net_bind_service=+ep' ./target/release/stalwart

# Option 3: Run as root (not recommended)
sudo ./target/release/stalwart --config /path/to/config.toml
```

#### Error: Cannot connect to database

```bash
# Check database is running
docker ps | grep postgres

# Test connection
psql -h localhost -U stalwart -d stalwart

# Check environment variables
echo $DB_PASSWORD

# Verify config file
cat /opt/stalwart/etc/config.toml | grep -A 5 postgres
```

#### Error: Port already in use

```bash
# Find process using port
sudo lsof -i :25
sudo netstat -tulpn | grep :25

# Kill process
sudo kill -9 <PID>

# Or use different port in config
```

### Docker Issues

#### Error: Cannot build multi-arch images

```bash
# Setup QEMU
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Create new builder
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap
```

#### Error: Build cache issues

```bash
# Clear Docker build cache
docker builder prune -a

# Build without cache
docker build --no-cache -t stalwart:local .
```

#### Container exits immediately

```bash
# Check logs
docker logs stalwart

# Run interactively to debug
docker run -it --rm stalwart:local /bin/bash

# Check entrypoint script
docker run --rm stalwart:local cat /usr/local/bin/entrypoint.sh
```

### Performance Issues

#### High memory usage

```toml
# Adjust in config.toml
[server]
max-connections = 1000  # Reduce if needed

[storage]
cache.size = "500MB"    # Reduce cache size
```

#### Slow startup

```bash
# Check database initialization
docker logs stalwart | grep -i migration

# Monitor startup process
docker logs -f stalwart
```

### Getting Help

1. **GitHub Discussions**: https://github.com/stalwartlabs/stalwart/discussions
2. **Discord**: https://discord.com/servers/stalwart-923615863037390889
3. **Reddit**: https://www.reddit.com/r/stalwartlabs/
4. **Documentation**: https://stalw.art/docs
5. **GitHub Issues**: https://github.com/stalwartlabs/stalwart/issues (for bugs)

---

## Quick Reference Commands

### Build Commands
```bash
# Local build (release)
cargo build --release -p stalwart

# Docker build (standard)
docker build -t stalwart:local -f Dockerfile .

# Docker build (advanced)
docker buildx build --file Dockerfile.build --target gnu --tag stalwart:local --load .
```

### Run Commands
```bash
# Local run
./target/release/stalwart --config /path/to/config.toml

# Docker run
docker run -d --name stalwart -p 25:25 -p 587:587 -p 143:143 -p 8080:8080 \
  -v ./data:/opt/stalwart stalwart:local

# Docker Compose
docker-compose up -d
```

### Management Commands
```bash
# Check version
./target/release/stalwart --version

# Initialize data
./target/release/stalwart --init /path/to/data

# Validate config
./target/release/stalwart --config /path/to/config.toml --validate

# Run tests
cargo test --workspace

# Format code
cargo fmt --all

# Check code
cargo clippy --all-features
```

---

## Conclusion

Stalwart is a modern, performant mail and collaboration server that's perfect for:
- New deployments
- Container-based infrastructure
- Organizations wanting modern protocols
- Teams comfortable with cutting-edge technology

The build process is straightforward once dependencies are installed, and the Docker deployment is well-designed for production use. While it's not yet version 1.0, it's feature-complete and actively maintained.

For production deployments, carefully consider the pros and cons listed above, test thoroughly in a staging environment, and have a solid backup strategy in place.

**Next Steps:**
1. Try the local build with default features
2. Test with your specific use case
3. Experiment with different storage backends
4. Join the community for support
5. Consider sponsoring the project if it meets your needs

---

*Last updated: 2026-02-09*
*Stalwart version tested: 0.15.4*
*Repository: https://github.com/stalwartlabs/stalwart*
