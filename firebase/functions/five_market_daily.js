/**
 * Five-market daily: EOD snapshots, scheduled credits, admin callables.
 * Phase 2 — additive; see docs/five_market_schema.md.
 */

"use strict";

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");
const { recalculateWallet, appendAudit } = require("./wallet_helpers");

function db() {
  return admin.firestore();
}

const REGION = "us-central1";

async function assertAdmin(uid) {
  const authUser = await admin.auth().getUser(uid);
  const claimAdmin =
    authUser.customClaims?.admin === true ||
    authUser.customClaims?.role === "admin";
  if (claimAdmin) return;

  const u = await db().collection("users").doc(uid).get();
  const role = (u.data()?.role || "").toLowerCase();
  if (role !== "admin") {
    throw new HttpsError("permission-denied", "Admin only.");
  }
}

async function safeAppendAudit(...args) {
  try {
    await appendAudit(...args);
  } catch (e) {
    logger.error("audit_log_failed", { error: String(e), args });
  }
}

/**
 * Resolves whether a given date (yyyy-MM-dd PKT string) is a trading day
 * for daily profit disbursement.
 *
 * Resolution order:
 * 1. If five_market_day_overrides/{date}.forceOpenDailyProfits = true → OPEN
 * 2. If five_market_day_overrides/{date}.forceClosedAll = true → CLOSED
 * 3. If Saturday or Sunday → CLOSED
 * 4. If date is in pakistan_holidays.holidays array → CLOSED
 * 5. Otherwise → OPEN
 *
 * Returns: { isTradingDay: bool, source: "forceOpen"|"forceClosed"|"weekend"|"holiday"|"calendar" }
 */
async function resolveTradingDay(datePkt) {
  const overrideSnap = await db()
    .collection("settings")
    .doc("five_market")
    .collection("five_market_day_overrides")
    .doc(datePkt)
    .get();

  if (overrideSnap.exists) {
    const o = overrideSnap.data();
    if (o.forceOpenDailyProfits === true) {
      return { isTradingDay: true, source: "forceOpen" };
    }
    if (o.forceClosedAll === true) {
      return { isTradingDay: false, source: "forceClosed" };
    }
  }

  const noonPkt = new Date(`${datePkt}T12:00:00+05:00`);
  const dow = noonPkt.getUTCDay();
  if (dow === 0 || dow === 6) {
    return { isTradingDay: false, source: "weekend" };
  }

  const holSnap = await db().collection("settings").doc("pakistan_holidays").get();
  const holidays = holSnap.exists
    ? (holSnap.data().holidays || []).map((h) => h && h.date).filter(Boolean)
    : [];
  if (holidays.includes(datePkt)) {
    return { isTradingDay: false, source: "holiday" };
  }

  return { isTradingDay: true, source: "calendar" };
}

/** yyyy-MM-dd in Asia/Karachi for [offsetDays] from today in that calendar. */
function getPktDateString(offsetDays = 0) {
  const cur = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Karachi",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  if (!offsetDays) return cur;
  const [y, mo, da] = cur.split("-").map(Number);
  const t = Date.UTC(y, mo - 1, da + offsetDays, 12, 0, 0);
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Karachi",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date(t));
}

/**
 * Fetches KMI30 daily bar from psxterminal.com/api/klines/KMI30/1d
 * Returns { closingValue, openingValue, high, low, volume,
 *           changeAbsolute, changePercent } or null on failure.
 * change* use **previous bar close** vs last close when two bars exist (PSX-style);
 * with one bar, uses session open as baseline (matches Flutter `fetchIndexTick`).
 */
