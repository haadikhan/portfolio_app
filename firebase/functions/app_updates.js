const os = require("os");
const path = require("path");
const fs = require("fs/promises");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

/**
 * Regex-escape project id fragments when building ACAO matchers (Hosting / firebaseapp URLs).
 */
function escapeRegexLit(s) {
  return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Must match Flutter web bucket in `lib/firebase_options.dart` (DefaultFirebaseOptions.web).
 */
const FIREBASE_WEB_STORAGE_BUCKET_ID = "portfolio-e97b1.firebasestorage.app";

/** Origins permitted to call Firebase callable HTTPS from Flutter web / browsers. */
function callableCorsAllowlist(projectId) {
  const pid = escapeRegexLit(projectId.trim() || "portfolio-e97b1");
  return [
    // http://localhost and http://localhost:<port>
    /^http:\/\/localhost(?::\d+)?$/i,
    /^http:\/\/127\.0\.0\.1(?::\d+)?$/i,
    /^https:\/\/.*\.vercel\.app$/i,
    "https://portfolio-e97b1.web.app",
    "https://portfolio-e97b1.firebaseapp.com",
    new RegExp(`^https:\\/\\/.*\\.${pid}\\.web\\.app$`, "i"),
    new RegExp(`^https:\\/\\/.*\\.${pid}\\.firebaseapp\\.com$`, "i"),
  ];
}

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

/**
 * Same bucket ID as Flutter web (`firebase_options` → storageBucket).
 * Override with env STORAGE_BUCKET for non-default environments only.
 */
function resolveDefaultStorageBucketName() {
  const explicit =
    typeof process.env.STORAGE_BUCKET === "string"
      ? process.env.STORAGE_BUCKET.trim()
      : "";
  if (explicit) return explicit;
  return FIREBASE_WEB_STORAGE_BUCKET_ID;
}

function parseFirebaseConfigSafe() {
  try {
    return JSON.parse(process.env.FIREBASE_CONFIG || "{}");
  } catch (_) {
    return {};
  }
}

const gcloudProjectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  parseFirebaseConfigSafe().projectId ||
  "portfolio-e97b1";

function normalizeVersionCode(raw) {
  if (raw == null) return 0;
  if (typeof raw === "bigint") {
    const n = Number(raw);
    return Number.isFinite(n) && n > 0 && n <= Number.MAX_SAFE_INTEGER
      ? Math.floor(n)
      : 0;
  }
  const parsed = Number.parseInt(String(raw), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

function looksLikeTransientInfraFailure(error) {
  const blob = `${error && error.code} ${error && error.message} ${String(error)}`;
  return /ENOTFOUND|EAI_AGAIN|ETIMEDOUT|ECONNRESET|ECONNREFUSED|GaxiosError/i.test(
    blob,
  );
}

/** @returns {HttpsError | null} */
function storageFailureToHttpsError(error) {
  const message =
    error && typeof error.message === "string"
      ? error.message
      : String(error ?? "");
  const code = error && error.code;

  if (code === 404 || /No such object|not found\b|404\b/i.test(message)) {
    return new HttpsError(
      "not-found",
      "Uploaded APK was not found in Storage. Try uploading again.",
    );
  }
  if (code === 403 || code === "403" || /\b403\b|access denied/i.test(message)) {
    return new HttpsError(
      "permission-denied",
      "Storage refused access when reading the uploaded APK.",
    );
  }
  return null;
}

exports.parseInvestorApkMetadata = onCall(
  {
    region: "us-central1",
    cors: callableCorsAllowlist(gcloudProjectId),
    enforceAppCheck: false,
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
      const ApkReader = require("adbkit-apkreader");
      const bucketName = resolveDefaultStorageBucketName();
      const bucket = storage().bucket(bucketName);
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
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
        storagePath,
      });
      if (error instanceof HttpsError) {
        throw error;
      }
      if (looksLikeTransientInfraFailure(error)) {
        throw new HttpsError(
          "unavailable",
          "Could not reach Storage to finish parsing. Retry in a moment.",
        );
      }
      const storageErr = storageFailureToHttpsError(error);
      if (storageErr) {
        throw storageErr;
      }
      throw new HttpsError(
        "failed-precondition",
        "Could not read package/version metadata from this APK file.",
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
