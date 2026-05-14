# Five-market daily feature — Firestore document schema (Phase 1)

This document describes the **additive** Firestore shapes for the five-market daily calculation feature. No calculation logic runs in Phase 1; this is schema and access rules only.

---

## A) `settings/five_market_calc` (single document)

Admin-editable market configuration:

```json
{
  "allocations": {
    "stock": 40,
    "tech": 25,
    "debt": 25,
    "money": 5,
    "gold": 5
  },
  "rates": {
    "debtAnnualPercent": 18.0,
    "moneyAnnualPercent": 15.0,
    "techBenchmarkAnnualPercent": 100.0,
    "techTargetAnnualPercent": 500.0
  },
  "updatedAt": "<Timestamp>",
  "updatedBy": "<admin UID string>"
}
```

- `allocations`: all five numeric fields are percentages of the **base** invested in each market. **All five must sum to 100.** Validated on write (enforced in a later phase / admin UI / functions).
- `rates.debtAnnualPercent` / `rates.moneyAnnualPercent`: admin-editable; effective next calendar day.
- `rates.techBenchmarkAnnualPercent`: minimum guaranteed benchmark (annual %).
- `rates.techTargetAnnualPercent`: informational target only (annual %).

---

## B) `settings/pakistan_holidays` (single document)

```json
{
  "holidays": [
    {
      "date": "2026-03-23",
      "name": "Pakistan Day",
      "isIslamicHoliday": false,
      "estimatedDate": false
    }
  ],
  "seededAt": "<Timestamp>",
  "seededVersion": "1.0.0"
}
```

- `holidays`: array of objects; `date` is ISO `yyyy-MM-dd` in **PKT** calendar date.
- `isIslamicHoliday`: `true` when moon-sighting dependent.
- `estimatedDate`: `true` when the date is an estimate and admins should verify before the day.
- Seeded for **2026, 2027, 2028** via `firebase/scripts/seed_pakistan_holidays.js`. Bump `seededVersion` when re-seeding.

---

## C) `settings/five_market_day_overrides/{yyyy-MM-dd}` (one document per date)

Admin per-date override. **Only one** of `forceClosedAll` or `forceOpenDailyProfits` may be `true` at a time (mutually exclusive); validate on write in a later phase.

**Firestore path:** `five_market_day_overrides` is stored as a **subcollection** under a singleton settings document `settings/five_market` so each calendar day is a normal document ID:

`settings/five_market/five_market_day_overrides/{yyyy-MM-dd}`

```json
{
  "date": "2026-05-15",
  "forceClosedAll": false,
  "forceOpenDailyProfits": false,
  "reason": "Unexpected strike",
  "createdBy": "<admin UID string>",
  "createdAt": "<Timestamp>"
}
```

- `date`: same string as the document ID (`yyyy-MM-dd`).

---

## D) `investment_daily_market_close/{yyyy-MM-dd}` (one document per trading day)

EOD snapshot written by Cloud Function after **16:05 PKT**. **Read-only** for clients.

```json
{
  "date": "2026-05-15",
  "tradingDay": true,
  "kmi30": {
    "closingValue": 242661.27,
    "openingValue": 242486.67,
    "changeAbsolute": 63.04,
    "changePercent": 0.03,
    "high": 243688.36,
    "low": 242486.67,
    "volume": 7800000
  },
  "gold": {
    "closingPricePkr": 280000.0,
    "openingPricePkr": 279500.0,
    "changePercent": 0.18,
    "source": "metals.dev"
  },
  "snapshotAt": "<Timestamp>",
  "effectiveDaySource": "calendar"
}
```

- `effectiveDaySource`: `"calendar"` | `"forceOpen"` | `"forceClosed"`.
- `changePercent` fields are **percentage** values (e.g. `0.03` means +0.03%).

---

## E) `portfolios/{uid}/five_market_daily/{yyyy-MM-dd}` (one document per user per day)

Daily ledger row per user, written by **00:05 PKT** job (later phase).

```json
{
  "date": "2026-05-15",
  "basePkr": 100000.0,
  "tradingDay": true,
  "markets": {
    "stock": {
      "allocatedPkr": 40000.0,
      "changePercent": 0.03,
      "profitPkr": 12.0,
      "status": "REALIZED"
    },
    "tech": {
      "allocatedPkr": 25000.0,
      "annualPercent": 100.0,
      "profitPkr": 68.49,
      "status": "REALIZED"
    },
    "debt": {
      "allocatedPkr": 25000.0,
      "annualPercent": 18.0,
      "profitPkr": 12.33,
      "status": "REALIZED"
    },
    "money": {
      "allocatedPkr": 5000.0,
      "annualPercent": 15.0,
      "profitPkr": 2.05,
      "status": "REALIZED"
    },
    "gold": {
      "allocatedPkr": 5000.0,
      "changePercent": 0.18,
      "profitPkr": 9.0,
      "status": "REALIZED"
    }
  },
  "totalProfitPkr": 103.87,
  "creditedToWallet": true,
  "creditedAt": "<Timestamp>",
  "notes": "Daily five-market profit 2026-05-15",
  "effectiveDaySource": "calendar"
}
```

- `markets.*.status`: `LIVE` | `REALIZED` | `CLOSED` | `NON_TRADING_DAY`.
- `basePkr`: allocation total from wallet at calculation time.

---

## F) `portfolios/{uid}` — one new field only

Add **only** this field to the existing portfolio document (do not restructure other fields):

```json
{
  "fiveMarketDailyLedger": false
}
```

- Default: field **missing** or `false` → legacy behavior (no daily five-market credits).
- `true` → opted into daily five-market credits (**admin-only** write in a later phase).
