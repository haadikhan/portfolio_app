/**
 * One-time migration: set feeVersion = "v1" on all
 * existing users/{uid} documents that don't have it.
 *
 * USAGE:
 *   cd firebase
 *   node scripts/migrate_investors_feeversion_v1.js
 *
 * SAFE TO RE-RUN: skips users who already have feeVersion.
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

async function migrate() {
  try {
    const usersSnap = await admin.firestore().collection("users").get();

    let updated = 0;
    let skipped = 0;
    const BATCH_SIZE = 400;
    let batch = admin.firestore().batch();
    let batchCount = 0;

    for (const doc of usersSnap.docs) {
      const data = doc.data();

      if (data.feeVersion) {
        skipped++;
        continue;
      }

      const role = (data.role || "").toLowerCase();
      if (role === "admin" || role === "crm") {
        skipped++;
        continue;
      }

      batch.set(doc.ref, { feeVersion: "v1" }, { merge: true });
      batchCount++;
      updated++;

      if (batchCount >= BATCH_SIZE) {
        await batch.commit();
        batch = admin.firestore().batch();
        batchCount = 0;
        console.log(`  Committed batch, ${updated} updated so far...`);
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    console.log("✓ Migration complete.");
    console.log(`  Updated: ${updated} investors → feeVersion: "v1"`);
    console.log(`  Skipped: ${skipped} (already set or non-investor)`);
    process.exit(0);
  } catch (err) {
    console.error("✗ Migration failed:", err);
    process.exit(1);
  }
}

migrate();
