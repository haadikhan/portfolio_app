/**
 * Firebase Cloud Functions — Wakalat Invest
 */

const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const { recalculateWallet } = require("./wallet_helpers");
const { notifyAllAdmins } = require("./notifications");

const walletLedger = require("./wallet_ledger");
const notifications = require("./notifications");
const marketData = require("./market_data");
const appUpdates = require("./app_updates");
Object.assign(exports, walletLedger);
Object.assign(exports, notifications);
Object.assign(exports, marketData);
Object.assign(exports, appUpdates);

exports.onKycSubmittedForReview = onDocumentUpdated(
  {
    document: "kyc/{userId}",
    region: "us-central1",
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;
    const beforeStatus = (before?.status || "").toLowerCase();
    const afterStatus = (after.status || "").toLowerCase();
    if (afterStatus !== "underreview" || beforeStatus === "underreview") {
      return;
    }
    const uid = event.params.userId;
    try {
      await notifyAllAdmins({
        title: "KYC submitted for review",
        body: `A user submitted KYC for review.`,
        type: "kyc",
        category: "admin",
        action: "open_kyc",
        refId: uid,
        amount: null,
        currency: "PKR",
      });
    } catch (e) {
      logger.warn("onKycSubmittedForReview_failed", { error: String(e) });
    }
  },
);

exports.onTransactionUpdated = onDocumentUpdated(
  {
    document: "transactions/{txId}",
    region: "us-central1",
    memory: "256MiB",
    cpu: 0.08,
  },
  async (event) => {
    const after = event.data?.after?.data();
    const uid = after?.userId;
    if (uid) {
      try {
        await recalculateWallet(uid);
      } catch (e) {
        logger.error("recalculateWallet failed", e);
      }
    }
  },
);
