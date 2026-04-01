# Wallet & Ledger — Firestore Schema (additive)

All financial writes are performed by **Cloud Functions** (Admin SDK). Clients **read** only.

## Collections

### `wallets/{userId}` (projection)

| Field | Type | Notes |
|-------|------|--------|
| `userId` | string | Same as doc id |
| `totalDeposited` | number | Sum of **approved** deposits |
| `totalWithdrawn` | number | Sum of **completed** withdrawals |
| `totalProfit` | number | Sum of profit entries (approved) |
| `totalAdjustments` | number | Sum of adjustments (signed) |
| `reservedAmount` | number | Pending withdrawal holds |
| `availableBalance` | number | Derived: deposited + profit + adjustments − withdrawn − reserved |
| `currentBalance` | number | Same as available for MVP |
| `lastRecalculatedAt` | timestamp | |

### `transactions/{txId}` (immutable ledger)

| Field | Type | Notes |
|-------|------|--------|
| `id` | string | Human-readable id e.g. `TXN-2026-xxxxx` |
| `userId` | string | |
| `type` | string | `deposit` \| `withdrawal` \| `profit` \| `adjustment` |
| `amount` | number | Positive; sign by type |
| `status` | string | `pending` \| `approved` \| `completed` \| `rejected` \| `cancelled` |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |
| `notes` | string? | |
| `requestId` | string? | Links to deposit/withdrawal request |
| `proofUrl` | string? | Deposit proof |
| `paymentMethod` | string? | Deposit |
| `approvedBy` | string? | uid |
| `completedBy` | string? | uid |

### `deposit_requests/{requestId}`

| Field | Type |
|-------|------|
| `userId` | string |
| `amount` | number |
| `paymentMethod` | string |
| `proofUrl` | string? |
| `status` | `pending` \| `approved` \| `rejected` |
| `transactionId` | string |
| `createdAt` | timestamp |
| `updatedAt` | timestamp |

### `withdrawal_requests/{requestId}`

| Field | Type |
|-------|------|
| `userId` | string |
| `amount` | number |
| `status` | `pending` \| `approved` \| `completed` \| `rejected` \| `cancelled` |
| `transactionId` | string |
| `createdAt` | timestamp |
| `updatedAt` | timestamp |
| `adminNote` | string? |

### `audit_logs/{logId}`

| Field | Type |
|-------|------|
| `actorId` | string |
| `actorRole` | string |
| `action` | string |
| `entityType` | string |
| `entityId` | string |
| `before` | map? |
| `after` | map? |
| `createdAt` | timestamp |
