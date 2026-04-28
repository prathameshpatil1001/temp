# DST API Guide (Frontend)

This document explains DST retrieval APIs in `dst.v1.DstService`.

## Authentication and Role

- JWT required in metadata:
  - `authorization: Bearer <ACCESS_TOKEN>`
- Role access summary:
  - `admin`: can fetch/list DST accounts across branches.
  - `manager`: can fetch/list DST accounts only from their own branch.

## RPC List

- `GetDstAccount`
- `ListDstAccounts`

## 1) Get DST Account (Admin/Manager)

RPC: `GetDstAccount`

Request fields:

- `user_id` (required DST user UUID)

Response:

- `account`
  - `user_id`, `profile_id`, `name`, `email`, `phone_number`
  - `is_active`, `is_requiring_password_change`
  - `branch_id`, `branch_name`, `branch_region`, `branch_city`
  - `created_at`

Behavior:

- admin can fetch any DST account.
- manager can fetch only DST accounts from their own branch.

## 2) List DST Accounts (Admin/Manager)

RPC: `ListDstAccounts`

Request fields:

- `branch_id` (optional for admin, manager must stay within own branch scope)
- `limit` (optional, default `20`, max `100`)
- `offset` (optional, default `0`)

Response:

- `items[]` of DST account objects (same shape as `GetDstAccountResponse.account`)

Behavior:

- admin can list by any branch.
- manager can list only their own branch.
