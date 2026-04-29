# Database Migrations (golang-migrate)

This project uses `golang-migrate` for schema changes on non-empty databases.

Migration files live in:

- `services/core-api/internal/repository/migrations`

## Why this exists

- `docker-entrypoint-initdb.d` scripts run only on first Postgres initialization.
- Existing DBs need explicit, versioned migrations during deployment.

## Prerequisites

Install `migrate` CLI locally (or use Docker commands shown below).

Default DSN used by Make targets:

- `postgres://lms:lms@localhost:15432/lms?sslmode=disable`

You can override DSN per command:

```bash
make migrate-up POSTGRES_DSN="postgres://user:pass@host:5432/db?sslmode=disable"
```

## Common Commands

From repo root:

```bash
make migrate-version
make migrate-up
make migrate-down
make migrate-force VERSION=1
make migrate-create NAME=add_new_table
```

Docker-based equivalents:

```bash
make migrate-version-docker
make migrate-up-docker
make migrate-force-docker VERSION=1
```

## Existing DB Baseline Flow

Use this when a DB already has tables created outside migration history.

1. Backup DB.
2. Mark baseline version as applied:

```bash
make migrate-force VERSION=1
```

3. Apply newer migrations:

```bash
make migrate-up
```

In this repository:

- `000001_init_schema` is baseline schema
- `000002_branch_profile_refactor` upgrades old branch-manager model
- `000003_add_dst_and_branch_commission` adds DST role/profile and branch commission field
- `000004_add_kyc_and_user_consents` adds borrower KYC history/current tables and user consent tracking
- `000005_add_media_files` adds media metadata storage for R2-backed uploads
- `000006_add_employee_identity_fields` adds immutable employee serial/code for manager and officer profiles
- `000007_add_loan_management` adds loan products, applications, collateral, underwriting, and repayment ledger tables

## Docker-based Run (no local migrate install)

Use the compose migration service:

```bash
docker compose run --rm migrate -path /migrations -database "postgres://lms:lms@postgres:5432/lms?sslmode=disable" version
docker compose run --rm migrate -path /migrations -database "postgres://lms:lms@postgres:5432/lms?sslmode=disable" up
docker compose run --rm migrate -path /migrations -database "postgres://lms:lms@postgres:5432/lms?sslmode=disable" force 1
```

## Deployment Recommendation

For production deploys:

1. run migrations first,
2. then deploy/restart `core-api`.

Do not rely on init SQL scripts for existing DB upgrades.

## Compose-Based Automation

`docker-compose.yml` is configured so migrations run automatically before `core-api` starts:

- `migrate` service runs `migrate ... up`
- `core-api` depends on `migrate` with `service_completed_successfully`

Behavior:

- if DB is up to date, migrate exits successfully and `core-api` starts.
- if pending migrations exist, they are applied first.
- if migration fails, `core-api` does not start.

You can still run migration commands manually for debugging:

```bash
make migrate-version-docker
make migrate-up-docker
```

### One-time setup for existing DBs

Before enabling automated `up` on already-existing DBs, baseline once:

```bash
docker compose run --rm migrate -path /migrations -database "postgres://lms:lms@postgres:5432/lms?sslmode=disable" force 1
docker compose run --rm migrate -path /migrations -database "postgres://lms:lms@postgres:5432/lms?sslmode=disable" up
```
