# Onboarding API Guide (Frontend)

This document explains `onboarding.v1.OnboardingService` for borrower onboarding.

## Service

- gRPC service: `onboarding.v1.OnboardingService`
- RPC: `CompleteBorrowerOnboarding`

## When To Call

Call onboarding only after user is authenticated (you have `access_token`).

Typical borrower app sequence:

1. Complete auth login flow and get tokens.
2. Collect onboarding form data from screens.
3. Submit once using `CompleteBorrowerOnboarding`.

## Authentication and Authorization

- JWT required in metadata:
  - `authorization: Bearer <ACCESS_TOKEN>`
- Only borrower role is allowed for this RPC.
- User identity is derived from JWT in backend (frontend does not send `user_id`).

## Request: CompleteBorrowerOnboardingRequest

Required fields:

- `first_name` (string)
- `last_name` (string)
- `date_of_birth` (string, `YYYY-MM-DD`)
- `gender` (enum)
- `address_line1` (string)
- `city` (string)
- `state` (string)
- `pincode` (string)
- `employment_type` (enum)
- `monthly_income` (decimal string)
- `profile_completeness_percent` (int32, `0..100`)

Enums:

- `BorrowerGender`
  - `BORROWER_GENDER_MALE`
  - `BORROWER_GENDER_FEMALE`
  - `BORROWER_GENDER_OTHER`
- `BorrowerEmploymentType`
  - `BORROWER_EMPLOYMENT_TYPE_SALARIED`
  - `BORROWER_EMPLOYMENT_TYPE_SELF_EMPLOYED`
  - `BORROWER_EMPLOYMENT_TYPE_BUSINESS`

## Response

- `success` (`true` on completion)

## Backend Side Effects

On successful onboarding:

- borrower profile row is created
- user is activated (`is_active = true`)

## Error Cases to Handle

- `Unauthenticated`: missing/invalid/expired token.
- `PermissionDenied`: logged-in user is not borrower role.
- `InvalidArgument`: invalid field format (date/decimal/percent) or missing required fields.
- `AlreadyExists`: borrower profile already exists for this user.
- `Internal`: server/database issue.

## Frontend Submission Pattern

- Keep onboarding form state local until final submit.
- Submit only once on completion CTA.
- Disable submit button while in-flight.
- On `AlreadyExists`, treat as completed state and continue app flow.

## Example JSON Payload (grpc tooling style)

```json
{
  "first_name": "Aarav",
  "last_name": "Sharma",
  "date_of_birth": "1995-08-20",
  "gender": "BORROWER_GENDER_MALE",
  "address_line1": "221B Residency Road",
  "city": "Bengaluru",
  "state": "Karnataka",
  "pincode": "560001",
  "employment_type": "BORROWER_EMPLOYMENT_TYPE_SALARIED",
  "monthly_income": "85000.00",
  "profile_completeness_percent": 100
}
```