async function fetchKmi30Eod() {
  try {
    const url = "https://psxterminal.com/api/klines/KMI30/1d?limit=2";
    const res = await fetch(url, {
      headers: { "User-Agent": "ISC-WAI-Server/1.0" },
      signal: AbortSignal.timeout(15000),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();

    const rawBars = Array.isArray(data) ? data : data.data || data.bars || [];
    if (!rawBars.length) return null;

    /** @param {unknown} bar */
    const normBar = (bar) => {
      if (Array.isArray(bar)) {
        return {
          t: Number(bar[0] ?? 0),
          open: Number(bar[1] ?? 0),
          high: Number(bar[2] ?? 0),
          low: Number(bar[3] ?? 0),
          close: Number(bar[4] ?? 0),
          vol: Number(bar[5] ?? 0),
        };
      }
      const o = bar && typeof bar === "object" ? bar : {};
      return {
        t: Number(o.timestamp ?? o.time ?? o.t ?? 0),
        open: Number(o.open ?? 0),
        high: Number(o.high ?? 0),
        low: Number(o.low ?? 0),
        close: Number(o.close ?? 0),
        vol: Number(o.volume ?? 0),
      };
    };

    const norm = rawBars.map(normBar).sort((a, b) => a.t - b.t);
    const today = norm[norm.length - 1];
    if (!today.close) return null;

    const usesPriorClose = norm.length >= 2;
    const baseline = usesPriorClose
      ? norm[norm.length - 2].close
      : today.open;
    if (!baseline) return null;

    const changeAbsolute = parseFloat((today.close - baseline).toFixed(2));
    const changePercent = parseFloat(
      ((changeAbsolute / baseline) * 100).toFixed(4),
    );

    return {
      closingValue: today.close,
      openingValue: today.open,
      high: today.high,
      low: today.low,
      volume: today.vol,
      changeAbsolute,
      changePercent,
    };
  } catch (e) {
    logger.warn("fetchKmi30Eod_failed", { error: String(e) });
    return null;
  }
}

/**
 * Optional metals.dev API key (uses monthly quota — only used if free feeds fail).
 * @see getGoldApiKey
 */
function getGoldApiKey() {
  const fromEnv = process.env.GOLD_API_KEY;
  if (fromEnv && String(fromEnv).trim()) return String(fromEnv).trim();
  try {
    const raw = process.env.CLOUD_RUNTIME_CONFIG;
    if (!raw) return "";
    const parsed = JSON.parse(raw);
    const k = parsed.gold && parsed.gold.api_key;
    return k ? String(k).trim() : "";
  } catch {
    return "";
  }
}

const _httpHeaders = { "User-Agent": "ISC-WAI-Server/1.0 (Wakalat; gold EOD)" };

/** USD→PKR from free public APIs (same idea as Flutter GoldPriceRepository). */
async function fetchUsdPkrFree() {
  try {
    const res = await fetch("https://open.er-api.com/v6/latest/USD", {
      headers: _httpHeaders,
      signal: AbortSignal.timeout(10000),
    });
    if (res.ok) {
      const j = await res.json();
      const pkr = j?.conversion_rates?.PKR;
      const n = Number(pkr);
      if (n > 0) return n;
    }
  } catch (_) {}
  try {
    const res = await fetch(
      "https://latest.currency-api.pages.dev/v1/currencies/usd.json",
      { headers: _httpHeaders, signal: AbortSignal.timeout(10000) },
    );
    if (res.ok) {
      const j = await res.json();
      const pkr = j?.usd?.pkr;
      const n = Number(pkr);
      if (n > 0) return n;
    }
  } catch (_) {}
  return null;
}

/**
 * XAU/PAXG as USD per troy oz from free currency-api `usd` map (same scales as Flutter).
 */
function xauUsdFromFreeUsdMap(usdMap) {
  if (!usdMap || typeof usdMap !== "object") return null;
  const raw = Number(usdMap.xau ?? usdMap.paxg);
  if (!Number.isFinite(raw) || raw <= 0) return null;
  if (raw >= 500 && raw <= 30000) return raw;
  if (raw < 0.02) return 1.0 / raw;
  return null;
}

/**
 * Gold EOD: **no API key** by default.
 * 1) Binance PAXGUSDT 1d klines (open→close %, spot in USD) × free USD/PKR.
 * 2) Free currency-api USD table (PKR + XAU) — price only; % from open/close unavailable → 0.
 * 3) Optional metals.dev only if a key is configured and (1)(2) failed.
 */
async function fetchGoldEod() {
  try {
    const usdPkrBinance = await fetchUsdPkrFree();
    if (usdPkrBinance) {
      const kRes = await fetch(
        "https://api.binance.com/api/v3/klines?symbol=PAXGUSDT&interval=1d&limit=2",
        { headers: _httpHeaders, signal: AbortSignal.timeout(12000) },
      );
      if (kRes.ok) {
        const klines = await kRes.json();
        if (Array.isArray(klines) && klines.length >= 1) {
          const bar = klines[klines.length - 1];
          const open = Number(bar[1]);
          const high = Number(bar[2]);
          const low = Number(bar[3]);
          const close = Number(bar[4]);
          if (open > 0 && close > 0) {
            const changePercent = parseFloat(
              (((close - open) / open) * 100).toFixed(4),
            );
            return {
              closingPricePkr: parseFloat((close * usdPkrBinance).toFixed(2)),
              openingPricePkr: parseFloat((open * usdPkrBinance).toFixed(2)),
              changePercent,
              source: "binance_paxg_1d+free_fx",
            };
          }
        }
      }
    }

    try {
      const res = await fetch(
        "https://latest.currency-api.pages.dev/v1/currencies/usd.json",
        { headers: _httpHeaders, signal: AbortSignal.timeout(12000) },
      );
      if (res.ok) {
        const j = await res.json();
        const usd = j?.usd;
        const pkr = usd && Number(usd.pkr);
        const xauUsd = xauUsdFromFreeUsdMap(usd);
        if (pkr > 0 && xauUsd) {
          const closeUsd = xauUsd;
          return {
            closingPricePkr: parseFloat((closeUsd * pkr).toFixed(2)),
            openingPricePkr: null,
            changePercent: 0,
            source: "currency-api.pages.dev (free)",
          };
        }
      }
    } catch (_) {}

    const apiKey = getGoldApiKey();
    if (apiKey) {
      const mRes = await fetch(
        `https://metals.dev/api/latest?api_key=${encodeURIComponent(apiKey)}&currency=PKR&unit=toz`,
        { signal: AbortSignal.timeout(10000) },
      );
      if (mRes.ok) {
        const data = await mRes.json();
        const price = data?.metals?.gold;
        if (price && Number(price) > 0) {
          return {
            closingPricePkr: Number(price),
            openingPricePkr: null,
            changePercent: null,
            source: "metals.dev (fallback)",
          };
        }
      }
    }

    return null;
  } catch (e) {
    logger.warn("fetchGoldEod_failed", { error: String(e) });
    return null;
  }
}

/**
 * Calculates five-market daily profit breakdown for a user.
 * Returns per-market PKR amounts and total.
 */
function calculateDailyProfit({ basePkr, config, eodSnap }) {
  const alloc = config.allocations || {};
  const rates = config.rates || {};

  const stockPct = (alloc.stock || 0) / 100;
  const techPct = (alloc.tech || 0) / 100;
  const debtPct = (alloc.debt || 0) / 100;
  const moneyPct = (alloc.money || 0) / 100;
  const goldPct = (alloc.gold || 0) / 100;

  const stockAllocated = basePkr * stockPct;
  const techAllocated = basePkr * techPct;
  const debtAllocated = basePkr * debtPct;
  const moneyAllocated = basePkr * moneyPct;
  const goldAllocated = basePkr * goldPct;

  const kmi = eodSnap && eodSnap.kmi30 && typeof eodSnap.kmi30 === "object" && !eodSnap.kmi30.error
    ? eodSnap.kmi30
    : {};
  const kmi30Change = Number(kmi.changePercent) || 0;
  const stockProfit = parseFloat(
    (stockAllocated * (kmi30Change / 100)).toFixed(2),
  );

  const techBenchmark = rates.techBenchmarkAnnualPercent || 0;
  const techProfit = parseFloat(
    (techAllocated * (techBenchmark / 100) / 365).toFixed(2),
  );

  const debtAnnual = rates.debtAnnualPercent || 0;
  const debtProfit = parseFloat(
    (debtAllocated * (debtAnnual / 100) / 365).toFixed(2),
  );

  const moneyAnnual = rates.moneyAnnualPercent || 0;
  const moneyProfit = parseFloat(
    (moneyAllocated * (moneyAnnual / 100) / 365).toFixed(2),
  );

  const g = eodSnap && eodSnap.gold && typeof eodSnap.gold === "object" && !eodSnap.gold.error
    ? eodSnap.gold
    : {};
  const goldChange = g.changePercent != null ? Number(g.changePercent) : 0;
  const goldProfit = parseFloat(
    (goldAllocated * (goldChange / 100)).toFixed(2),
  );

  const totalProfit = parseFloat(
    (stockProfit + techProfit + debtProfit + moneyProfit + goldProfit).toFixed(2),
  );

  return {
    markets: {
      stock: {
        allocatedPkr: parseFloat(stockAllocated.toFixed(2)),
        changePercent: kmi30Change,
        profitPkr: stockProfit,
        status: kmi30Change !== 0 ? "REALIZED" : "CLOSED",
      },
      tech: {
        allocatedPkr: parseFloat(techAllocated.toFixed(2)),
        annualPercent: techBenchmark,
        profitPkr: techProfit,
        status: "REALIZED",
      },
      debt: {
        allocatedPkr: parseFloat(debtAllocated.toFixed(2)),
        annualPercent: debtAnnual,
        profitPkr: debtProfit,
        status: "REALIZED",
      },
      money: {
        allocatedPkr: parseFloat(moneyAllocated.toFixed(2)),
        annualPercent: moneyAnnual,
        profitPkr: moneyProfit,
        status: "REALIZED",
      },
      gold: {
        allocatedPkr: parseFloat(goldAllocated.toFixed(2)),
        changePercent: goldChange,
        profitPkr: goldProfit,
        status: goldChange !== 0 ? "REALIZED" : "CLOSED",
      },
    },
    totalProfitPkr: totalProfit,
  };
}

exports.fiveMarketEodSnapshot = onSchedule(
  {
    schedule: "5 16 * * 1-5",
    timeZone: "Asia/Karachi",
    region: REGION,
    memory: "256MiB",
  },
  async () => {
    const datePkt = getPktDateString(0);
    logger.info("fiveMarketEodSnapshot_start", { datePkt });

    const { isTradingDay, source } = await resolveTradingDay(datePkt);

    if (!isTradingDay) {
      logger.info("fiveMarketEodSnapshot_skipped_nontrading", { datePkt, source });
      await db()
        .collection("investment_daily_market_close")
        .doc(datePkt)
        .set({
          date: datePkt,
          tradingDay: false,
          effectiveDaySource: source,
          snapshotAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      return;
    }

    const [kmi30, gold] = await Promise.all([fetchKmi30Eod(), fetchGoldEod()]);

    const doc = {
      date: datePkt,
      tradingDay: true,
      effectiveDaySource: source,
      snapshotAt: admin.firestore.FieldValue.serverTimestamp(),
      kmi30: kmi30 || { error: "fetch_failed" },
      gold: gold || { error: "fetch_failed" },
    };

    await db().collection("investment_daily_market_close").doc(datePkt).set(doc);

    logger.info("fiveMarketEodSnapshot_done", {
      datePkt,
      kmi30Ok: !!kmi30,
      goldOk: !!gold,
    });
  },
);

exports.fiveMarketDailyCredit = onSchedule(
  {
    schedule: "5 0 * * *",
    timeZone: "Asia/Karachi",
    region: REGION,
    memory: "512MiB",
    timeoutSeconds: 540,
  },
  async () => {
    const datePkt = getPktDateString(-1);
    logger.info("fiveMarketDailyCredit_start", { datePkt });

    const { isTradingDay, source } = await resolveTradingDay(datePkt);
    if (!isTradingDay) {
      logger.info("fiveMarketDailyCredit_skipped_nontrading", { datePkt, source });
      return;
    }

    const eodSnap = await db()
      .collection("investment_daily_market_close")
      .doc(datePkt)
      .get();

    if (!eodSnap.exists) {
      logger.warn("fiveMarketDailyCredit_no_eod_snapshot", { datePkt });
      return;
    }

    const eodData = eodSnap.data();
    if (!eodData.tradingDay) {
      logger.info("fiveMarketDailyCredit_eod_marked_nontrading", { datePkt });
      return;
    }

    const configSnap = await db().collection("settings").doc("five_market_calc").get();

    if (!configSnap.exists) {
      logger.error("fiveMarketDailyCredit_no_config", { datePkt });
      return;
    }
    const config = configSnap.data();

    const portfoliosSnap = await db()
      .collection("portfolios")
      .where("fiveMarketDailyLedger", "==", true)
      .get();

    if (portfoliosSnap.empty) {
      logger.info("fiveMarketDailyCredit_no_opted_in_portfolios", { datePkt });
      return;
    }

    logger.info("fiveMarketDailyCredit_processing", {
      datePkt,
      count: portfoliosSnap.size,
    });

    const results = { success: 0, skipped: 0, failed: 0 };

    for (const portfolioDoc of portfoliosSnap.docs) {
      const uid = portfolioDoc.id;
      try {
        const existingCredit = await db()
          .collection("portfolios")
          .doc(uid)
          .collection("five_market_daily")
          .doc(datePkt)
          .get();

        if (existingCredit.exists && existingCredit.data().creditedToWallet) {
          logger.info("fiveMarketDailyCredit_already_credited", { uid, datePkt });
          results.skipped++;
          continue;
        }

        const walletSnap = await db().collection("wallets").doc(uid).get();

        if (!walletSnap.exists) {
          logger.warn("fiveMarketDailyCredit_no_wallet", { uid, datePkt });
          results.skipped++;
          continue;
        }

        const wallet = walletSnap.data();
        const basePkr = parseFloat(
          (
            (Number(wallet.totalDeposited) || 0) +
            (Number(wallet.totalProfit) || 0) +
            (Number(wallet.totalAdjustments) || 0) -
            (Number(wallet.totalWithdrawn) || 0)
          ).toFixed(2),
        );

        if (basePkr <= 0) {
          logger.info("fiveMarketDailyCredit_zero_base", { uid, datePkt });
          results.skipped++;
          continue;
        }

        const { markets, totalProfitPkr } = calculateDailyProfit({
          basePkr,
          config,
          eodSnap: eodData,
        });

        const now = admin.firestore.FieldValue.serverTimestamp();

        const dailyRef = db()
          .collection("portfolios")
          .doc(uid)
          .collection("five_market_daily")
          .doc(datePkt);

        await dailyRef.set({
          date: datePkt,
          basePkr,
          tradingDay: true,
          markets,
          totalProfitPkr,
          creditedToWallet: false,
          effectiveDaySource: source,
          notes: `Five-market daily profit ${datePkt}`,
          createdAt: now,
        });

        if (totalProfitPkr !== 0) {
          const txRef = db().collection("transactions").doc();
          const batch = db().batch();

          batch.set(txRef, {
            id: txRef.id,
            userId: uid,
            type: "profit_entry",
            status: "approved",
            amount: totalProfitPkr,
            notes: `Five-market daily profit ${datePkt}`,
            metadata: {
              periodKey: datePkt,
              source: "five_market_daily",
              markets,
            },
            createdAt: now,
            updatedAt: now,
            approvedBy: "system_five_market_daily",
          });

          batch.update(dailyRef, {
            creditedToWallet: true,
            creditedAt: now,
            transactionId: txRef.id,
          });

          await batch.commit();

          await recalculateWallet(uid);
        } else {
          await dailyRef.update({
            creditedToWallet: true,
            creditedAt: now,
          });
        }

        results.success++;
        logger.info("fiveMarketDailyCredit_user_done", {
          uid,
          datePkt,
          totalProfitPkr,
        });
      } catch (e) {
        results.failed++;
        logger.error("fiveMarketDailyCredit_user_failed", {
          uid,
          datePkt,
          error: String(e),
        });
      }
    }

    logger.info("fiveMarketDailyCredit_complete", { datePkt, results });
  },
);

exports.saveFiveMarketConfig = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in required.");
  await assertAdmin(request.auth.uid);

  const { allocations, rates } = request.data || {};

  if (allocations) {
    const sum = Object.values(allocations).reduce(
      (a, b) => a + Number(b),
      0,
    );
    if (Math.abs(sum - 100) > 0.01) {
      throw new HttpsError("invalid-argument", "Allocations must sum to 100.");
    }
  }

  const existing = await db().collection("settings").doc("five_market_calc").get();
  const oldData = existing.exists ? existing.data() : {};

  await db()
    .collection("settings")
    .doc("five_market_calc")
    .set(
      {
        ...(allocations && { allocations }),
        ...(rates && { rates }),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: request.auth.uid,
      },
      { merge: true },
    );

  await safeAppendAudit(
    request.auth.uid,
    "admin",
    "saveFiveMarketConfig",
    "settings",
    "five_market_calc",
    { rates: oldData.rates, allocations: oldData.allocations },
    { rates, allocations },
  );

  return { ok: true };
});

exports.saveFiveMarketDayOverride = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in required.");
  await assertAdmin(request.auth.uid);

  const { date, forceClosedAll, forceOpenDailyProfits, reason } = request.data || {};

  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new HttpsError("invalid-argument", "date must be yyyy-MM-dd.");
  }
  if (forceClosedAll === true && forceOpenDailyProfits === true) {
    throw new HttpsError(
      "invalid-argument",
      "forceClosedAll and forceOpenDailyProfits are mutually exclusive.",
    );
  }
  if (!reason || !String(reason).trim()) {
    throw new HttpsError("invalid-argument", "reason is required for day overrides.");
  }

  const ref = db()
    .collection("settings")
    .doc("five_market")
    .collection("five_market_day_overrides")
    .doc(date);

  const existing = await ref.get();
  const oldData = existing.exists ? existing.data() : null;

  const explicitClear =
    forceClosedAll === false && forceOpenDailyProfits === false;
  const hasTrueFlag =
    forceClosedAll === true || forceOpenDailyProfits === true;

  if (explicitClear) {
    await ref.delete();
    await safeAppendAudit(
      request.auth.uid,
      "admin",
      "saveFiveMarketDayOverride",
      "five_market_day_overrides",
      date,
      oldData,
      null,
    );
  } else if (hasTrueFlag) {
    await ref.set({
      date,
      forceClosedAll: forceClosedAll === true,
      forceOpenDailyProfits: forceOpenDailyProfits === true,
      reason: String(reason).trim(),
      createdBy: request.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await safeAppendAudit(
      request.auth.uid,
      "admin",
      "saveFiveMarketDayOverride",
      "five_market_day_overrides",
      date,
      oldData,
      { date, forceClosedAll, forceOpenDailyProfits, reason },
    );
  } else {
    throw new HttpsError(
      "invalid-argument",
      "Set forceClosedAll or forceOpenDailyProfits to true, or both to false to remove an override.",
    );
  }

  return { ok: true };
});

exports.setFiveMarketDailyLedger = onCall({ region: REGION }, async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in required.");
  await assertAdmin(request.auth.uid);

  const { userId, enabled } = request.data || {};
  if (!userId) throw new HttpsError("invalid-argument", "userId required.");
  if (typeof enabled !== "boolean") {
    throw new HttpsError("invalid-argument", "enabled must be boolean.");
  }

  const prevSnap = await db().collection("portfolios").doc(userId).get();
  const beforeLedger = prevSnap.exists
    ? prevSnap.data().fiveMarketDailyLedger
    : undefined;

  await db()
    .collection("portfolios")
    .doc(userId)
    .set({ fiveMarketDailyLedger: enabled }, { merge: true });

  await safeAppendAudit(
    request.auth.uid,
    "admin",
    "setFiveMarketDailyLedger",
    "portfolios",
    userId,
    { fiveMarketDailyLedger: beforeLedger === true },
    { fiveMarketDailyLedger: enabled },
  );

  return { ok: true };
});
