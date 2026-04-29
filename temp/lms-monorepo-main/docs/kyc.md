# KYC API Guide (Frontend)

This document explains `kyc.v1.KycService` APIs and the required call order for borrower KYC.

## Service

- gRPC service: `kyc.v1.KycService`

## Consent Type Enum

- `CONSENT_TYPE_AADHAAR_KYC` (stored as `aadhar_kyc`)
- `CONSENT_TYPE_PAN_KYC` (stored as `pan_kyc`)

## RPC List

- `RecordUserConsent`
- `InitiateAadhaarKyc`
- `VerifyAadhaarKycOtp`
- `VerifyPanKyc`
- `GetBorrowerKycStatus`
- `ListBorrowerKycHistory`

## Required Flow

1. Record consent for Aadhaar: `RecordUserConsent`
2. Aadhaar OTP start: `InitiateAadhaarKyc`
3. Aadhaar OTP verify: `VerifyAadhaarKycOtp`
4. Record consent for PAN: `RecordUserConsent`
5. PAN verify: `VerifyPanKyc`
6. Status/history fetch as needed:
   - `GetBorrowerKycStatus`
   - `ListBorrowerKycHistory`

All KYC RPCs are borrower-only and require auth metadata.

Verification is marked successful only when provider status is valid and profile details match borrower profile data (name, DOB, and gender for Aadhaar; name/DOB for PAN).

## gRPC Metadata

- `authorization: Bearer <ACCESS_TOKEN>`

## 1) RecordUserConsent

Use before Aadhaar or PAN verification.

Example request:

```json
{
  "consent_type": "CONSENT_TYPE_AADHAAR_KYC",
  "consent_version": "v1",
  "consent_text": "I authorize identity verification for Aadhaar KYC.",
  "is_granted": true,
  "source": "web",
  "ip_address": "203.0.113.10",
  "user_agent": "Mozilla/5.0",
  "metadata_json": "{\"screen\":\"kyc-consent\"}"
}
```

Example response:

```json
{
  "success": true,
  "consent_id": "37fcf4b5-311b-4f5a-8de4-31c6db6fe0e2"
}
```

## 2) InitiateAadhaarKyc

Starts OTP flow with Sandbox and returns `reference_id`.

Example request:

```json
{
  "aadhaar_number": "123412341234",
  "reason": "KYC verification"
}
```

Example response:

```json
{
  "success": true,
  "reference_id": "1234567",
  "provider_transaction_id": "fad04935-d568-4830-a650-7abd4ecec507",
  "message": "OTP sent successfully"
}
```

## 3) VerifyAadhaarKycOtp

Verifies OTP and persists history/current snapshot.

Example request:

```json
{
  "reference_id": "1234567",
  "otp": "123456"
}
```

Example success response:

```json
{
  "success": true,
  "status": "VALID",
  "message": "Aadhaar Card Exists",
  "provider_transaction_id": "33d55e13-d145-4b95-ae8e-5cbafc1d6e5c",
  "name": "John Doe",
  "date_of_birth": "21-04-1985",
  "gender": "M"
}
```

Example failure response (invalid OTP):

```json
{
  "success": false,
  "status": "",
  "message": "Invalid OTP",
  "provider_transaction_id": "98a4f051-7e2a-4117-bd71-3396555c74ee"
}
```

Example failure response (OTP expired):

```json
{
  "success": false,
  "status": "",
  "message": "aadhaar otp has expired, please request a new one",
  "provider_transaction_id": "cd820d41-3a81-47c8-b370-1e8d9935fb85"
}
```

When OTP is expired, the history record stores `failure_code: OTP_EXPIRED`.

## 4) VerifyPanKyc

Runs PAN verification against Sandbox API (`/kyc/pan/verify`) and persists history/current snapshot.

Example request:

```json
{
  "pan": "XXXPX1234A",
  "name_as_per_pan": "John Ronald Doe",
  "date_of_birth": "11/11/2001",
  "reason": "KYC verification"
}
```

Example response:

```json
{
  "success": true,
  "status": "valid",
  "message": "",
  "provider_transaction_id": "22b497f0-25ac-40c3-84b8-5ec0e5d86f9f",
  "name_as_per_pan_match": true,
  "date_of_birth_match": true,
  "aadhaar_seeding_status": "y"
}
```

## 5) GetBorrowerKycStatus

Returns verification flags and timestamps from borrower profile.

Example request:

```json
{}
```

Example response:

```json
{
  "is_aadhaar_verified": true,
  "is_pan_verified": true,
  "aadhaar_verified_at": "2026-04-17T11:10:08Z",
  "pan_verified_at": "2026-04-17T11:12:44Z"
}
```

## 6) ListBorrowerKycHistory

Returns merged KYC attempt history across Aadhaar and PAN.

`doc_type` values:

- `KYC_DOC_TYPE_UNSPECIFIED` (both)
- `KYC_DOC_TYPE_AADHAAR`
- `KYC_DOC_TYPE_PAN`

Example request:

```json
{
  "doc_type": "KYC_DOC_TYPE_UNSPECIFIED",
  "limit": 20,
  "offset": 0
}
```

Example response:

```json
{
  "items": [
    {
      "id": "d6f4c29f-71f6-4b71-9685-b2577f7d8f54",
      "doc_type": "KYC_DOC_TYPE_PAN",
      "status": "SUCCESS",
      "failure_code": "",
      "failure_reason": "",
      "provider_transaction_id": "22b497f0-25ac-40c3-84b8-5ec0e5d86f9f",
      "attempted_at": "2026-04-17T11:12:44Z"
    },
    {
      "id": "37cb9030-4f9b-49b8-bc35-2f38620f8225",
      "doc_type": "KYC_DOC_TYPE_AADHAAR",
      "status": "FAILED",
      "failure_code": "AADHAAR_VERIFY_FAILED",
      "failure_reason": "Invalid OTP",
      "provider_transaction_id": "98a4f051-7e2a-4117-bd71-3396555c74ee",
      "attempted_at": "2026-04-17T11:11:02Z"
    }
  ]
}
```

## Error Notes

- `InvalidArgument`: missing/invalid input (including enum value).
- `FailedPrecondition`: consent missing for requested KYC operation.
- `PermissionDenied`: non-borrower user calls KYC endpoints.
- `Internal` with Sandbox error details: API subscription/wallet issues (404, 403) or upstream failures (5xx).
