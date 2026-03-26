# Wakalat Invest

Digital investment tracking and reporting platform (Flutter + Firebase-first).

## Implemented In This Repository

- Multi-module Flutter app shell for Investor, Admin, and CRM surfaces.
- Core ledger domain with immutable transaction-based wallet derivation.
- Returns engine baseline with duplicate-cycle protection.
- Dashboard/report/notification/legal/KYC/auth module screens.
- Firebase scaffolding (`firestore.rules`, cloud function stubs).

## Folder Structure

- `lib/src/app` app-level router and bootstrap.
- `lib/src/core` shared config, models, services, widgets, theme.
- `lib/src/features` feature modules (auth, kyc, ledger, investment, reports, notifications, admin, crm, legal).
- `firebase` backend rules and scheduled/event function stubs.
- `docs` implementation notes and rollout status.

## Run

```bash
flutter pub get
flutter run
```

## Firebase Setup (Required for production)

1. Create Firebase project and platforms.
2. Add platform config files.
3. Deploy Firestore rules from `firebase/firestore.rules`.
4. Deploy functions from `firebase/functions`.
5. Follow detailed integration steps in `docs/firebase_integration_setup.md`.

## Compliance Intent

This system is designed as a private investment tracking and reporting platform:
- It records and displays transactions/portfolio state.
- It does not execute trades or connect to exchanges.
- Returns and historical performance are not guarantees.
