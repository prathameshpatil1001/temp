# API Conventions (Frontend)

This file covers common rules used across auth and onboarding APIs.

## Transport

- Protocol: gRPC
- Service host (local compose): `localhost:18080`
- Reflection is enabled in dev, so grpc tooling can inspect services.

## Authentication Header

For protected methods, send metadata:

- `authorization: Bearer <ACCESS_TOKEN>`

If missing or invalid, backend returns `Unauthenticated`.

## Request ID (Recommended)

Send a per-request correlation id in metadata:

- `x-request-id: <unique-id>`

Why:

- backend request logs include `request_id`, making frontend/backend trace matching easier.
- useful for debugging retries, intermittent failures, and user-reported issues.

Recommended format:

- UUID v4 (or any globally unique string your client stack already uses).

## Public vs Protected Methods

Public methods (no JWT needed):

- `AuthService/Hello`
- `AuthService/InitiateSignup`
- `AuthService/VerifySignupOTPs`
- `AuthService/LoginPrimary`
- `AuthService/InitiateReopen`
- `AuthService/SelectLoginMFAFactor`
- `AuthService/VerifyLoginMFA`
- `AuthService/InitiateForgotPassword`
- `AuthService/VerifyForgotPasswordOTPs`
- `AuthService/ResetForgotPassword`
- `AuthService/RefreshToken`

Protected methods (JWT required):

- `AuthService/SetupTOTP`
- `AuthService/VerifyTOTPSetup`
- `AuthService/GetMyProfile`
- `AuthService/ChangePassword`
- `AuthService/Logout`
- `DstService/GetDstAccount`
- `DstService/ListDstAccounts`
- `OnboardingService/CompleteBorrowerOnboarding`

## Token Model

- Access token: short-lived JWT.
- Refresh token: opaque token used to start `InitiateReopen`.
- Use returned access token for protected RPCs.
- Reopen/unlock flow is MFA-based: `InitiateReopen` -> `SelectLoginMFAFactor` -> `VerifyLoginMFA`.

## Error Handling

Handle gRPC codes at minimum:

- `Unauthenticated`: token/session invalid, login again.
- `PermissionDenied`: role cannot call this method.
- `InvalidArgument`: request validation failed; show field-level message.
- `FailedPrecondition`: step order issue (e.g., MFA factor not selected).
- `AlreadyExists`: duplicate entity (email/phone/profile).
- `NotFound`: resource/session expired or missing.
- `Internal`: retry once if safe, then show fallback error.

## Enums

Always send enum names exactly as defined in proto (for JSON tooling paths), e.g.:

- `USER_ROLE_BORROWER`
- `USER_ROLE_DST`
- `BORROWER_GENDER_MALE`
- `BORROWER_EMPLOYMENT_TYPE_SALARIED`

## Date and Decimal Formats

- `date_of_birth`: `YYYY-MM-DD`
- `monthly_income`: decimal as string (e.g. `"75000.50"`)

## Session/Flow Rules

- Signup is multi-step: initiate -> verify OTPs.
- Login MFA is strict 3-step: login primary -> select factor -> verify factor.
- Reopen MFA is strict 3-step: initiate reopen -> select factor -> verify factor.
- Onboarding is separate service and should be called post-auth for borrower users.
