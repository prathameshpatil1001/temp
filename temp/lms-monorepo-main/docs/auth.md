# Auth API Guide (Frontend)

This document explains `auth.v1.AuthService` APIs and the required call order.

## Service

- gRPC service: `auth.v1.AuthService`

## RPC List

- `Hello`
- `InitiateSignup`
- `VerifySignupOTPs`
- `SetupTOTP`
- `VerifyTOTPSetup`
- `LoginPrimary`
- `InitiateReopen`
- `SelectLoginMFAFactor`
- `VerifyLoginMFA`
- `ChangePassword`
- `InitiateForgotPassword`
- `VerifyForgotPasswordOTPs`
- `ResetForgotPassword`
- `BeginWebAuthnRegistration`
- `FinishWebAuthnRegistration`
- `BeginWebAuthnLogin`
- `FinishWebAuthnLogin`
- `GetMyProfile`
- `RefreshToken`
- `Logout`

## 1) Signup Flow (Required Order)

1. `InitiateSignup`
2. `VerifySignupOTPs`

### 1.1 InitiateSignup

Request fields:

- `email`
- `phone`
- `password`

Behavior:

- Manual signup creates only borrower accounts.
- Role is not accepted in signup request.

Response:

- `registration_id`

Frontend action:

- Move user to OTP verification UI.

### 1.2 VerifySignupOTPs

Request fields:

- `registration_id`
- `email_code`
- `phone_code`

Response:

- `verified` (`true` on success)

Notes:

- User is verified here, but activation may still depend on onboarding rules.

## 2) Login + MFA Flow (Strict Order)

1. `LoginPrimary`
2. `SelectLoginMFAFactor`
3. `VerifyLoginMFA`

If step 2 is skipped, step 3 fails with `FailedPrecondition`.

### 2.1 LoginPrimary

Request:

- `email_or_phone`
- `password`

Response:

- `mfa_session_id`
- `allowed_factors` (subset of: `totp`, `email_otp`, `phone_otp`, `webauthn`)
- `is_requiring_password_change`

Frontend action:

- Show factor picker using `allowed_factors`.
- If `is_requiring_password_change=true`, force password-change flow after successful MFA.

### 2.2 SelectLoginMFAFactor

Request:

- `mfa_session_id`
- `factor` (`totp`, `email_otp`, `phone_otp`, `webauthn`)

Response:

- `challenge_sent`
- `challenge_target` (masked destination for OTP channels)
- `webauthn_request_options` (returned when `factor=webauthn`)

Frontend action:

- For OTP factors, show input waiting for code.
- For TOTP, show authenticator code input directly.
- For WebAuthn, use `webauthn_request_options` to run passkey assertion and submit `webauthn_assertion` in `VerifyLoginMFA`.

### 2.3 VerifyLoginMFA

Request:

- `mfa_session_id`
- `device_id`
- exactly one factor payload:
  - `totp_code`, or
  - `email_otp_code`, or
  - `phone_otp_code`

Response:

- `access_token`
- `refresh_token`

Frontend action:

- Store tokens securely.
- Use `access_token` in authorization metadata for protected calls.

## 2.4 Reopen Flow (Passwordless + MFA Required)

Use this when app is reopened and client still has a refresh token for the same device.

1. `InitiateReopen`
2. `SelectLoginMFAFactor`
3. `VerifyLoginMFA`

### InitiateReopen

Request:

- `refresh_token`
- `device_id`

Response:

- `mfa_session_id`
- `allowed_factors` (subset of: `totp`, `email_otp`, `phone_otp`, `webauthn`)

Behavior:

- Password is not required.
- Backend validates refresh token ownership and device binding.
- If refresh token is revoked (logged out), backend returns unauthenticated and password login is required.
- If refresh token is expired, backend returns unauthenticated and password login is required.
- On successful `VerifyLoginMFA`, backend revokes old refresh token and mints a new token pair.

## 3) TOTP Setup Flow (Authenticated)

Use this for enrolling authenticator app MFA after user is logged in.

1. `SetupTOTP`
2. `VerifyTOTPSetup`

### 3.1 SetupTOTP

Auth: required.

Request:

- empty message (`SetupTOTPRequest {}`)

Response:

- `secret`
- `provisioning_uri`

Frontend action:

- Render QR from `provisioning_uri`.

### 3.2 VerifyTOTPSetup

Auth: required.

Request:

- `code`
- `device_id`

Response:

- token pair (`access_token`, `refresh_token`)

