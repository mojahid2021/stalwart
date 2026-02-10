# Stalwart Scaling Guide

Comprehensive guide for scaling Stalwart Mail Server both vertically and horizontally to handle growing workloads.

## Table of Contents

1. [Understanding Stalwart Architecture](#understanding-stalwart-architecture)
2. [Vertical Scaling](#vertical-scaling)
3. [Horizontal Scaling](#horizontal-scaling)
4. [Storage Scaling Strategies](#storage-scaling-strategies)
5. [Load Balancing](#load-balancing)
6. [Monitoring and Capacity Planning](#monitoring-and-capacity-planning)
7. [Kubernetes Deployment](#kubernetes-deployment)
8. [Performance Optimization](#performance-optimization)

---

## Understanding Stalwart Architecture

Stalwart is designed for scalability from day one with support for:

**Built-in Scaling Features:**
- **Stateless design**: Multiple Stalwart instances can run simultaneously
- **Cluster coordination**: Peer-to-peer or via Kafka, Redpanda, NATS, Redis
- **Storage separation**: Data, blob, FTS, and lookup can use different backends
- **Read replicas**: Support for database read replicas
- **Sharded blob storage**: Distribute large files across multiple storage backends
- **Container orchestration**: Native support for Kubernetes, Docker Swarm, Apache Mesos

**Scaling Limits:**
- **Single instance**: 10,000+ users with RocksDB on good hardware
- **Horizontal cluster**: Supports thousands of nodes
- **User capacity**: Millions of users with proper horizontal scaling

---

## Vertical Scaling

Vertical scaling involves increasing resources (CPU, RAM, disk) on a single server.

### When to Scale Vertically

✅ **Use vertical scaling when:**
- User count < 10,000
- Single datacenter deployment
- Simpler operations preferred
- Cost-effective for small-medium deployments

### Docker Resource Configuration

**Dynamic Resource Allocation (Default):**

By default, all Docker Compose configurations use dynamic resource allocation:
- **No hard limits**: Containers can use as much CPU/memory as needed
- **Soft limits (reservations)**: Minimum guaranteed resources
- **Intelligent scaling**: Docker allocates more when workload increases, less when idle

**Configuration approach:**
```yaml
deploy:
  resources:
    # No limits section = dynamic allocation
    reservations:
      memory: 1G    # Minimum guaranteed
      cpus: '1'     # Minimum guaranteed
```

**Benefits:**
- ✅ Automatically scales with workload
- ✅ Uses less resources during quiet periods
- ✅ Can handle traffic spikes without manual intervention
- ✅ No need to predict exact resource needs
- ✅ Better resource utilization across all containers

**When to use hard limits:**

Add hard limits only if you need to:
- Prevent a single container from consuming all host resources
- Enforce resource quotas for billing/accounting
- Test behavior under resource constraints

**Example with hard limits (optional):**
```yaml
deploy:
  resources:
    limits:
      memory: 4G    # Maximum allowed
      cpus: '4'     # Maximum allowed
    reservations:
      memory: 1G    # Minimum guaranteed
      cpus: '1'     # Minimum guaranteed
```

### Hardware Recommendations

#### Small Deployment (< 1,000 users)
```
CPU: 2-4 cores
RAM: 4-8 GB
Disk: 100 GB SSD
Storage: RocksDB
```

#### Medium Deployment (1,000-5,000 users)
```
CPU: 4-8 cores
RAM: 8-16 GB
Disk: 500 GB NVMe SSD
Storage: RocksDB or PostgreSQL
```

#### Large Single-Server (5,000-10,000 users)
```
CPU: 8-16 cores
RAM: 16-32 GB
Disk: 1-2 TB NVMe SSD
Storage: PostgreSQL + S3 for blobs
```

**Original section replaced - see "Docker Resource Configuration" section above (after line 75)**

### RocksDB Tuning for Vertical Scaling

**Configuration (`config.toml`):**
```toml
[store."rocksdb"]
type = "rocksdb"
path = "/opt/stalwart/data"
compression = "lz4"  # or "zstd" for better compression

# Scale cache with available RAM
# Rule of thumb: 25-30% of total RAM
cache.size = "8GB"   # For 32GB RAM server

# Optimize for your workload
optimize.writes = true   # For write-heavy workloads
optimize.reads = true    # For read-heavy workloads

# Performance tuning
max-background-jobs = 8  # Match CPU cores
```

### PostgreSQL Tuning for Vertical Scaling

**PostgreSQL configuration:**
```ini
# Match server resources
shared_buffers = 8GB              # 25% of RAM
effective_cache_size = 24GB       # 75% of RAM
maintenance_work_mem = 2GB
work_mem = 64MB
max_worker_processes = 8
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
```

---

## Horizontal Scaling

Horizontal scaling involves adding more servers to distribute the load.

### When to Scale Horizontally

✅ **Use horizontal scaling when:**
- User count > 10,000
- High availability required
- Multi-region deployment
- Need to scale beyond single-server limits

### Architecture Patterns

#### 1. Active-Active Cluster (Recommended)

Multiple Stalwart instances serving traffic simultaneously.

```
                     ┌─────────────┐
                     │ Load Balancer│
                     │  (HAProxy)   │
                     └──────┬───────┘
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
    ┌─────▼─────┐     ┌─────▼─────┐    ┌─────▼─────┐
    │ Stalwart 1│     │ Stalwart 2│    │ Stalwart 3│
    └─────┬─────┘     └─────┬─────┘    └─────┬─────┘
          │                 │                 │
          └─────────────────┼─────────────────┘
                            │
                  ┌─────────▼──────────┐
                  │   PostgreSQL       │
                  │   (with replica)   │
                  └────────────────────┘
                            │
                  ┌─────────▼──────────┐
                  │   S3 Storage       │
                  │   (MinIO cluster)  │
                  └────────────────────┘
```

**Benefits:**
- ✅ High availability
- ✅ Load distribution
- ✅ No single point of failure
- ✅ Easy to add/remove nodes

#### 2. Separation by Protocol

Different instances handle different protocols.

```
SMTP Cluster → Stalwart SMTP (3 nodes)
IMAP Cluster → Stalwart IMAP (3 nodes)
HTTP Admin   → Stalwart HTTP (2 nodes)
```

**Benefits:**
- ✅ Protocol isolation
- ✅ Independent scaling per protocol
- ✅ Better resource utilization

#### 3. Geographic Distribution

Instances in multiple regions for global reach.

```
US East  → Stalwart Cluster (3 nodes) → PostgreSQL Replica
Europe   → Stalwart Cluster (3 nodes) → PostgreSQL Replica
Asia     → Stalwart Cluster (3 nodes) → PostgreSQL Replica
                    ↓
         PostgreSQL Primary (US East)
                    ↓
              S3 (Multi-region)
```

### Cluster Coordination Methods

#### Option 1: Kafka/Redpanda (Recommended for Large Scale)

**Configuration:**
```toml
[cluster]
type = "kafka"
bootstrap-servers = ["kafka1:9092", "kafka2:9092", "kafka3:9092"]
topic = "stalwart-cluster"
group-id = "stalwart"
```

**Use when:**
- 10,000+ users
- Need strong consistency
- Complex event streaming

#### Option 2: NATS (Lightweight, Fast)

**Configuration:**
```toml
[cluster]
type = "nats"
urls = ["nats://nats1:4222", "nats://nats2:4222"]
```

**Use when:**
- Medium scale (1,000-10,000 users)
- Low latency critical
- Simple deployment

#### Option 3: Redis (Simple, Built-in HA)

**Configuration:**
```toml
[cluster]
type = "redis"
urls = ["redis://sentinel1:26379", "redis://sentinel2:26379"]
```

**Use when:**
- Small-medium scale
- Already using Redis
- Simple setup preferred

### Storage Configuration for Horizontal Scaling

**Required:**
- ✅ **Shared database**: PostgreSQL or MySQL (RocksDB won't work)
- ✅ **Shared blob storage**: S3, MinIO, or Azure
- ✅ **Shared cache**: Redis with Sentinel or Cluster mode

**Example configuration:**
```toml
[storage]
data = "postgres"        # Shared database
fts = "postgres"         # Full-text search
blob = "s3"              # Shared blob storage
lookup = "redis"         # Shared cache
directory = "internal"   # User directory

[store."postgres"]
type = "postgresql"
host = "postgres-primary.internal"
port = 5432
database = "stalwart"
user = "stalwart"
password = "%{env:DB_PASSWORD}%"
pool.max-connections = 50  # Increase for multiple instances

# Read replicas for load distribution
read-replicas = [
    "postgres-replica1.internal:5432",
    "postgres-replica2.internal:5432"
]

[store."s3"]
type = "s3"
endpoint = "https://s3.amazonaws.com"
bucket = "stalwart-blobs"
region = "us-east-1"

[store."redis"]
type = "redis"
# Redis Sentinel for HA
urls = [
    "redis://sentinel1:26379",
    "redis://sentinel2:26379",
    "redis://sentinel3:26379"
]
sentinel.master = "stalwart-master"
```

### Docker Compose for Horizontal Scaling

**`docker-compose-cluster.yml`:**
```yaml
services:
  stalwart:
    image: stalwart:production
    deploy:
      replicas: 3  # Run 3 instances
      resources:
        limits:
          memory: ${STALWART_MEMORY_LIMIT:-4G}
          cpus: ${STALWART_CPU_LIMIT:-4}
    environment:
      - CLUSTER_NODE_ID=${HOSTNAME}
      - CLUSTER_ENABLED=true
    networks:
      - stalwart-cluster
    volumes:
      - /opt/stalwart/config:/opt/stalwart/etc:ro

networks:
  stalwart-cluster:
    driver: overlay  # For Docker Swarm
```

**Deploy with Docker Swarm:**
```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose-cluster.yml stalwart

# Scale up/down
docker service scale stalwart_stalwart=5
```

---

## Storage Scaling Strategies

### Database Scaling

#### PostgreSQL Replication

**Primary-Replica Setup:**
```toml
[store."postgres"]
type = "postgresql"
host = "postgres-primary"
database = "stalwart"

# Read replicas for SELECT queries
read-replicas = [
    "postgres-replica1:5432",
    "postgres-replica2:5432"
]

# Connection pooling per instance
pool.max-connections = 100
```

**Benefits:**
- ✅ Read load distribution
- ✅ High availability
- ✅ Faster query performance

#### PostgreSQL Sharding

For > 100,000 users, consider sharding:

```toml
[store."postgres-shard1"]
type = "postgresql"
host = "postgres-shard1"
database = "stalwart_shard1"
# Users A-M

[store."postgres-shard2"]
type = "postgresql"
host = "postgres-shard2"
database = "stalwart_shard2"
# Users N-Z
```

### Blob Storage Scaling

#### S3/MinIO Cluster

**MinIO Distributed Mode (4+ nodes):**
```bash
# Start MinIO cluster (4 nodes minimum)
docker run -d \
  --name minio1 \
  minio/minio server \
  http://minio{1...4}/data{1...4}

# Automatic sharding and replication
```

**Benefits:**
- ✅ Unlimited capacity
- ✅ Geographic distribution
- ✅ Built-in redundancy

#### Tiered Storage

**Configuration:**
```toml
[store."s3-hot"]
type = "s3"
bucket = "stalwart-hot"
# Recent emails (< 30 days)

[store."s3-cold"]
type = "s3"
bucket = "stalwart-cold"
storage-class = "GLACIER"
# Archive (> 30 days)
```

### Cache Scaling

#### Redis Cluster

**Redis Cluster Setup (3 masters, 3 replicas):**
```toml
[store."redis"]
type = "redis"
urls = [
    "redis://redis-cluster1:6379",
    "redis://redis-cluster2:6379",
    "redis://redis-cluster3:6379"
]
cluster = true
```

**Benefits:**
- ✅ Distributed cache
- ✅ Automatic sharding
- ✅ High availability

---

## Load Balancing

### SMTP/IMAP Load Balancing

#### HAProxy Configuration

**`/etc/haproxy/haproxy.cfg`:**
```haproxy
global
    maxconn 50000
    log stdout format raw local0

defaults
    mode tcp
    timeout connect 5s
    timeout client 30s
    timeout server 30s
    log global

# SMTP Load Balancer
frontend smtp_front
    bind *:25
    default_backend smtp_back

backend smtp_back
    balance roundrobin
    server stalwart1 10.0.0.11:25 check
    server stalwart2 10.0.0.12:25 check
    server stalwart3 10.0.0.13:25 check

# IMAP Load Balancer
frontend imap_front
    bind *:143
    default_backend imap_back

backend imap_back
    balance leastconn  # Better for persistent connections
    server stalwart1 10.0.0.11:143 check
    server stalwart2 10.0.0.12:143 check
    server stalwart3 10.0.0.13:143 check

# HTTPS Admin Load Balancer
frontend https_front
    bind *:443 ssl crt /etc/ssl/certs/stalwart.pem
    default_backend https_back

backend https_back
    balance roundrobin
    cookie SERVERID insert indirect nocache
    server stalwart1 10.0.0.11:8080 check cookie s1
    server stalwart2 10.0.0.12:8080 check cookie s2
    server stalwart3 10.0.0.13:8080 check cookie s3
```

#### Nginx Load Balancer (Alternative)

**`/etc/nginx/nginx.conf`:**
```nginx
stream {
    upstream smtp_cluster {
        least_conn;
        server stalwart1:25 max_fails=3 fail_timeout=30s;
        server stalwart2:25 max_fails=3 fail_timeout=30s;
        server stalwart3:25 max_fails=3 fail_timeout=30s;
    }

    server {
        listen 25;
        proxy_pass smtp_cluster;
        proxy_connect_timeout 1s;
    }
}

http {
    upstream https_cluster {
        least_conn;
        server stalwart1:8080;
        server stalwart2:8080;
        server stalwart3:8080;
    }

    server {
        listen 443 ssl;
        server_name mail.yourdomain.com;
        
        location / {
            proxy_pass http://https_cluster;
        }
    }
}
```

---

## Monitoring and Capacity Planning

### Key Metrics to Monitor

**Per Instance:**
- CPU usage (target: < 70%)
- Memory usage (target: < 80%)
- Disk I/O (IOPS, throughput)
- Network traffic
- Connection count

**Cluster-wide:**
- Total throughput (emails/minute)
- Queue depth
- Database connection pool usage
- Cache hit rate
- Response times (p50, p95, p99)

### Monitoring Setup

#### Prometheus + Grafana

**Stalwart Prometheus Exporter:**
```toml
[metrics]
enable = true
bind = "0.0.0.0:9090"
type = "prometheus"
```

**Prometheus configuration:**
```yaml
scrape_configs:
  - job_name: 'stalwart'
    static_configs:
      - targets:
        - stalwart1:9090
        - stalwart2:9090
        - stalwart3:9090
```

### Capacity Planning

**Formula for instance count:**
```
Instances needed = (Peak emails/hour ÷ 10,000) × 1.5
                   (1.5x for headroom)
```

**Example:**
- 50,000 emails/hour peak
- 50,000 ÷ 10,000 = 5
- 5 × 1.5 = 7.5 → **8 instances**

**When to scale:**
- ✅ CPU > 70% sustained
- ✅ Memory > 80% sustained
- ✅ Queue depth growing
- ✅ Response time > target SLA

---

## Kubernetes Deployment

### Kubernetes Architecture

```yaml
# stalwart-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stalwart
  labels:
    app: stalwart
spec:
  replicas: 3  # Start with 3, scale as needed
  selector:
    matchLabels:
      app: stalwart
  template:
    metadata:
      labels:
        app: stalwart
    spec:
      containers:
      - name: stalwart
        image: stalwart:production
        ports:
        - containerPort: 25
          name: smtp
        - containerPort: 143
          name: imap
        - containerPort: 8080
          name: http
        env:
        - name: ADMIN_SECRET
          valueFrom:
            secretKeyRef:
              name: stalwart-secrets
              key: admin-password
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
# Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: stalwart-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: stalwart
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
---
# Service for SMTP
apiVersion: v1
kind: Service
metadata:
  name: stalwart-smtp
spec:
  type: LoadBalancer
  ports:
  - port: 25
    targetPort: 25
    protocol: TCP
  selector:
    app: stalwart
---
# Service for IMAP
apiVersion: v1
kind: Service
metadata:
  name: stalwart-imap
spec:
  type: LoadBalancer
  ports:
  - port: 143
    targetPort: 143
    protocol: TCP
  selector:
    app: stalwart
---
# Service for HTTP Admin
apiVersion: v1
kind: Service
metadata:
  name: stalwart-http
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
  selector:
    app: stalwart
```

### Deploy to Kubernetes

```bash
# Create secrets
kubectl create secret generic stalwart-secrets \
  --from-literal=admin-password='YOUR_SECURE_PASSWORD' \
  --from-literal=db-password='YOUR_DB_PASSWORD'

# Deploy Stalwart
kubectl apply -f stalwart-deployment.yaml

# Watch scaling
kubectl get hpa -w

# Scale manually if needed
kubectl scale deployment stalwart --replicas=5
```

---

## Performance Optimization

### General Optimization Tips

1. **Use SSDs/NVMe** - 10x faster than HDDs
2. **Enable compression** - LZ4 or Zstd reduces I/O
3. **Tune connection pools** - Match your concurrency needs
4. **Use CDN for static assets** - Reduce server load
5. **Enable caching** - Redis for frequently accessed data
6. **Optimize queries** - Add database indexes
7. **Monitor bottlenecks** - Use profiling tools

### Configuration Checklist

**For Vertical Scaling:**
- [ ] Adjust RocksDB cache to 25-30% of RAM
- [ ] Enable write/read optimization based on workload
- [ ] Tune PostgreSQL shared_buffers and work_mem
- [ ] Use connection pooling
- [ ] Enable compression (LZ4 or Zstd)

**For Horizontal Scaling:**
- [ ] Configure cluster coordination (Kafka/NATS/Redis)
- [ ] Use PostgreSQL with read replicas
- [ ] Configure S3/MinIO for shared blob storage
- [ ] Setup Redis Sentinel or Cluster
- [ ] Deploy load balancer (HAProxy/nginx)
- [ ] Configure health checks
- [ ] Enable monitoring (Prometheus)
- [ ] Setup auto-scaling (Kubernetes HPA)

---

## Scaling Decision Matrix

| Users | Architecture | Storage | Instances | Cluster |
|-------|--------------|---------|-----------|---------|
| < 1K | Single server | RocksDB | 1 | No |
| 1K-5K | Single server | RocksDB/PostgreSQL | 1 | No |
| 5K-10K | Single server | PostgreSQL + S3 | 1 | Optional |
| 10K-50K | Horizontal | PostgreSQL + S3 + Redis | 3-5 | Yes |
| 50K-100K | Horizontal | PostgreSQL + S3 + Redis | 5-10 | Yes |
| 100K+ | Horizontal | PostgreSQL (sharded) + S3 + Redis | 10+ | Yes |

---

## Additional Resources

- **[SETUP.md](./SETUP.md)** - Production deployment guide
- **[Storage Backend Selection](./SETUP.md#storage-backend-selection)** - Detailed storage comparison
- **[SEPARATE_DOMAINS_SETUP.md](./SEPARATE_DOMAINS_SETUP.md)** - Multi-domain configuration
- **[Stalwart Documentation](https://stalw.art/docs)** - Official documentation
- **[Kubernetes Best Practices](https://kubernetes.io/docs/concepts/cluster-administration/)** - K8s documentation

---

*Last updated: 2026-02-10*
*Stalwart version: 0.15.4*
