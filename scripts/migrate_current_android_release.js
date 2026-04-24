/**
 * Backfill current app_releases/current_android into release history.
 *
 * Usage (from project root):
 *   node scripts/migrate_current_android_release.js
 *
 * Requirements:
 * - GOOGLE_APPLICATION_CREDENTIALS must point to a service-account json.
 * - Firestore access to this project.
 */

const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

async function run() {
  const db = admin.firestore();
  const currentRef = db.collection("app_releases").doc("current_android");
  const currentSnap = await currentRef.get();
  if (!currentSnap.exists || !currentSnap.data()) {
    throw new Error("app_releases/current_android is missing.");
  }
  const current = currentSnap.data();
  const versionCode = Number.parseInt(String(current.versionCode || "0"), 10);
  if (!Number.isFinite(versionCode) || versionCode <= 0) {
    throw new Error(`Invalid versionCode in current_android: ${current.versionCode}`);
  }

  const historyRef = db
    .collection("app_releases")
    .doc("android_releases")
    .collection("items")
    .doc(String(versionCode));

  const batch = db.batch();
  batch.set(
    historyRef,
    {
      platform: "android",
      versionCode,
      versionName: String(current.versionName || ""),
      packageId: String(current.packageId || ""),
      apkStoragePath: String(current.apkStoragePath || ""),
      apkUrl: String(current.apkUrl || ""),
      requiredAfterDays: Number.parseInt(String(current.requiredAfterDays || "7"), 10),
      title: String(current.title || ""),
      message: String(current.message || ""),
      isActive: current.isActive === true,
      publishedBy: String(current.publishedBy || ""),
      publishedAt: current.publishedAt || admin.firestore.FieldValue.serverTimestamp(),
      uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
      releaseRef: historyRef.path,
      migratedFromCurrentAndroid: true,
    },
    { merge: true },
  );
  batch.set(
    currentRef,
    {
      releaseRef: historyRef.path,
      packageId: String(current.packageId || ""),
    },
    { merge: true },
  );
  await batch.commit();
  // eslint-disable-next-line no-console
  console.log(`Backfill complete for versionCode ${versionCode}.`);
}

run().catch((error) => {
  // eslint-disable-next-line no-console
  console.error(error);
  process.exitCode = 1;
});
