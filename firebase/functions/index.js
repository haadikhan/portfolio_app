// Firebase Cloud Functions scaffold for Wakalat Invest.
// This file provides a baseline and can be expanded per environment.

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");

exports.generateMonthlyReports = onSchedule("0 0 1 * *", async () => {
  logger.info("Monthly report job triggered");
  // TODO: query wallets + transactions, generate PDF, store in reports collection.
});

exports.onTransactionUpdated = onDocumentUpdated(
  "transactions/{txId}",
  async (event) => {
    logger.info("Transaction changed", { txId: event.params.txId });
    // TODO: send push notifications for deposit/withdrawal/profit updates.
  },
);