## 4) Password Change (Authenticated)

RPC: `ChangePassword`

Auth: required.

Request:

- `current_password`
- `new_password`

Backend rules:

- Current password must match.
- New password must be strong:
  - min 8 chars
  - uppercase + lowercase + number + special char
- New password must differ from current password.
- On success, backend sets `is_requiring_password_change = false`.

Response:

- `success`

## 5) Token Refresh

RPC: `RefreshToken`

Auth: not required (uses refresh token).

Request:

- `refresh_token`
- `device_id`

Current behavior:

- Direct token refresh is disabled.
- Backend returns `FailedPrecondition` instructing clients to use `InitiateReopen` + MFA.

Frontend action:

- Do not retry direct `RefreshToken` on `FailedPrecondition`.
- Start `InitiateReopen`, complete MFA (`SelectLoginMFAFactor` -> `VerifyLoginMFA`), and then replace tokens atomically.

## 6) Forgot Password (Public)

Use this flow when user cannot provide current password.

1. `InitiateForgotPassword`
2. `VerifyForgotPasswordOTPs`
3. `ResetForgotPassword`

### 6.1 InitiateForgotPassword

Request:

- `email_or_phone`

Response:

- `reset_session_id`
- `challenge_sent`
- `masked_email`
- `masked_phone`

Current OTP behavior (temporary):

- both email OTP and phone OTP are fixed to `123456` in backend for development.

### 6.2 VerifyForgotPasswordOTPs

Request:

- `reset_session_id`
- `email_code`
- `phone_code`

Response:

- `verified`

### 6.3 ResetForgotPassword

Request:

- `reset_session_id`
- `new_password`

Response:

- `success`

Backend behavior:

- reset session must be OTP-verified first.
- `new_password` follows same strength rules as `ChangePassword`.
- on success, `is_requiring_password_change=false` for the user.

## 7) Get Current User Profile (Authenticated)

RPC: `GetMyProfile`

Auth: required.

Request:

- empty message (`GetMyProfileRequest {}`)

Response:

- Common user fields (all roles):
  - `user_id`, `email`, `phone`, `role`
  - `is_email_verified`, `is_phone_verified`, `is_active`
  - `is_requiring_password_change`, `has_totp`, `created_at`
- Role-specific `profile` (oneof):
  - `admin_profile`
  - `manager_profile`
  - `officer_profile`
  - `borrower_profile`
  - `dst_profile`

Branch-linked profile payloads (`manager_profile`, `officer_profile`, `dst_profile`) include optional `branch`:

- `branch_id`, `name`, `region`, `city`, `dst_commission`

Borrower profile payload is full and includes:

- `first_name`, `last_name`, `date_of_birth`, `gender`
- `address_line1`, `city`, `state`, `pincode`
- `employment_type`, `monthly_income`, `profile_completeness_percent`
- `is_aadhaar_verified`, `is_pan_verified`, `aadhaar_verified_at`, `pan_verified_at`

Frontend action:

- Call this immediately after successful login MFA to hydrate app state.
- Use `role` + role-specific `profile` to route to borrower/admin/manager/officer/dst experiences.

## 8) Logout (Authenticated)

RPC: `Logout`

Auth: required.

Request:

- `access_token`
- `refresh_token`

Response:

- `success`

Frontend action:

- Clear local auth state regardless of response retries.

## 9) WebAuthn (Current Status)

- Begin and finish registration/login methods are implemented.
- Expected client payload format:
  - `WebAuthnFinishRegRequest.credential`: raw JSON bytes of browser/native WebAuthn attestation response.
  - `WebAuthnFinishLoginRequest.assertion`: raw JSON bytes of WebAuthn assertion response.
- Backend stores WebAuthn session state in Redis with short TTL and persists credentials/sign counter in Postgres.

### WebAuthn Setup Requirements

Backend WebAuthn behavior depends on environment values:

- `WEBAUTHN_RP_ID`
- `WEBAUTHN_RP_ORIGINS` (comma-separated)
- `WEBAUTHN_RP_DISPLAY_NAME`

These must match your deployed domain/origin, otherwise passkey ceremonies will fail validation.

## Example Sequence (Borrower First Login)

1. Signup: `InitiateSignup` -> `VerifySignupOTPs`
2. Login: `LoginPrimary` -> `SelectLoginMFAFactor` -> `VerifyLoginMFA`
3. Borrower onboarding (other service): `OnboardingService/CompleteBorrowerOnboarding`
4. Optional: setup TOTP post-login
