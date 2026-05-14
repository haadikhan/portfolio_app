/**
 * Seed script: Pakistan public holidays for five-market daily feature
 * Seeds 2026, 2027, 2028 into settings/pakistan_holidays
 *
 * USAGE:
 *   cd firebase
 *   node scripts/seed_pakistan_holidays.js
 *
 * SAFE TO RE-RUN: uses set() which overwrites the document cleanly.
 *
 * Islamic holiday dates are ESTIMATED (moon-sighting dependent).
 * Admin can use five_market_day_overrides to force-close on actual date
 * if it differs from estimate.
 *
 * To add future years: add entries to the holidays array below and re-run.
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

const holidays = [
  // ── 2026 ────────────────────────────────────────────────
  // Fixed civil holidays
  { date: "2026-01-01", name: "New Year's Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2026-02-05", name: "Kashmir Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2026-03-23", name: "Pakistan Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2026-05-01", name: "Labour Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2026-08-14", name: "Independence Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2026-11-09", name: "Iqbal Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2026-12-25", name: "Quaid-e-Azam Day",
    isIslamicHoliday: false, estimatedDate: false },
  // Islamic holidays 2026 (estimated)
  { date: "2026-02-18", name: "Eid ul Fitr Day 1",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2026-02-19", name: "Eid ul Fitr Day 2",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2026-02-20", name: "Eid ul Fitr Day 3",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2026-04-27", name: "Eid ul Adha Day 1",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2026-04-28", name: "Eid ul Adha Day 2",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2026-04-29", name: "Eid ul Adha Day 3",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2026-07-26", name: "Ashura (Muharram 10)",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2026-09-04", name: "Eid Milad un Nabi",
    isIslamicHoliday: true, estimatedDate: true },

  // ── 2027 ────────────────────────────────────────────────
  { date: "2027-01-01", name: "New Year's Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2027-02-05", name: "Kashmir Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2027-03-23", name: "Pakistan Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2027-05-01", name: "Labour Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2027-08-14", name: "Independence Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2027-11-09", name: "Iqbal Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2027-12-25", name: "Quaid-e-Azam Day",
    isIslamicHoliday: false, estimatedDate: false },
  // Islamic holidays 2027 (estimated)
  { date: "2027-02-07", name: "Eid ul Fitr Day 1",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2027-02-08", name: "Eid ul Fitr Day 2",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2027-02-09", name: "Eid ul Fitr Day 3",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2027-04-17", name: "Eid ul Adha Day 1",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2027-04-18", name: "Eid ul Adha Day 2",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2027-04-19", name: "Eid ul Adha Day 3",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2027-07-15", name: "Ashura (Muharram 10)",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2027-08-24", name: "Eid Milad un Nabi",
    isIslamicHoliday: true, estimatedDate: true },

  // ── 2028 ────────────────────────────────────────────────
  { date: "2028-01-01", name: "New Year's Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2028-02-05", name: "Kashmir Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2028-03-23", name: "Pakistan Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2028-05-01", name: "Labour Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2028-08-14", name: "Independence Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2028-11-09", name: "Iqbal Day",
    isIslamicHoliday: false, estimatedDate: false },
  { date: "2028-12-25", name: "Quaid-e-Azam Day",
    isIslamicHoliday: false, estimatedDate: false },
  // Islamic holidays 2028 (estimated)
  { date: "2028-01-26", name: "Eid ul Fitr Day 1",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2028-01-27", name: "Eid ul Fitr Day 2",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2028-01-28", name: "Eid ul Fitr Day 3",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2028-04-05", name: "Eid ul Adha Day 1",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2028-04-06", name: "Eid ul Adha Day 2",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2028-04-07", name: "Eid ul Adha Day 3",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2028-07-04", name: "Ashura (Muharram 10)",
    isIslamicHoliday: true, estimatedDate: true },
  { date: "2028-08-12", name: "Eid Milad un Nabi",
    isIslamicHoliday: true, estimatedDate: true },
];

async function seed() {
  try {
    await admin.firestore()
      .collection("settings")
      .doc("pakistan_holidays")
      .set({
        holidays,
        seededAt: admin.firestore.FieldValue.serverTimestamp(),
        seededVersion: "1.0.0",
        note: "Islamic holiday dates are estimated. Use five_market_day_overrides to adjust actual dates.",
      });

    console.log(`✓ Seeded ${holidays.length} holidays (2026–2028)`);
    console.log("  Islamic holidays are marked estimatedDate: true");
    console.log("  Re-run this script in late 2027 to add 2029 dates.");
    process.exit(0);
  } catch (err) {
    console.error("✗ Seed failed:", err);
    process.exit(1);
  }
}

seed();
