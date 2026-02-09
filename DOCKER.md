# Running Stalwart with Docker Compose

This guide explains how to run Stalwart Mail Server using Docker Compose.

## Prerequisites

- Docker Engine 20.10 or later
- Docker Compose V2 or later
- At least 2GB of RAM
- At least 10GB of disk space

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/stalwartlabs/stalwart.git
cd stalwart
```

### 2. Configure Environment Variables

**IMPORTANT**: You must configure the admin password before starting the service.

Copy the example environment file and customize it:

```bash
cp .env.example .env
```

Edit `.env` and set a strong `ADMIN_SECRET`:

```bash
# Set a strong admin password (required!)
# Use at least 12 characters with uppercase, lowercase, numbers, and symbols
ADMIN_SECRET=your_very_secure_password_here
```

**Note**: The service will not start without a valid `ADMIN_SECRET` in your `.env` file.

### 3. Start Stalwart

```bash
docker compose up -d
```

This will:
- Pull the latest Stalwart image from Docker Hub
- Create persistent volumes for data storage
- Start the mail server
- Expose all necessary ports

### 4. Access the Admin Interface

Once started, access the web admin interface at:
- HTTPS: `https://localhost` (or `https://your-server-ip`)
- HTTP: `http://localhost:8080` (for development)

Default credentials:
- Username: `admin`
- Password: (the value you set for `ADMIN_SECRET`)

## Port Mappings

| Port | Protocol | Description |
|------|----------|-------------|
| 25 | SMTP | Mail submission (MTA to MTA) |
| 587 | SMTP | Mail submission (STARTTLS) |
| 465 | SMTP | Mail submission (TLS) |
| 143 | IMAP | IMAP (STARTTLS) |
| 993 | IMAP | IMAP (TLS) |
| 110 | POP3 | POP3 (STARTTLS) |
| 995 | POP3 | POP3 (TLS) |
| 4190 | ManageSieve | Sieve script management |
| 443 | HTTPS | Web admin, JMAP, CalDAV, CardDAV |
| 8080 | HTTP | HTTP (optional) |

## Configuration

### Using the Default Configuration

By default, Stalwart will initialize with a basic configuration on first run. The configuration is stored in the persistent volume at `/opt/stalwart/etc/config.toml`.

### Using a Custom Configuration

To use a custom configuration file:

1. Create a `config` directory:
   ```bash
   mkdir -p config
   ```

2. Copy your configuration file:
   ```bash
   cp your-config.toml config/config.toml
   ```

3. Uncomment the volume mount in `docker-compose.yml`:
   ```yaml
   volumes:
     - ./config/config.toml:/opt/stalwart/etc/config.toml:ro
   ```

4. Restart the service:
   ```bash
   docker compose restart stalwart
   ```

## Development Setup

For development with additional services (PostgreSQL, Redis), use the development compose file:

```bash
docker compose -f docker-compose.dev.yml up -d
```

This includes:
- Stalwart Mail Server (built from source)
- PostgreSQL database
- Redis cache
- Adminer (database management UI at http://localhost:8081)

## Data Persistence

All data is stored in Docker volumes:

- `stalwart-data`: Contains all Stalwart data, configuration, and mail storage

To backup your data:

```bash
docker compose down
docker run --rm -v stalwart-data:/data -v $(pwd):/backup alpine tar czf /backup/stalwart-backup.tar.gz -C /data .
```

To restore from backup:

```bash
docker compose down
docker volume rm stalwart-data
docker volume create stalwart-data
docker run --rm -v stalwart-data:/data -v $(pwd):/backup alpine tar xzf /backup/stalwart-backup.tar.gz -C /data
docker compose up -d
```

## Managing the Service

### View logs

```bash
docker compose logs -f stalwart
```

### Stop the service

```bash
docker compose down
```

### Stop and remove all data

```bash
docker compose down -v
```

### Restart the service

```bash
docker compose restart stalwart
```

### Update to the latest version

```bash
docker compose pull
docker compose up -d
```

## TLS/SSL Certificates

Stalwart can automatically obtain Let's Encrypt certificates. To enable this:

1. Ensure ports 80 and 443 are accessible from the internet
2. Configure your domain to point to your server
3. Stalwart will automatically request and renew certificates

Alternatively, you can provide your own certificates:

1. Create a `certs` directory:
   ```bash
   mkdir -p certs
   ```

2. Place your certificate files in the directory:
   - `cert.pem`: Your certificate
   - `key.pem`: Your private key

3. Uncomment the certificate volume mount in `docker-compose.yml`:
   ```yaml
   volumes:
     - ./certs:/opt/stalwart/etc/certs:ro
   ```

4. Update your configuration to use the certificates

## Troubleshooting

### Check if the service is running

```bash
docker compose ps
```

### View service logs

```bash
docker compose logs stalwart
```

### Check health status

```bash
docker inspect stalwart-mail --format='{{.State.Health.Status}}'
```

### Test SMTP connectivity

```bash
telnet localhost 25
```

### Test IMAP connectivity

```bash
openssl s_client -connect localhost:993
```

### Access the container shell

```bash
docker compose exec stalwart sh
```

## Security Recommendations

1. **Change the default admin password** immediately after first login
2. **Use strong passwords** for all accounts
3. **Enable TLS/SSL** for all protocols
4. **Configure firewall rules** to restrict access
5. **Keep Docker and Stalwart updated** regularly
6. **Use environment variables** instead of hardcoding secrets
7. **Regular backups** of your data
8. **Monitor logs** for suspicious activity

## Advanced Configuration

### Resource Limits

To set resource limits, uncomment and adjust the `deploy` section in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
    reservations:
      cpus: '0.5'
      memory: 512M
```

### Multiple Domains

Stalwart supports multiple domains. Configure them through the web admin interface or configuration file.

### Using External Databases

To use PostgreSQL or MySQL instead of the default RocksDB:

1. Update the storage configuration in your config file
2. Provide database connection details
3. Use the development compose file as a reference

## Additional Resources

- [Official Documentation](https://stalw.art/docs)
- [Installation Guide](https://stalw.art/docs/install/platform/docker)
- [Configuration Guide](https://stalw.art/docs/configuration)
- [GitHub Repository](https://github.com/stalwartlabs/stalwart)
- [Community Discord](https://discord.com/servers/stalwart-923615863037390889)
- [Reddit Community](https://www.reddit.com/r/stalwartlabs/)

## Support

If you need help:

1. Check the [documentation](https://stalw.art/docs)
2. Search [GitHub Discussions](https://github.com/stalwartlabs/stalwart/discussions)
3. Ask on [Discord](https://discord.com/servers/stalwart-923615863037390889)
4. Post on [Reddit](https://www.reddit.com/r/stalwartlabs/)

For commercial support, consider purchasing an [Enterprise License](https://stalw.art/enterprise).
