/**
 * Initializes v2 fee fields on portfolios/{uid}.
 *
 * Sets: performanceHwm: 0, netDeposits: 0, ytdManagementFee: 0
 *
 * USAGE:
 *   cd firebase
 *   node scripts/init_portfolio_v2_fields.js
 *
 * SAFE TO RE-RUN: skips portfolios that already have all three fields.
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

async function init() {
  try {
    const portfoliosSnap = await admin
      .firestore()
      .collection("portfolios")
      .get();

    let updated = 0;
    let skipped = 0;
    const BATCH_SIZE = 400;
    let batch = admin.firestore().batch();
    let batchCount = 0;

    for (const doc of portfoliosSnap.docs) {
      const data = doc.data();

      if (
        "performanceHwm" in data &&
        "netDeposits" in data &&
        "ytdManagementFee" in data
      ) {
        skipped++;
        continue;
      }

      const toSet = {};
      if (!("performanceHwm" in data)) toSet.performanceHwm = 0;
      if (!("netDeposits" in data)) toSet.netDeposits = 0;
      if (!("ytdManagementFee" in data)) toSet.ytdManagementFee = 0;

      batch.set(doc.ref, toSet, { merge: true });
      batchCount++;
      updated++;

      if (batchCount >= BATCH_SIZE) {
        await batch.commit();
        batch = admin.firestore().batch();
        batchCount = 0;
        console.log(`  Committed batch, ${updated} updated...`);
      }
    }

    if (batchCount > 0) await batch.commit();

    console.log("✓ Portfolio v2 init complete.");
    console.log(`  Updated: ${updated}`);
    console.log(`  Skipped: ${skipped} (already initialized)`);
    process.exit(0);
  } catch (err) {
    console.error("✗ Init failed:", err);
    process.exit(1);
  }
}

init();
