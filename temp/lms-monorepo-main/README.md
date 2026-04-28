# LMS Monorepo

This repository contains the backend API, protobuf contracts, and frontend integration docs for the Loan Management System (LMS) project.

## Purpose of the Backend

The backend is designed to provide a robust, scalable, and secure API for the LMS platform. It handles all core business logic including user authentication and session management, borrower onboarding, KYC processing, direct sales team (DST) management, loan product configurations, and media uploads. It serves as the single source of truth for the platform, ensuring data integrity across PostgreSQL and Redis.

The main runnable service is `core-api` (Go + gRPC).

## Monorepo Layout

```text
lms-monorepo/
├── proto/                             # Protobuf definitions for all gRPC APIs (See proto/README.md)
│   ├── admin/v1/admin.proto           # Admin and employee management contract
│   ├── auth/v1/auth.proto             # Auth and session contract
│   ├── dst/v1/dst.proto               # DST account retrieval contract
│   ├── kyc/v1/kyc.proto               # Borrower KYC contract
│   ├── media/v1/media.proto           # Media upload/list contract
│   ├── onboarding/v1/onboarding.proto # Borrower onboarding contract
│   └── loan/v1/loan.proto             # Loan service contract
├── services/
│   └── core-api/                      # Go backend main service (See services/core-api/README.md)
├── docker-compose.yml                 # Local infra + core-api
├── docs/                              # Frontend integration docs
├── Makefile                           # Helper commands (proto, sqlc, docker)
└── go.work                            # Go workspace (currently includes core-api)
```

Frontend API docs are available in `docs/README.md`.

## Architecture At A Glance

- Transport: gRPC using protobuf definitions from `proto/`
- Services: `AuthService`, `AdminService`, `DstService`, `OnboardingService`, `KycService`, `MediaService`, `LoanService`
- Backend: Go service in `services/core-api`
- Data layer:
  - Postgres for users, profiles, refresh tokens, webauthn credentials, KYC history, media metadata
  - Redis for OTP/MFA/session state
- Auth model:
  - Password (Argon2)
  - OTP verification for signup
  - TOTP for MFA
  - JWT access token + refresh token rotation
  - WebAuthn scaffolding (partially implemented)

## Quick Start (Recommended: Docker)

### Prerequisites

- Docker Desktop / Docker Engine with Compose v2

### Run everything

From repo root:

```bash
docker compose up --build
```

or:

```bash
make docker-up
```

What starts:

- `postgres` on `localhost:15432`
- `redis` on `localhost:16379`
- `core-api` gRPC server on `localhost:18080`

### Database initialization

On first startup of the Postgres volume, schema is auto-loaded from:

- `services/core-api/internal/repository/schema/001_auth.sql`

If you already have an existing Postgres Docker volume and need a clean re-init:

```bash
docker compose down -v
docker compose up --build
```

## Quick Start (Local Go Service)

If you want to run API directly on your host and keep infra in Docker:

1. Start infra only (Postgres + Redis):

```bash
docker compose up -d postgres redis
```

2. Run backend:

```bash
cd services/core-api
POSTGRES_DSN="postgres://lms:lms@localhost:15432/lms?sslmode=disable" REDIS_ADDR="localhost:16379" go run .
```

Default config (if env vars are not set) is defined in `services/core-api/internal/config/config.go`.

Useful env vars:

- `GRPC_PORT` (default: `8080`)
- `POSTGRES_DSN` (default points to local postgres)
- `REDIS_ADDR` (default: `localhost:6379`)
- `REDIS_PASSWORD` (optional)
- `JWT_SIGNING_KEY` (default dev key; change for non-local use)

## Tooling & Code Generation

### 1) Protobuf to Go

Generates gRPC/Go types into `services/core-api/internal/transport/grpc/generated/*`.

```bash
make proto
```

Inputs:

- `proto/auth/v1/auth.proto`
- `proto/admin/v1/admin.proto`
- `proto/dst/v1/dst.proto`
- `proto/kyc/v1/kyc.proto`
- `proto/media/v1/media.proto`
- `proto/onboarding/v1/onboarding.proto`
- `proto/loan/v1/loan.proto`

### 2) SQL to Go (sqlc)

Generates typed query code into `services/core-api/internal/repository/generated/`.

```bash
make sqlc
```

Inputs:

- Schema: `services/core-api/internal/repository/schema/`
- Queries: `services/core-api/internal/repository/queries/`

Config file:

- `services/core-api/sqlc.yaml`

### 3) Basic Go validation

```bash
cd services/core-api
go test ./...
go build ./...
```

## How To Read The Codebase

If you are new to this repo, read in this order:

