# Quick Start Guide for Stalwart

This is a condensed quick-start guide. For the complete documentation, see [SETUP.md](./SETUP.md).

## 🚀 Quick Start Options

### Option 1: Run with Docker Compose (Recommended)

```bash
# 1. Clone the repository
git clone https://github.com/stalwartlabs/stalwart.git
cd stalwart

# 2. Create environment file
cp .env.template .env
# Edit .env and set ADMIN_SECRET to a secure password

# 3. Build and start
docker compose up -d

# 4. Access the admin interface
# Open http://localhost:8080 in your browser
# Login: admin / (your ADMIN_SECRET)
```

### Option 2: Build Locally

```bash
# 1. Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 2. Clone and build
git clone https://github.com/stalwartlabs/stalwart.git
cd stalwart
cargo build --release -p stalwart

# 3. Initialize and run
mkdir -p /tmp/stalwart-data
./target/release/stalwart --init /tmp/stalwart-data
ADMIN_SECRET='MyS3cur3P@ssw0rd!2024' ./target/release/stalwart --config /tmp/stalwart-data/etc/config.toml

# 4. Access at http://localhost:8080
```

### Option 3: Build Docker Image from Source

```bash
# Build the image
docker build -t stalwart:local -f Dockerfile .

# Run it
docker run -d --name stalwart \
  -p 25:25 -p 587:587 -p 143:143 -p 8080:8080 \
  -v ./stalwart-data:/opt/stalwart \
  -e ADMIN_SECRET='MyS3cur3P@ssw0rd!2024' \
  stalwart:local

# Access at http://localhost:8080
```

## 📚 What's Included

- **SETUP.md** - Comprehensive setup guide covering:
  - Local development setup
  - Docker container deployment
  - Building Docker images from source
  - Docker Compose configurations
  - Configuration examples
  - Testing procedures
  - Pros and cons analysis
  - Troubleshooting guide

- **docker-compose.yml** - Basic setup with RocksDB (single container)

- **docker-compose.advanced.yml** - Full stack with PostgreSQL, Redis, and MinIO

- **config-advanced.toml** - Example configuration for advanced setup

- **.env.template** - Template for environment variables

## 🔑 Default Ports

| Port | Service |
|------|---------|
| 8080 | Web Admin (HTTP) |
| 443  | Web Admin (HTTPS) |
| 25   | SMTP |
| 587  | Mail Submission |
| 143  | IMAP |
| 993  | IMAPS |

## 🛠️ Key Features

- Complete mail server (SMTP, IMAP, POP3)
- Modern JMAP protocol support
- Collaboration features (CalDAV, CardDAV, WebDAV)
- Built-in spam filtering
- Web-based admin interface
- Multiple storage backend options
- Written in Rust for security and performance

## 📖 Next Steps

1. Read the complete [SETUP.md](./SETUP.md) guide
2. Join the community on [Discord](https://discord.com/servers/stalwart-923615863037390889)
3. Check the [official documentation](https://stalw.art/docs)
4. Report issues on [GitHub](https://github.com/stalwartlabs/stalwart/issues)

## ⚠️ Security Note

**Always change default passwords!** Never use default credentials in production.

Generate secure passwords:
```bash
openssl rand -base64 32
```

## 📝 License

Dual-licensed under AGPL-3.0 or Stalwart Enterprise License (SELv1).
