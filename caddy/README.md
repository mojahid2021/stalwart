# Caddy Configuration for Stalwart Admin Panel

This directory contains the Caddy reverse proxy configuration for serving the Stalwart admin panel on a separate domain with automatic HTTPS.

## Overview

Caddy acts as a reverse proxy that:
- Serves admin panel on `admin.yourdomain.com`
- Automatically obtains and renews Let's Encrypt TLS certificates
- Adds security headers
- Proxies requests to Stalwart's admin interface (localhost:8080)

## Files

- `Caddyfile` - Main Caddy configuration file

## Configuration

The Caddyfile uses environment variables for configuration:

- `ADMIN_DOMAIN` - Admin panel domain (e.g., admin.yourdomain.com)
- `ACME_EMAIL` - Email for Let's Encrypt notifications (e.g., admin@yourdomain.com)

These are set in the `.env` file used by Docker Compose.

## Usage

### With Docker Compose

The Caddy service is automatically started when using:

```bash
docker compose -f docker-compose.advanced-separate-domains.yml up -d
```

### Testing Configuration

Validate the Caddyfile syntax:

```bash
docker exec stalwart-caddy caddy validate --config /etc/caddy/Caddyfile
```

### Reloading Configuration

After modifying the Caddyfile, reload without downtime:

```bash
docker exec stalwart-caddy caddy reload --config /etc/caddy/Caddyfile
```

### Viewing Logs

Check Caddy logs:

```bash
docker logs stalwart-caddy
docker logs -f stalwart-caddy  # Follow logs
```

## Security Features

The Caddyfile includes:

- **Automatic HTTPS**: Let's Encrypt certificate management
- **HSTS**: HTTP Strict Transport Security with preload support
- **Security Headers**: X-Content-Type-Options, X-Frame-Options, CSP, etc.
- **Error Handling**: Custom error responses
- **Access Logging**: JSON-formatted logs for monitoring

## Customization

### Adding Rate Limiting

Add to the site block in Caddyfile:

```caddy
{$ADMIN_DOMAIN} {
    # Rate limiting (requires Caddy rate_limit plugin)
    rate_limit {
        zone admin_zone {
            key {remote_host}
            events 10
            window 1m
        }
    }
    
    # ... rest of configuration
}
```

### IP Whitelisting

Restrict access to specific IPs:

```caddy
{$ADMIN_DOMAIN} {
    # Allow only specific IPs
    @allowed {
        remote_ip 203.0.113.0/24 198.51.100.0/24
    }
    
    handle @allowed {
        reverse_proxy stalwart:8080
    }
    
    handle {
        respond "Access Denied" 403
    }
}
```

### Basic Authentication

Add basic auth layer:

```caddy
{$ADMIN_DOMAIN} {
    # Basic authentication
    basicauth {
        admin $2a$14$HASHED_PASSWORD
    }
    
    reverse_proxy stalwart:8080
}
```

Generate password hash:

```bash
docker exec stalwart-caddy caddy hash-password
```

## Troubleshooting

### Certificate Issues

Check certificate status:

```bash
docker exec stalwart-caddy caddy list-certificates
```

View ACME logs:

```bash
docker logs stalwart-caddy 2>&1 | grep -i acme
```

### DNS Not Resolving

Verify DNS:

```bash
dig admin.yourdomain.com
nslookup admin.yourdomain.com
```

### Port Conflicts

Ensure ports 80 and 443 are not in use:

```bash
sudo netstat -tulpn | grep -E ':(80|443)'
sudo ss -tulpn | grep -E ':(80|443)'
```

### Backend Connection Issues

Test connection to Stalwart:

```bash
docker exec stalwart-caddy wget -O- http://stalwart:8080/health
```

## Alternative: Nginx

If you prefer Nginx over Caddy, see `SEPARATE_DOMAINS_SETUP.md` for Nginx configuration examples.

## Resources

- [Caddy Documentation](https://caddyserver.com/docs/)
- [Caddy Security Headers](https://caddyserver.com/docs/caddyfile/directives/header)
- [Let's Encrypt](https://letsencrypt.org/)
- [Stalwart Documentation](https://stalw.art/docs)
