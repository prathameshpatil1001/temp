# Protobuf Contracts

This directory contains the gRPC protocol buffer (`.proto`) definitions for the LMS platform. These files act as the single source of truth for the API contracts between the backend (`core-api`) and all clients.

## Structure

The proto files are organized by domain and versioned:

- **`admin/v1`**: Admin operations, employee account management, and branch/DST configuration.
- **`auth/v1`**: Authentication workflows including signup, login, MFA (TOTP), session management, and password recovery.
- **`dst/v1`**: Direct Sales Team (DST) specific operations and account retrieval.
- **`kyc/v1`**: Borrower Know Your Customer (KYC) processes, including Aadhaar and PAN verification.
- **`loan/v1`**: Loan product configuration, application lifecycle, collateral tracking, and repayment schedules.
- **`media/v1`**: Media upload protocols (e.g., presigned URLs for Cloudflare R2) and retrieval.
- **`onboarding/v1`**: The specific workflow for borrower profile completion and onboarding.

## Code Generation

We use standard `protoc` tooling wrapped in a Makefile at the monorepo root to generate Go code from these definitions.

To regenerate the Go bindings:

```bash
cd ..
make proto
```

The generated Go code is placed in `services/core-api/internal/transport/grpc/generated/`. 

## Best Practices

- Always define a request and response message for every RPC method, even if currently empty.
- Keep backwards compatibility in mind. Do not change existing field numbers or types. If a field is no longer used, mark it as `reserved` or `deprecated`.
- Use descriptive enum values following the format `[DOMAIN]_[FIELD]_[VALUE]`, e.g., `USER_ROLE_BORROWER`.
