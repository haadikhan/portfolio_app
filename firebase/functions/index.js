/**
 * Firebase Cloud Functions — Wakalat Invest
 */

// Lower the per-function default CPU from 1 to 0.5 to stay under the
// us-central1 Cloud Run regional CPU quota during rolling deploys.
// Per-function overrides (cpu: 0.08 / 0.25 / 0.5) take priority over this.
const { setGlobalOptions } = require("firebase-functions/v2");
setGlobalOptions({
  region: "us-central1",
  cpu: 0.5,
  memory: "256MiB",
});

const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const { recalculateWallet } = require("./wallet_helpers");
const {
  notifyAllAdmins,
  sendCustomerTransactionAlerts,
} = require("./notifications");

const walletLedger = require("./wallet_ledger");
const notifications = require("./notifications");
const marketData = require("./market_data");
const appUpdates = require("./app_updates");
const mpin = require("./mpin");
const fees = require("./fees");
const otpSecurity = require("./otp_security");
Object.assign(exports, walletLedger);
Object.assign(exports, notifications);
Object.assign(exports, marketData);
Object.assign(exports, appUpdates);
Object.assign(exports, mpin);
exports.verifyMpin = mpin.verifyMpin;
Object.assign(exports, otpSecurity);
// Only expose public callables / scheduled functions; module-private helpers
// (getFeeConfig_internal, applyDepositFees, ...) are NOT re-exported.
exports.getFeeConfig = fees.getFeeConfig;
exports.saveFeeConfig = fees.saveFeeConfig;
exports.sendMonthlyFeeStatements = fees.sendMonthlyFeeStatements;
exports.applyMonthEndFeeStatements = fees.applyMonthEndFeeStatements;

exports.onKycSubmittedForReview = onDocumentUpdated(
  {
    document: "kyc/{userId}",
    region: "us-central1",
    memory: "256MiB",
    cpu: 0.08,
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

exports.onKycApproved = onDocumentUpdated(
  {
    document: "kyc/{userId}",
    region: "us-central1",
    memory: "256MiB",
    cpu: 0.08,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;

    const beforeStatus = (before?.status || "").toLowerCase();
    const afterStatus = (after.status || "").toLowerCase();

    if (afterStatus !== "approved" || beforeStatus === "approved") {
      return;
    }

    const uid = event.params.userId;
    try {
      await sendCustomerTransactionAlerts(uid, {
        title: "KYC Approved",
        body: "Congratulations! Your KYC verification has been approved.",
        type: "kyc",
        category: "kyc",
        action: "open_kyc",
        refId: uid,
        amount: null,
        currency: "PKR",
      });
    } catch (e) {
      logger.warn("onKycApproved_notify_failed", { uid, error: String(e) });
    }
  },
);

exports.onKycRejected = onDocumentUpdated(
  {
    document: "kyc/{userId}",
    region: "us-central1",
    memory: "256MiB",
    cpu: 0.08,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;

    const beforeStatus = (before?.status || "").toLowerCase();
    const afterStatus = (after.status || "").toLowerCase();

    if (afterStatus !== "rejected" || beforeStatus === "rejected") {
      return;
    }

    const uid = event.params.userId;
    const reason = after.rejectionReason || "Please contact support.";
    try {
      await sendCustomerTransactionAlerts(uid, {
        title: "KYC Not Approved",
        body: `Your KYC verification was not approved. ${reason}`,
        type: "kyc",
        category: "kyc",
        action: "open_kyc",
        refId: uid,
        amount: null,
        currency: "PKR",
      });
    } catch (e) {
      logger.warn("onKycRejected_notify_failed", { uid, error: String(e) });
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

// ── Five-market daily feature (Phase 2) ──────────────────────────
const fiveMarketDaily = require("./five_market_daily");
exports.fiveMarketEodSnapshot = fiveMarketDaily.fiveMarketEodSnapshot;
exports.fiveMarketDailyCredit = fiveMarketDaily.fiveMarketDailyCredit;
exports.saveFiveMarketConfig = fiveMarketDaily.saveFiveMarketConfig;
exports.saveFiveMarketDayOverride = fiveMarketDaily.saveFiveMarketDayOverride;
exports.setFiveMarketDailyLedger = fiveMarketDaily.setFiveMarketDailyLedger;

// ── Fee System v2 — Daily Management Fee (Phase 3) ───────────
const mgmtFeeDaily = require("./management_fee_daily");
exports.applyDailyManagementFeeJob = mgmtFeeDaily.applyDailyManagementFeeJob;
exports.resetYtdManagementFee = mgmtFeeDaily.resetYtdManagementFee;

// ── Fee System v2 — Daily Performance Fee (Phase 4) ──────────
const perfFeeDaily = require("./performance_fee_daily");
exports.applyDailyPerformanceFeeJob = perfFeeDaily.applyDailyPerformanceFeeJob;