1. Contracts first
   - `proto/auth/v1/auth.proto`
   - `proto/admin/v1/admin.proto`
   - `proto/dst/v1/dst.proto`
   - `proto/onboarding/v1/onboarding.proto`
   - `proto/kyc/v1/kyc.proto`
   - `proto/media/v1/media.proto`
2. Server entrypoint + wiring
   - `services/core-api/main.go`
   - `services/core-api/cmd/server/run.go`
3. Transport layer
   - `services/core-api/internal/transport/grpc/auth_handler.go`
   - `services/core-api/internal/transport/grpc/interceptors/auth.go`
4. Business logic
   - `services/core-api/internal/service/auth/service.go`
5. Persistence
   - `services/core-api/internal/repository/queries/*.sql`
   - `services/core-api/internal/repository/generated/*.go`
6. Infra/config utilities
   - `services/core-api/internal/db/*.go`
   - `services/core-api/internal/config/config.go`

## Backend Request Flow (Auth)

Typical call path:

1. gRPC method defined in proto
2. Handler receives request (`auth_handler.go`)
3. JWT/RBAC interceptors run (for protected methods)
4. Auth service executes business logic (`service.go`)
5. SQLC-generated repository methods read/write Postgres
6. Redis stores short-lived auth state (OTP/MFA/active token)

## gRPC API Surface (Current)

- `auth.v1.AuthService`
  - Signup: `InitiateSignup`, `VerifySignupOTPs`
  - Login/MFA: `LoginPrimary`, `InitiateReopen`, `SelectLoginMFAFactor`, `VerifyLoginMFA`
  - Account security: `SetupTOTP`, `VerifyTOTPSetup`, `GetMyProfile`, `ChangePassword`, forgot-password flow, WebAuthn begin/finish methods
  - Session: `RefreshToken` (returns precondition to use reopen flow), `Logout`
- `admin.v1.AdminService`
  - Admin bootstrap, employee creation/update, branch management, DST creation/commission updates
  - Employee accounts include immutable `employee_serial` + 6-digit `employee_code` for manager/officer
- `dst.v1.DstService`
  - DST account retrieval for admin/manager views: `GetDstAccount`, `ListDstAccounts`
- `onboarding.v1.OnboardingService`
  - Borrower onboarding: `CompleteBorrowerOnboarding`
- `kyc.v1.KycService`
  - Consent recording, Aadhaar OTP verify flow, PAN verification, borrower KYC status/history
- `media.v1.MediaService`
  - Presigned upload init/complete and user media listing
- `loan.v1.LoanService`
  - Loan product setup, application lifecycle, collateral/documents, bureau snapshots, loans, EMI schedule, and payments

### Signup behavior

Manual signup creates only borrower accounts.

`SignupRequest` does not take role as input.

Sample signup payload:

```json
{
  "email": "borrower@example.com",
  "phone": "+15550001111",
  "password": "StrongPassword123!"
}
```

### Login flow sequence

Current login requires explicit MFA factor selection:

1. `LoginPrimary`
2. `SelectLoginMFAFactor`
3. `VerifyLoginMFA`

`VerifyLoginMFA` without `SelectLoginMFAFactor` returns a failed precondition error.

### Change password RPC

`ChangePassword` is an authenticated RPC (JWT required).

- Any authenticated role can call it.
- `current_password` is mandatory.
- `new_password` must pass strength checks:
  - minimum 8 chars
  - at least one uppercase letter
  - at least one lowercase letter
  - at least one digit
  - at least one special character
- On successful update, `users.is_requiring_password_change` is set to `false`.

Sample request payload:

```json
{
  "current_password": "CurrentPassword123!",
  "new_password": "NewSecurePassword123!"
}
```

Sample `grpcurl` (replace token):

```bash
grpcurl -plaintext \
  -H "authorization: Bearer <ACCESS_TOKEN>" \
  -d '{"current_password":"CurrentPassword123!","new_password":"NewSecurePassword123!"}' \
  localhost:18080 auth.v1.AuthService/ChangePassword
```

## Troubleshooting

- `failed to connect to postgres`: verify Postgres is running and DSN is correct.
- `failed to connect to redis`: Redis is required at startup; check `REDIS_ADDR` and container health.
- Auth tables missing: if schema did not initialize, recreate Postgres volume (`docker compose down -v`).
- Generated code out of sync: rerun `make proto` and/or `make sqlc`.

## Current Gaps / Notes

- Bootstrap admin creation is currently public by default (`CreateAdminAccount` in `publicMethods`); disable for production.
- OTP values are currently printed for local debugging.
- Direct `RefreshToken` rotation is intentionally disabled; clients should use `InitiateReopen` + MFA.
- Loan service contract exists but implementation is currently a stub.

## Handy Commands

From repo root:

```bash
make docker-up
make docker-down
make proto
make sqlc
```
