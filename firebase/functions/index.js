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

const walletLedger = require("./wallet_ledger");
const notifications = require("./notifications");
Object.assign(exports, walletLedger);
Object.assign(exports, notifications);

exports.onTransactionUpdated = onDocumentUpdated(
  "transactions/{txId}",
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
