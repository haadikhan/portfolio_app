/**
 * Seed script: initial five-market calculation config
 * Seeds default allocations and rates into settings/five_market_calc
 *
 * USAGE:
 *   cd firebase
 *   node scripts/seed_five_market_calc.js
 *
 * SAFE TO RE-RUN: uses set() with merge:false only on first run check.
 * Admin can update rates via admin panel once UI is built (Phase 5).
 *
 * Default allocations: Stock 40%, Tech 25%, Debt 25%, Money 5%, Gold 5%
 * Default rates: Debt 18% p.a., Money 15% p.a.
 * Tech benchmark: 100% p.a. | Tech target: 500% p.a. (informational)
 */

const admin = require("firebase-admin");
const path = require("path");

let credential;
try {
  const sa = require(
    path.resolve(__dirname, "../functions/serviceAccountKey.json")
  );
  credential = admin.credential.cert(sa);
} catch {
  credential = admin.credential.applicationDefault();
}

admin.initializeApp({ credential });

const config = {
  allocations: {
    stock: 40,
    tech:  25,
    debt:  25,
    money:  5,
    gold:   5,
  },
  rates: {
    debtAnnualPercent:              18.0,
    moneyAnnualPercent:             15.0,
    techBenchmarkAnnualPercent:    100.0,
    techTargetAnnualPercent:       500.0,
  },
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedBy: "seed_script",
};

async function seed() {
  try {
    const ref = admin.firestore()
      .collection("settings")
      .doc("five_market_calc");

    const snap = await ref.get();
    if (snap.exists) {
      console.log("⚠  settings/five_market_calc already exists — skipping.");
      console.log("   Delete the document first if you want to reset defaults.");
      process.exit(0);
    }

    await ref.set(config);
    console.log("✓ settings/five_market_calc seeded with defaults.");
    console.log("  Allocations: Stock 40%, Tech 25%, Debt 25%, Money 5%, Gold 5%");
    console.log("  Debt: 18% p.a. | Money: 15% p.a.");
    console.log("  Tech benchmark: 100% p.a. | Tech target: 500% p.a.");
    process.exit(0);
  } catch (err) {
    console.error("✗ Seed failed:", err);
    process.exit(1);
  }
}

seed();
