const os = require("os");
const path = require("path");
const fs = require("fs/promises");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const ApkReader = require("adbkit-apkreader");

const db = () => admin.firestore();
const storage = () => admin.storage();

async function assertAdmin(uid) {
  const authUser = await admin.auth().getUser(uid);
  const claimAdmin =
    authUser.customClaims?.admin === true ||
    authUser.customClaims?.role === "admin";
  if (claimAdmin) return;
  const userSnap = await db().collection("users").doc(uid).get();
  const role = String(userSnap.data()?.role || "").toLowerCase().trim();
  if (role !== "admin") {
    throw new HttpsError("permission-denied", "Admin only.");
  }
}

function normalizeVersionCode(raw) {
  if (raw == null) return 0;
  const parsed = Number.parseInt(String(raw), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

exports.parseInvestorApkMetadata = onCall(
  {
    region: "us-central1",
    cors: true,
    invoker: "public",
    memory: "512MiB",
    cpu: 0.25,
    timeoutSeconds: 120,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    await assertAdmin(request.auth.uid);

    const storagePath = String(request.data?.storagePath || "").trim();
    if (!storagePath.startsWith("releases/android/")) {
      throw new HttpsError(
        "invalid-argument",
        "storagePath must be inside releases/android/.",
      );
    }

    const tmpPath = path.join(
      os.tmpdir(),
      `apk_${Date.now()}_${Math.random().toString(36).slice(2)}.apk`,
    );

    try {
      const bucket = storage().bucket();
      await bucket.file(storagePath).download({ destination: tmpPath });

      const reader = await ApkReader.open(tmpPath);
      const manifest = await reader.readManifest();
      const packageId = String(manifest?.package || "").trim();
      const versionName = String(manifest?.versionName || "").trim();
      const versionCode = normalizeVersionCode(manifest?.versionCode);

      if (!packageId || !versionName || versionCode <= 0) {
        throw new HttpsError(
          "failed-precondition",
          "Could not extract package/version metadata from APK.",
        );
      }

      return {
        packageId,
        versionName,
        versionCode,
      };
    } catch (error) {
      logger.error("parseInvestorApkMetadata_failed", {
        storagePath,
        error: String(error),
      });
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        "internal",
        "Failed to parse APK metadata from uploaded file.",
      );
    } finally {
      try {
        await fs.unlink(tmpPath);
      } catch (_) {
        // Ignore temp cleanup failures.
      }
    }
  },
);
