# Fee System v2 — Firestore document schema (Phase 1)

This document describes the **additive** Firestore shapes for Fee System v2. Phase 1 is schema, security rules, and seed/migration scripts only. No v2 fee calculation or daily jobs run in this phase.

**Timezone:** Pakistan Standard Time (`Asia/Karachi`, UTC+5). Daily keys use `yyyy-MM-dd` in PKT unless noted.

**Versioning:** Investors are on fee engine `v1` (legacy monthly) or `v2` (daily management + HWM performance). Monthly jobs must skip `v2` investors; daily jobs (Phase 3+) must skip `v1`.

---

## A) `settings/fee_config` — new fields (existing unchanged)

Single document: `settings/fee_config`.

### Existing fields (unchanged)

| Field | Type | Notes |
|-------|------|--------|
| `isEnabled` | boolean | Master switch for fee charging |
| `managementFeePctAnnual` | number | **v1** annual management % (monthly = ÷ 12 at month-end) |
| `performanceFeePct` | number | **v1** % of monthly gross profit |
| `referralFeePct` | number | **v1** one-time % on first approved deposit |
| `frontEndLoadPct` | number | Front-end load % on deposit(s) |
| `frontEndLoadFirstDepositOnly` | boolean | **v1** if true, front-end load only on first approved deposit |
| `updatedAt` | timestamp | Set by `saveFeeConfig` |
| `updatedBy` | string | Admin UID |

### New fields (Phase 1 seed — additive merge)

| Field | Type | Default (seed) | Purpose |
|-------|------|----------------|---------|
| `defaultFeeVersion` | `"v1"` \| `"v2"` | `"v1"` | Default engine when `users/{uid}.feeVersion` is missing |
| `frontEndLoadAllDeposits` | boolean | `false` | **v2:** front-end load on every deposit; `false` preserves v1 behavior |
| `managementFeeAnnualPct` | number | `1.5` | **v2** daily management rate (separate from `managementFeePctAnnual`) |
| `performanceFeeHwmPct` | number | `15` | **v2** HWM performance fee % (separate from `performanceFeePct`) |
| `financialYearStartMonth` | number | `7` | FY start month (7 = July, PKT) for year-end PDF |

---

## B) `users/{uid}` — one new field

| Field | Type | Who writes | Purpose |
|-------|------|------------|---------|
| `feeVersion` | `"v1"` \| `"v2"` | Admin only | Per-investor engine; missing → `fee_config.defaultFeeVersion` |

- **v1:** monthly management + monthly performance (`bookMonthEndFeesAndProfit`).
- **v2:** daily management + daily HWM performance (Phase 3+).

---

## C) `referrals/{investorUid}` — NEW collection

**Document ID** = `investorUid` (the client, not the referrer).

```json
{
  "investorUid": "abc123",
  "referrerName": "Full Name",
  "referrerCnic": "42101-1234567-1",
  "referrerAddress": "Full address",
  "referrerFaName": "Bank account holder name",
  "depositCount": 0,
  "totalCommissionPkr": 0,
  "assignedBy": "adminUid",
  "assignedAt": "<Timestamp>",
  "updatedAt": "<Timestamp>",
  "notes": "optional"
}
```

### Commission halving sequence (`depositCount` before deposit)

| `depositCount` | Referral share of front-end load |
|----------------|----------------------------------|
| 0 | 50% |
| 1 | 25% |
| 2 | 12.5% |
| n | 50% / 2^n |

---

## D) `company_fee_ledger/{entryId}` — NEW collection

Auto-ID. One row per fee event (Phase 2+ writers).

```json
{
  "date": "2026-05-30",
  "investorUid": "abc123",
  "feeType": "front_end_load",
  "grossFeePkr": 3000,
  "referralSharePkr": 1500,
  "netToCompanyPkr": 1500,
  "referrerName": "Full Name",
  "depositRequestId": "reqId",
  "transactionId": "txId",
  "periodKey": "2026-05-30",
  "createdAt": "<Timestamp>"
}
```

**`feeType`:** `front_end_load` | `referral_commission` | `management_daily` | `performance_hwm`

---

## E) `portfolios/{uid}/management_fee_daily/{yyyy-MM-dd}` — NEW subcollection

Silent ledger — not in investor transaction history (Phase 3+).

```json
{
  "date": "2026-05-30",
  "basePkr": 1000000,
  "annualRatePct": 1.5,
  "dailyFeePkr": 41.1,
  "daysInFY": 365,
  "deductedAt": "<Timestamp>",
  "walletTxId": "linkedTxId",
  "ytdTotal": 1234.56
}
```

---

## F) `portfolios/{uid}` — new fields for v2

| Field | Type | Initial | Purpose |
|-------|------|---------|---------|
| `feeVersion` | `"v1"` \| `"v2"` | optional | Mirror of `users/{uid}.feeVersion` |
| `performanceHwm` | number | `0` | HWM on adjusted equity; never decreases |
| `netDeposits` | number | `0` | Recalculated on deposit/withdrawal (Phase 2) |
| `ytdManagementFee` | number | `0` | Resets FY start (1 July PKT) |
| `lastHwmUpdatedAt` | timestamp? | — | Last HWM increase |
| `hwmLockedUntil` | timestamp? | — | Reserved |

---

## G) Financial year definition

| Concept | Value |
|---------|--------|
| Financial year | 1 July → 30 June (Pakistan) |
| Timezone | `Asia/Karachi` (PKT) |
| `daysInFY` | 365 or 366 |
| Year-end job | 30 June 23:59 PKT (Phase 4+) |
| Year-start reset | 1 July 00:01 PKT — reset `ytdManagementFee` |

---

## Phase 1 scripts

```bash
cd firebase
node --check scripts/seed_fee_config_v2.js
node --check scripts/migrate_investors_feeversion_v1.js
node --check scripts/init_portfolio_v2_fields.js
# Requires firebase-admin (from functions/node_modules):
#   $env:NODE_PATH="functions/node_modules"   # PowerShell
node scripts/seed_fee_config_v2.js
node scripts/migrate_investors_feeversion_v1.js
node scripts/init_portfolio_v2_fields.js
```

---

## Unchanged in Phase 1

- `applyDepositFees`, `recalculateWallet`, `approveDeposit`
- `getFeeConfig` / `saveFeeConfig` existing fields
- Flutter/Dart files

**Phase 1 function change:** `wallet_ledger.js` adds v2 skip guard in `runMonthEndProfitCredit` and `applyMonthlyReturns` only.
