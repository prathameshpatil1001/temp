# Frontend API Docs

This folder contains frontend-focused integration docs for the gRPC backend.

## Start Here

- `docs/api-conventions.md` - auth headers, token handling, error handling, and common request rules.
- `docs/auth.md` - all auth APIs with exact call order for signup, login, MFA, password change, refresh, and logout.
- `docs/onboarding.md` - borrower onboarding API and when to call it in the app lifecycle.
- `docs/admin.md` - admin-only APIs for creating employee accounts and bank branches.
- `docs/dst.md` - DST account retrieval APIs for admin/manager scoped views.
- `docs/loan.md` - loan product management, application lifecycle, collateral/docs, and repayment APIs.
- `docs/kyc.md` - borrower KYC APIs (consent, Aadhaar OTP KYC, PAN verification, status/history).
- `docs/media.md` - general media upload APIs using Cloudflare R2 with optional notes.
- `docs/migrations.md` - how to run `golang-migrate` locally and in deployment.

For Dokploy users, `docs/migrations.md` includes the exact pre-deploy migration command.

## Current Service Endpoints

- Auth service: `auth.v1.AuthService`
- Admin service: `admin.v1.AdminService`
- DST service: `dst.v1.DstService`
- KYC service: `kyc.v1.KycService`
- Media service: `media.v1.MediaService`
- Loan service: `loan.v1.LoanService`
- Onboarding service: `onboarding.v1.OnboardingService`

## Local Dev Default (current compose)

- gRPC host: `localhost:18080`
- Postgres host port: `15432`
- Redis host port: `16379`
