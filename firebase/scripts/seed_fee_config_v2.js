/**
 * Seed script: add v2 fee fields to settings/fee_config
 * Adds new fields WITHOUT overwriting any existing fields.
 * Uses merge: true — safe to run multiple times.
 *
 * USAGE:
 *   cd firebase
 *   node scripts/seed_fee_config_v2.js
 *
 * WHAT THIS DOES:
 * - Adds defaultFeeVersion: "v1" (safe default)
 * - Adds frontEndLoadAllDeposits: false
 * - Adds managementFeeAnnualPct: 1.5
 * - Adds performanceFeeHwmPct: 15
 * - Adds financialYearStartMonth: 7
 * - Does NOT touch any existing field
 */

const admin = require("firebase-admin");
const path = require("path");

let credential;
try {
  const sa = require(
    path.resolve(__dirname, "../functions/serviceAccountKey.json"),
  );
  credential = admin.credential.cert(sa);
} catch {
  credential = admin.credential.applicationDefault();
}

admin.initializeApp({ credential });

const v2Additions = {
  defaultFeeVersion: "v1",
  frontEndLoadAllDeposits: false,
  managementFeeAnnualPct: 1.5,
  performanceFeeHwmPct: 15.0,
  financialYearStartMonth: 7,
};

async function seed() {
  try {
    const ref = admin.firestore().collection("settings").doc("fee_config");

    const snap = await ref.get();
    const existing = snap.exists ? snap.data() : {};
    console.log("Existing fee_config fields:", Object.keys(existing));

    const toAdd = {};
    for (const [key, val] of Object.entries(v2Additions)) {
      if (!(key in existing)) {
        toAdd[key] = val;
      } else {
        console.log(
          `  Skipping ${key} — already exists (${existing[key]})`,
        );
      }
    }

    if (Object.keys(toAdd).length === 0) {
      console.log("✓ All v2 fields already present. Nothing to add.");
      process.exit(0);
    }

    await ref.set(toAdd, { merge: true });
    console.log("✓ Added v2 fields to fee_config:", Object.keys(toAdd));
    process.exit(0);
  } catch (err) {
    console.error("✗ Seed failed:", err);
    process.exit(1);
  }
}

seed();
