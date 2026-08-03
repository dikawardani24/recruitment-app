# 13 — Deployment Architecture

## 1. Environments

| Env | Purpose | Infra |
|-----|---------|-------|
| dev | local dev | docker-compose: api, worker, pg, qdrant, redis |
| staging | pre-prod, provider stubs, eval | cloud, smaller instance classes |
| prod | production | cloud, HA, autoscaling |

## 2. Target Topology (AWS — cloud-agnostic pattern)

```
                          ┌─────────────┐
                          │  CloudFront  │  CDN for static assets + resume PDFs (signed URLs)
                          └──────┬──────┘
                                 │ HTTPS
                    ┌────────────▼────────────┐
                    │  ALB (TLS, WAF, rate)   │
                    └────┬─────────────┬──────┘
              ┌──────────▼───┐    ┌────▼────────────┐
              │  API / Fargate│    │  Worker / Fargate│
              │  autoscale    │    │  autoscale      │
              │  (stateless)  │    │  (queue-driven) │
              └─┬──────────┬──┘    └─┬─────────────┬─┘
                │          │         │             │
    ┌───────────▼───┐  ┌───▼─────┐  │     ┌───────▼─────────┐
    │  RDS PostgreSQL│  │ ElastiCache│ │     │  ECS Qdrant     │
    │  Multi-AZ,     │  │ Redis      │ │     │  (or Managed    │
    │  read replica  │  │ (queue/cache)│     │   Qdrant Cloud) │
    │  PITR, WAL     │  └─────────┘  │     └──────────────────┘
    └───────────────┘    ┌──────────▼──────────┐
                         │  S3 (resumes, backups)│
                         └─────────────────────┘
                    External: LLM/Embedding/OCR providers (allowlisted)
                    Observability: CloudWatch + OpenTelemetry Collector + Prometheus
```

## 3. Service Definitions

| Service | Image | Replicas | Resources | Autoscaling |
|---------|-------|----------|-----------|-------------|
| API | `ghcr.io/ats/api` | 2 (min) | 0.5–2 vCPU / 1–4 GB | CPU > 70% → scale to 10 |
| Worker | `ghcr.io/ats/worker` | 1 (min) | 1–4 vCPU / 2–8 GB | Queue depth > threshold → scale |
| Qdrant | `qdrant/qdrant` | 1 (prod 3-replica set) | GPU not required | Snapshot-based |
| RDS | `postgres:16` | Multi-AZ | 1 replica for reads | Vertical + read replica |
| Redis | `redis:7` | 1 (cluster for prod) | — | — |
| Embedding | sidecar or provider | batch | CPU / optional GPU | — |

## 4. Container & Image Strategy

- Multi-stage Dockerfiles: dev (with hot reload) vs prod (slim, non-root).
- Worker and API share the same codebase but different entrypoints (`uvicorn app.main:app` vs `arq worker.AppWorkerSettings`).
- Health checks: `/healthz` (liveness), `/readyz` (deps: PG, Redis, Qdrant).

## 5. IaC & GitOps

- **Terraform** modules per service (doc 04 §4); environments `dev/staging/prod`.
- **CI/CD**: GitHub Actions — lint+test+build on PR; deploy to staging on merge; prod via promoted image tag + DB migrations (`alembic upgrade`) run as pre-deploy job.
- **Zero-downtime**: rolling ECS deployments; **backward-compatible migrations**; vector re-index runs after new worker drains old queues.

## 6. Data Storage & Backup

| Store | Backup | Retention | DR |
|-------|--------|-----------|-----|
| RDS | PITR + nightly snapshot | 30 d | cross-region snapshot copy |
| S3 | versioning + lifecycle | 90 d | cross-region replication |
| Qdrant | snapshot to S3 nightly | 14 d | restore + rebuild from PG (source of truth) |
| Redis | AOF (non-critical cache only) | 1 d | rebuild from PG |

**Key DR principle**: PostgreSQL is the source of truth; Qdrant and Redis are rebuildable — worst-case DR = restore PG + re-index vectors (batch job).

## 7. Scaling Strategy

- **API**: stateless → scale horizontally behind ALB; per-replica LLM concurrency semaphore to avoid provider throttling.
- **Worker**: scale on queue depth; bounded concurrency (embedding batches, OCR processes); GPU worker pool for local embedding if > certain throughput.
- **Qdrant**: HNSW in RAM budget; replica shards for read-heavy search; scaled before index-growth bursts.
- **PostgreSQL**: connection pooling (pgbouncer) + read replica for `/search` hydration + dashboard reads.

## 8. Security Deployment Controls

- WAF rules on ALB (SQLi, XSS, rate limiting).
- Private subnets for DB/cache/Qdrant; security groups allow only API/worker.
- Secrets in AWS Secrets Manager; IAM roles for S3/Qdrant access (no static keys).
- VPC flow logs + GuardDuty; audit trail for PII access.
- TLS 1.3; HSTS; signed URLs for resume PDFs (30-min expiry).

## 9. Observability Stack

- **Metrics**: Prometheus (service, provider, pipeline gauges) + Grafana dashboards; SLOs (search p95 < 2s, pipeline p95 < 60s).
- **Logs**: CloudWatch Logs w/ structured JSON; error alerting (PagerDuty) on pipeline failure rate > 1%.
- **Traces**: OTel collector → traces per pipeline stage + search.
- **Alerts**: queue depth, LLM error rate, Qdrant search latency, PG replica lag.

## 10. Local Dev (docker-compose)

```yaml
services:
  api:      { build: ./backend, ports: ["8000:8000"], depends_on: [pg, qdrant, redis] }
  worker:   { build: ./backend, command: arq worker }
  pg:       { image: postgres:16, environment: POSTGRES_DB: ats }
  qdrant:   { image: qdrant/qdrant:latest, ports: ["6333:6333"] }
  redis:    { image: redis:7 }
```

Seed script loads sample resumes + golden eval set for development.
