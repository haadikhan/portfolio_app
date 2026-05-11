/**
 * One-time seed script for settings/deposit_instructions
 *
 * BEFORE RUNNING:
 * 1. Default values below are obvious DUMMIES for UI confirmation only —
 *    replace with real bank details before production.
 * 2. Make sure you have Node.js installed
 * 3. Run from the firebase/ directory:
 *      cd firebase
 *      node scripts/seed_deposit_instructions.js
 *
 * SAFE TO RUN MULTIPLE TIMES — uses merge:true, will not overwrite
 * fields that already have real values if you add new optional fields later.
 *
 * After running, verify in Firebase Console:
 *   Firestore → settings → deposit_instructions
 *
 * firebase-admin is loaded from firebase/functions/node_modules (same deps as
 * Cloud Functions). If require fails, run `npm install` in firebase/functions.
 */

const fs = require("fs");
const path = require("path");
const admin = require(path.join(
  __dirname,
  "../functions/node_modules/firebase-admin",
));

function resolveProjectId() {
  const fromEnv =
    process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
  if (fromEnv) return fromEnv;
  try {
    const rcPath = path.resolve(__dirname, "../../.firebaserc");
    const raw = fs.readFileSync(rcPath, "utf8");
    const parsed = JSON.parse(raw);
    return parsed?.projects?.default || undefined;
  } catch {
    return undefined;
  }
}

// Try service account file first, fall back to application default
let credential;
try {
  const sa = require(
    path.resolve(__dirname, "../functions/serviceAccountKey.json"),
  );
  credential = admin.credential.cert(sa);
} catch {
  credential = admin.credential.applicationDefault();
}

const projectId = resolveProjectId();
admin.initializeApp(
  projectId ? { credential, projectId } : { credential },
);

// Dummy data — wrong on purpose; confirms the app reads Firestore. Replace for production.
const depositInstructions = {
  companyBankName: "NOT REAL BANK (Dummy HBL)",
  accountHolderName: "FAKE — Wakalat Test Holder",
  ibanOrAccountNumber: "PK00DUMMY0000000000000001",
  branchName: "Dummy Branch — Main Boulevard",
  instructions:
    "This text is test-only. Do not transfer real money to any dummy account.",
};

async function seed() {
  try {
    await admin
      .firestore()
      .collection("settings")
      .doc("deposit_instructions")
      .set(depositInstructions, { merge: true });
    console.log("✓ settings/deposit_instructions written successfully.");
    process.exit(0);
  } catch (err) {
    console.error("✗ Failed to write deposit_instructions:", err);
    process.exit(1);
  }
}

seed();
