# Wallet & Ledger — Staged E2E Checklist

Run against **staging** after deploying Firestore rules, indexes, Storage rules, and Cloud Functions.

## Preconditions

1. Two accounts: **Investor** (`users/{uid}.kycStatus == approved`) and **Admin** (`users/{uid}.role == admin`).
2. Deploy: `firebase deploy --only firestore:rules,firestore:indexes,functions,storage` (or project-specific targets).

## Deposit flow

1. Investor: open **Wallet & ledger** → **Deposit request** → submit amount, method, optional proof image.
2. Verify `deposit_requests` + `transactions` documents exist with `pending`.
3. Admin: **Admin → Finance console → Deposits** → Approve (optional note).
4. Verify transaction `approved`, wallet `totalDeposited` / `availableBalance` updated.
5. Repeat with **Reject** on another pending deposit; verify `rejected` and **no** balance credit.

## Withdrawal flow

1. Investor: **Withdrawal** with amount ≤ available.
2. Verify `withdrawal_requests` + `transactions` pending; wallet shows **reserved** funds.
3. Admin: **Withdrawals (Pending)** → Approve.
4. Admin: **Approved (settle)** → Complete with settlement reference.
5. Verify transaction `completed`, `totalWithdrawn` increased, reserve cleared.
6. Test **Reject/Cancel** from pending or approved (per server rules) and verify reserve released.

## Manual postings

1. Admin: **Manual** tab → profit entry for a user → verify ledger + wallet.
2. Adjustment with note ≥ 3 chars (positive/negative) → verify `totalAdjustments` and balance.

## Regression (non-breaking)

1. OTP login and KYC gates still behave; non-approved KYC cannot call wallet callables (server `failed-precondition`).
2. Existing `users` / `kyc` flows unchanged aside from additive reads.

## Backward compatibility

- Legacy client writes to `transactions` / `wallets` are **denied** by design; all mutations must go through Functions.
