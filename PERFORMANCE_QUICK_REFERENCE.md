# Stalwart Performance Quick Reference

Quick reference guide for performance tuning and configuration decisions.

For comprehensive details, see [PERFORMANCE_AND_SAAS_ANALYSIS.md](./PERFORMANCE_AND_SAAS_ANALYSIS.md)

---

## Quick Decision Matrix

### Database Selection

| Users | Data Store | FTS | Blob | Cache |
|-------|------------|-----|------|-------|
| < 1K | RocksDB | RocksDB | RocksDB | RocksDB |
| 1K-10K | RocksDB | RocksDB | RocksDB | RocksDB |
| 10K-100K | PostgreSQL | PostgreSQL | S3 | Redis |
| > 100K | PostgreSQL (replicas) | Meilisearch | S3 | Redis Cluster |

### Hardware Requirements

| Users | CPU | RAM | Storage | Cost/Month |
|-------|-----|-----|---------|------------|
| < 1K | 4 cores | 8 GB | 100 GB SSD | $40 |
| 1K-10K | 8 cores | 32 GB | 1 TB NVMe | $200 |
| 10K-100K | 24 cores | 96 GB | 5 TB + S3 | $1,950 |
| > 100K | 160 cores | 320 GB | 10 TB + S3 | $14,200 |

---

## Performance Benchmarks

### RocksDB (Single Server)
- **Latency**: < 10ms (cached), 1-5ms (disk)
- **Throughput**: 1M+ ops/sec
- **Concurrency**: 10K+ connections
- **Users**: 10,000+ on good hardware

### PostgreSQL (Multi-Server)
- **Latency**: 5-20ms (typical)
- **Throughput**: 100K+ ops/sec
- **Concurrency**: 100K+ connections
- **Users**: Millions (with horizontal scaling)

---

## Fastest Configuration (< 10K users)

```toml
[storage]
data = "rocksdb"
fts = "rocksdb"
blob = "rocksdb"
lookup = "rocksdb"

[store."rocksdb"]
type = "rocksdb"
path = "/opt/stalwart/data"
compression = "lz4"
cache.size = "8GB"
optimize.reads = true
max-background-jobs = 8
```

**Hardware**: NVMe SSD, 32GB RAM, 8 CPU cores
**Performance**: 10K+ emails/minute, < 10ms latency

---

## Production SaaS Configuration (> 10K users)

```toml
[storage]
data = "postgres"
fts = "meilisearch"
blob = "s3"
lookup = "redis"

[store."postgres"]
type = "postgresql"
pool.max-connections = 100
read-replicas = ["replica1", "replica2"]

[store."redis"]
type = "redis"
urls = ["redis://redis-cluster:6379"]
cluster = true

[smtp.queue]
workers = 100
batch.enable = true
batch.size = 100
```

**Infrastructure**: 3+ Stalwart instances, PostgreSQL cluster, Redis cluster, S3
**Performance**: 50K+ emails/minute, < 50ms latency

---

## Key Limits

| Parameter | Default | Recommended |
|-----------|---------|-------------|
| Max connections/listener | 8192 | 1024-8192 |
| JMAP concurrent requests | 4 | 4-16 |
| IMAP rate limit | 2000/min | 1000-5000/min |
| SMTP queue workers | Async | 20-100 |
| Email size | 75 MB | 50-100 MB |
| Attachment size | 50 MB | 25-75 MB |

---

## Rate Limiting

```toml
[rate-limit."api"]
account = "1000/1m"    # Authenticated users
anonymous = "100/1m"   # Anonymous users

[rate-limit."smtp"]
inbound = "50/30s"     # Per sender IP
outbound = "500/1m"    # Per domain
```

---

## PostgreSQL Tuning (32GB RAM)

```ini
shared_buffers = 8GB                # 25% of RAM
effective_cache_size = 24GB         # 75% of RAM
work_mem = 64MB
maintenance_work_mem = 2GB
max_connections = 200
random_page_cost = 1.1              # For SSD
effective_io_concurrency = 200
```

---

## Scaling Thresholds

**Scale Vertically When:**
- CPU > 70% sustained
- Memory > 80% sustained
- Disk I/O wait > 10%

**Scale Horizontally When:**
- Users > 10,000 on single instance
- Peak emails/hour > 50,000
- Geographic distribution needed
- High availability required

---

## Stalwart vs Commercial Services

| Service | Cost (1M emails/mo) | Self-Hosted | Full Control |
|---------|---------------------|-------------|--------------|
| Stalwart | $1,650 | ✅ | ✅ |
| SendGrid | $990 | ❌ | ❌ |
| Mailgun | $890 | ❌ | ❌ |
| Mailchimp | $3,000 | ❌ | ❌ |

**Break-even**: Stalwart becomes cost-effective at ~500K emails/month

---

## Monitoring Checklist

- [ ] CPU usage (target: < 70%)
- [ ] Memory usage (target: < 80%)
- [ ] Disk I/O (IOPS, throughput)
- [ ] Queue depth (target: < 1000)
- [ ] Email delivery rate (target: > 95%)
- [ ] Response times (p50, p95, p99)
- [ ] Connection pool usage
- [ ] Cache hit rate

---

## Quick Commands

### Check system status
```bash
# Docker logs
docker logs stalwart --tail 100 --follow

# Check health
curl http://localhost:8080/health

# Monitor resource usage
docker stats stalwart
```

### Database operations
```bash
# PostgreSQL connection count
psql -c "SELECT count(*) FROM pg_stat_activity;"

# Redis cache stats
redis-cli INFO stats

# RocksDB stats (via Stalwart admin)
curl http://localhost:8080/metrics
```

### Performance testing
```bash
# SMTP throughput test
for i in {1..1000}; do echo "Test email $i" | mail -s "Test $i" user@example.com; done

# IMAP connection test
imaptest host=localhost port=143 user=test pass=test clients=100

# HTTP load test
ab -n 10000 -c 100 http://localhost:8080/health
```

---

For detailed configuration examples, tuning parameters, and SaaS deployment, see [PERFORMANCE_AND_SAAS_ANALYSIS.md](./PERFORMANCE_AND_SAAS_ANALYSIS.md)
