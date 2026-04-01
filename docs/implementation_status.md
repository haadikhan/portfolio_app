# Wakalat Invest Implementation Status

## Completed Foundation
- Layered Flutter structure under `lib/src`.
- Environment config with compile-time flags in `app_config.dart`.
- Shared theme and reusable app scaffold.
- Firebase-ready startup bootstrap in `main.dart`.

## Implemented Modules
- Auth and OTP flow shell.
- KYC capture/status shell.
- Wallet and immutable ledger derivation logic (client-side prototypes) **and** production path: Firestore `transactions` + `wallets` projection with Cloud Functions (`firebase/functions`).
- **Wallet & Ledger (production)**: investor wallet/history (read-only), deposit/withdrawal requests + proof upload, admin Finance console (queues, ledger list, profit/adjustment, wallet recalc). See `docs/wallet_ledger_schema.md`, `docs/wallet_ledger_operations.md`, `docs/wallet_ledger_e2e.md`.
- Returns application logic with idempotency guard.
- Investor dashboard metrics and growth chart.
- Reports center shell and monthly generation trigger stub.
- Notification center screen.
- Admin dashboard controls and analytics section.
- CRM dashboard with assignments/follow-ups/logs.
- Legal disclaimer and consent gate.

## Firebase Backend Scaffolding
- Firestore RBAC rules in `firebase/firestore.rules` (ledger collections server-write only).
- Storage rules for `deposit_proofs/{uid}/**` in `firebase/storage.rules`.
- Cloud Functions: wallet/ledger callables, `onTransactionUpdated` projection hook, nightly `reconcileWalletsDaily`; stubs for monthly reports and event notifications where applicable.

## Next Production Steps
- Connect remaining screens to Firestore collections where still stubbed.
- Add Firebase OTP implementation and secure KYC file uploads (beyond wallet proofs).
- Return batch posting integration with ledger (if distinct from profit entries).
- Add PDF generation service and branded templates.
- Implement full FCM token registration and delivery retries.
