# Wallet & Ledger — Audit & Reconciliation

## Audit logging

- Cloud Functions call `appendAudit` after investor deposit/withdrawal requests and every admin transition (`firebase/functions/wallet_helpers.js`, `wallet_ledger.js`).
- Events are stored in `audit_logs` with `actorId`, `actorRole`, `action`, `entityType`, `entityId`, optional `before`/`after`, and `createdAt`.
- Firestore rules: **client writes denied**; only Admin SDK (Functions) appends logs.

## Scheduled reconciliation

- `reconcileWalletsDaily` runs on schedule (`0 3 * * *`, `firebase/functions/wallet_ledger.js`).
- For each user (batch limit 500), it runs `recalculateWallet` and logs when `availableBalance` changes materially (operational signal for drift investigation).

## Manual repair

- Callable `recalculateWalletForUser` (admin-only) recomputes `wallets/{userId}` from the immutable `transactions` collection.
- Exposed in **Admin → Finance console → Manual → Recalculate wallet**.

## Operational monitoring

- Use Cloud Logging / Functions logs for `recalculateWallet failed` (trigger `onTransactionUpdated`) and `Wallet recalculated` info lines from the nightly job.
- Set alerts on error rate for wallet callables in production.
