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

    // Default ON: every wallet holder is eligible unless portfolios/{uid}
    // explicitly sets fiveMarketDailyLedger === false.
    const walletsSnap = await db().collection("wallets").get();

    if (walletsSnap.empty) {
      logger.info("fiveMarketDailyCredit_no_wallets", { datePkt });
      return;
    }

    logger.info("fiveMarketDailyCredit_processing", {
      datePkt,
      count: walletsSnap.size,
    });

    const results = { success: 0, skipped: 0, failed: 0 };

    for (const walletDoc of walletsSnap.docs) {
      const uid = walletDoc.id;
      try {
        const portfolioSnap = await db().collection("portfolios").doc(uid).get();
        if (
          portfolioSnap.exists &&
          portfolioSnap.data().fiveMarketDailyLedger === false
        ) {
          results.skipped++;
          continue;
        }

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

        const wallet = walletDoc.data();
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
  const wasEnabled = beforeLedger !== false;

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
    { fiveMarketDailyLedger: wasEnabled },
    { fiveMarketDailyLedger: enabled },
  );

  return { ok: true };
});

exports.adminAutoBackfillInvestor = onCall(
  { region: REGION, timeoutSeconds: 540, memory: "512MiB" },
  async (request) => {
    if (!request.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    await assertAdmin(request.auth.uid);

    const { userId, depositDate, depositAmount, deposits: depositsRaw, dryRun = false } =
      request.data || {};

    if (!userId || typeof userId !== "string" || !userId.trim())
      throw new HttpsError("invalid-argument", "userId required.");
    const uid = userId.trim();

    // Support both single-deposit (old) and multi-deposit (new) formats.
    let deposits;
    if (Array.isArray(depositsRaw) && depositsRaw.length > 0) {
      deposits = depositsRaw
        .map((d) => ({
          date: String(d.date || "").trim(),
          amount: Number(d.amount),
        }))
        .filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d.date) && d.amount > 0)
        .sort((a, b) => a.date.localeCompare(b.date));
      if (!deposits.length)
        throw new HttpsError("invalid-argument", "No valid deposits provided.");
    } else if (depositDate && depositAmount) {
      // Backward-compatible single deposit
      deposits = [{ date: String(depositDate).trim(), amount: Number(depositAmount) }];
    } else {
      throw new HttpsError("invalid-argument", "Provide deposits array or depositDate+depositAmount.");
    }

    const firstDeposit = deposits[0];
    const firstDepositDateObj = new Date(firstDeposit.date + "T00:00:00.000Z");
    if (isNaN(firstDepositDateObj.getTime()))
      throw new HttpsError("invalid-argument", "Invalid first deposit date.");

    const todayPkt = getPktDateString(0);
    const todayPktDate = new Date(todayPkt + "T00:00:00.000Z");
    if (firstDepositDateObj >= todayPktDate)
      throw new HttpsError("invalid-argument", "First deposit date must be before today.");

    for (const d of deposits) {
      const parsed = new Date(d.date + "T00:00:00.000Z");
      if (parsed >= todayPktDate)
        throw new HttpsError("invalid-argument", `Deposit date ${d.date} must be before today.`);
      if (!isFinite(d.amount) || d.amount <= 0)
        throw new HttpsError("invalid-argument", `Deposit amount for ${d.date} must be positive.`);
    }

    const totalAmount = deposits.reduce((s, d) => s + d.amount, 0);

    // Build a lookup: date string → deposit amount for that date
    const depositByDate = {};
    for (const d of deposits) {
      depositByDate[d.date] = (depositByDate[d.date] || 0) + d.amount;
    }

    const adminUid = request.auth.uid;
    const now = admin.firestore.FieldValue.serverTimestamp();

    // ── Load config ────────────────────────────────────────────────────────
    const [configSnap, holSnap, feeConfigSnap] = await Promise.all([
      db().collection("settings").doc("five_market_calc").get(),
      db().collection("settings").doc("pakistan_holidays").get(),
      db().collection("settings").doc("fee_config").get(),
    ]);

    const config =
      configSnap.exists && configSnap.data()
        ? configSnap.data()
        : { allocations: {}, rates: {} };

    const holidays = holSnap.exists
      ? (holSnap.data().holidays || []).map((h) => h && h.date).filter(Boolean)
      : [];

    const feeConfig = feeConfigSnap.exists ? feeConfigSnap.data() : {};
    const feesEnabled = feeConfig.isEnabled === true;
    const perfFeePct = feesEnabled
      ? Number(feeConfig.performanceFeePct) || 0
      : 0;
    // Annual management fee % (field may be stored as either name)
    const mgmtFeePctAnnual = feesEnabled
      ? (Number(feeConfig.managementFeePctAnnual) || Number(feeConfig.managementFeeAnnualPct) || 0)
      : 0;
    // Front-end load % charged once per deposit
    const frontEndLoadPct = feesEnabled
      ? (Number(feeConfig.frontEndLoadPct) || 0)
      : 0;

    // Build a lookup: date string → front-end load fee for deposits on that date
    // (must run AFTER frontEndLoadPct is resolved from fee_config)
    const frontEndLoadByDate = {};
    let totalFrontEndLoad = 0;
    if (frontEndLoadPct > 0) {
      for (const d of deposits) {
        const fee = parseFloat((d.amount * frontEndLoadPct / 100).toFixed(2));
        if (fee > 0) {
          frontEndLoadByDate[d.date] = (frontEndLoadByDate[d.date] || 0) + fee;
          totalFrontEndLoad = parseFloat((totalFrontEndLoad + fee).toFixed(2));
        }
      }
    }

    // ── Load all EOD snapshots from depositDate to yesterday ───────────────
    const yesterdayPkt = getPktDateString(-1);
    const eodSnaps = await db()
      .collection("investment_daily_market_close")
      .where("date", ">=", firstDeposit.date)
      .where("date", "<=", yesterdayPkt)
      .get();

    const eodMap = {};
    for (const doc of eodSnaps.docs) {
      eodMap[doc.id] = doc.data();
    }

    // ── Helper: convert a timestamp to PKT date string ─────────────────────
    function tsToPktDate(ts) {
      // Detect ms vs seconds by magnitude (ms > 1e12)
      const d = ts > 1e12 ? new Date(ts) : new Date(ts * 1000);
      return new Intl.DateTimeFormat("en-CA", {
        timeZone: "Asia/Karachi",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
      }).format(d);
    }

    // ── Fetch historical KMI30 % changes as fallback for missing/errored EOD ─
    // Source order: PSX Terminal (most accurate) → Yahoo Finance → empty map.
    const historicalKmi30Map = await (async () => {
      // ── Source 1: PSX Terminal historical (same API as live EOD snapshot) ──
      try {
        const res = await fetch(
          "https://psxterminal.com/api/klines/KMI30/1d?limit=730",
          { headers: { "User-Agent": "ISC-WAI-Server/1.0" }, signal: AbortSignal.timeout(25000) },
        );
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        const rawBars = Array.isArray(data) ? data : data.data || data.bars || [];
        if (rawBars.length < 2) throw new Error("Insufficient data");

        const parsed = rawBars.map((bar) => {
          if (Array.isArray(bar)) {
            return { t: Number(bar[0] ?? 0), close: Number(bar[4] ?? 0) };
          }
          const o = bar && typeof bar === "object" ? bar : {};
          return {
            t: Number(o.timestamp ?? o.time ?? o.t ?? 0),
            close: Number(o.close ?? 0),
          };
        }).filter((b) => b.t > 0 && b.close > 0).sort((a, b) => a.t - b.t);

        if (parsed.length < 2) throw new Error("No valid bars");

        const map = {};
        for (let i = 1; i < parsed.length; i++) {
          const prev = parsed[i - 1].close;
          const curr = parsed[i].close;
          if (!prev || !curr) continue;
          const pktDate = tsToPktDate(parsed[i].t);
          if (pktDate >= firstDeposit.date && pktDate <= yesterdayPkt) {
            map[pktDate] = parseFloat((((curr - prev) / prev) * 100).toFixed(4));
          }
        }
        if (!Object.keys(map).length) throw new Error("No dates in range");
        logger.info("backfill_psx_kmi30_historical_ok", { dates: Object.keys(map).length });
        return map;
      } catch (e) {
        logger.warn("backfill_psx_kmi30_historical_failed", { error: String(e) });
      }

      // ── Source 2: Yahoo Finance Pakistan market indexes ──────────────────
      async function tryYahooTicker(ticker) {
        const url =
          `https://query1.finance.yahoo.com/v8/finance/chart/${ticker}` +
          `?interval=1d&range=2y`;
        const res = await fetch(url, {
          headers: {
            "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
              "AppleWebKit/537.36 (KHTML, like Gecko) " +
              "Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json",
            "Accept-Language": "en-US,en;q=0.9",
          },
          signal: AbortSignal.timeout(20000),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const json = await res.json();
        const result = json?.chart?.result?.[0];
        if (!result) throw new Error("No chart result");
        const timestamps = result.timestamp || [];
        const closes = result.indicators?.quote?.[0]?.close || [];
        if (timestamps.length < 2) throw new Error("Insufficient data");

        const map = {};
        for (let i = 1; i < timestamps.length; i++) {
          const prev = closes[i - 1];
          const curr = closes[i];
          if (!prev || !curr || isNaN(prev) || isNaN(curr)) continue;
          const pktDate = tsToPktDate(timestamps[i]);  // Yahoo uses seconds
          if (pktDate >= firstDeposit.date && pktDate <= yesterdayPkt) {
            map[pktDate] = parseFloat((((curr - prev) / prev) * 100).toFixed(4));
          }
        }
        if (!Object.keys(map).length) throw new Error("No dates in range");
        return map;
      }

      const tickers = [
        "%5EKSE",    // ^KSE  — KSE100
        "%5EPKOL",   // ^PKOL — alternate Pakistan index
        "%5EKSEI",   // ^KSEI — KSE Meezan Index
      ];
      for (const ticker of tickers) {
        try {
          const map = await tryYahooTicker(ticker);
          logger.info("backfill_yahoo_kmi30_ok", { ticker, dates: Object.keys(map).length });
          return map;
        } catch (e) {
          logger.warn("backfill_yahoo_ticker_failed", { ticker, error: String(e) });
        }
      }

      logger.warn("backfill_kmi30_all_sources_failed");
      return {};
    })();

    // ── Fetch historical Gold % changes (Binance PAXGUSDT) ─────────────────
    // Used to supplement missing gold data for the same days KMI30 may be missing.
    const historicalGoldMap = await (async () => {
      try {
        const res = await fetch(
          "https://api.binance.com/api/v3/klines?symbol=PAXGUSDT&interval=1d&limit=730",
          { headers: { "User-Agent": "ISC-WAI-Server/1.0" }, signal: AbortSignal.timeout(20000) },
        );
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const klines = await res.json();
        if (!Array.isArray(klines) || klines.length < 2) throw new Error("Insufficient data");

        const map = {};
        for (let i = 1; i < klines.length; i++) {
          const prevClose = Number(klines[i - 1][4]);
          const currClose = Number(klines[i][4]);
          if (!prevClose || !currClose) continue;
          const pktDate = tsToPktDate(Number(klines[i][0])); // Binance uses ms
          if (pktDate >= firstDeposit.date && pktDate <= yesterdayPkt) {
            map[pktDate] = parseFloat((((currClose - prevClose) / prevClose) * 100).toFixed(4));
          }
        }
        if (!Object.keys(map).length) throw new Error("No dates in range");
        logger.info("backfill_gold_historical_ok", { dates: Object.keys(map).length });
        return map;
      } catch (e) {
        logger.warn("backfill_gold_historical_failed", { error: String(e) });
        return {};
      }
    })();

    // ── Simulate day-by-day, collecting daily and monthly results ──────────
    // runningBasePkr compounds daily (gross) and deducts monthly perf fee.
    let runningBasePkr = 0;   // starts at 0; each deposit adds to base on its date
    let currentDate = new Date(firstDeposit.date + "T00:00:00.000Z");
    const monthlyData = {};
    let missingEodDays = 0;
    let totalTradingDays = 0;

    while (currentDate < todayPktDate) {
      const dateStr = currentDate.toISOString().split("T")[0];
      const dow = currentDate.getUTCDay();
      const isWeekend = dow === 0 || dow === 6;
      const isHoliday = holidays.includes(dateStr);
      const isTradingDay = !isWeekend && !isHoliday;
      const monthKey = dateStr.substring(0, 7);

      if (!monthlyData[monthKey]) {
        monthlyData[monthKey] = {
          grossProfit: 0,
          tradingDays: 0,
          lastTradingDate: null,
          firstDate: dateStr,
          basePkrAtStart: parseFloat(runningBasePkr.toFixed(2)),
          dailyEntries: [],
        };
      }

      // Apply any deposit(s) that fall on this date
      if (depositByDate[dateStr]) {
        runningBasePkr += depositByDate[dateStr];
      }
      // Deduct front-end load on deposit dates (reduces the invested capital base)
      if (frontEndLoadByDate[dateStr]) {
        runningBasePkr -= frontEndLoadByDate[dateStr];
      }

      if (isTradingDay) {
        const eod = eodMap[dateStr];

        // Determine whether stored KMI30 data is valid (not errored/missing)
        const kmi30IsValid =
          eod &&
          eod.kmi30 &&
          typeof eod.kmi30 === "object" &&
          !eod.kmi30.error &&
          eod.kmi30.changePercent != null;

        if (!kmi30IsValid) missingEodDays++;

        // Build effective EOD: prefer stored data; supplement KMI30 from
        // Yahoo Finance historical map when stored data is missing or errored.
        let effectiveEod = eod || { tradingDay: true };
        let kmi30Source = kmi30IsValid
          ? eod.effectiveDaySource || "calendar"
          : "missing";

        if (!kmi30IsValid && historicalKmi30Map[dateStr] !== undefined) {
          effectiveEod = {
            ...effectiveEod,
            kmi30: { changePercent: historicalKmi30Map[dateStr] },
          };
          kmi30Source = "historical_proxy";
        }

        // Supplement missing gold data from Binance historical map
        const storedGoldValid =
          effectiveEod.gold &&
          typeof effectiveEod.gold === "object" &&
          !effectiveEod.gold.error &&
          effectiveEod.gold.changePercent != null;
        if (!storedGoldValid && historicalGoldMap[dateStr] !== undefined) {
          effectiveEod = {
            ...effectiveEod,
            gold: { changePercent: historicalGoldMap[dateStr] },
          };
        }

        const result = calculateDailyProfit({
          basePkr: runningBasePkr,
          config,
          eodSnap: effectiveEod,
        });
        const dailyPkr = parseFloat(result.totalProfitPkr.toFixed(2));

        monthlyData[monthKey].dailyEntries.push({
          date: dateStr,
          basePkr: parseFloat(runningBasePkr.toFixed(2)),
          markets: result.markets,
          totalProfitPkr: dailyPkr,
          eodSource: kmi30Source,
        });
        monthlyData[monthKey].grossProfit += dailyPkr;
        monthlyData[monthKey].tradingDays++;
        monthlyData[monthKey].lastTradingDate = dateStr;

        // Compound daily with GROSS profit (fees deducted monthly below)
        runningBasePkr += dailyPkr;
        totalTradingDays++;
      }

      currentDate = new Date(currentDate.getTime() + 24 * 60 * 60 * 1000);
    }

    // ── Build monthly summaries ────────────────────────────────────────────
    const months = Object.keys(monthlyData).sort();
    let totalGrossProfit = 0;
    let totalNetProfit = 0;
    let totalFees = 0;

    // Reset runningBasePkr to recompute with fee deductions per month.
    // Start after front-end load deductions (reflects actual invested capital).
    runningBasePkr = totalAmount - totalFrontEndLoad;
    // Seed total fees with the front-end loads already computed.
    totalFees = parseFloat(totalFrontEndLoad.toFixed(2));

    const monthResults = months.map((monthKey) => {
      const md = monthlyData[monthKey];
      const grossProfit = parseFloat(md.grossProfit.toFixed(2));
      const performanceFee =
        grossProfit > 0 && perfFeePct > 0
          ? parseFloat(((grossProfit * perfFeePct) / 100).toFixed(2))
          : 0;
      // Monthly management fee: annual rate ÷ 12, applied to opening portfolio value
      const managementFee =
        runningBasePkr > 0 && mgmtFeePctAnnual > 0
          ? parseFloat(((runningBasePkr * mgmtFeePctAnnual) / 100 / 12).toFixed(2))
          : 0;
      const totalMonthFees = parseFloat((performanceFee + managementFee).toFixed(2));
      const netProfit = parseFloat((grossProfit - totalMonthFees).toFixed(2));
      const returnPct =
        runningBasePkr > 0
          ? parseFloat(((grossProfit / runningBasePkr) * 100).toFixed(4))
          : 0;
      const previousValue = parseFloat(runningBasePkr.toFixed(2));

      totalGrossProfit += grossProfit;
      totalNetProfit += netProfit;
      totalFees += totalMonthFees;

      // Compound monthly NET (all fees deducted) for the preview
      runningBasePkr = runningBasePkr + grossProfit - totalMonthFees;

      return {
        monthKey,
        grossProfit,
        performanceFee,
        managementFee,
        netProfit,
        returnPct,
        previousValue,
        newValue: parseFloat(runningBasePkr.toFixed(2)),
        lastTradingDate: md.lastTradingDate,
        tradingDays: md.tradingDays,
        firstDate: md.firstDate,
      };
    });

    // ── DRY RUN: return preview without writing ────────────────────────────
    if (dryRun) {
      return {
        ok: true,
        dryRun: true,
        monthsProcessed: monthResults.length,
        tradingDaysProcessed: totalTradingDays,
        totalDeposited: totalAmount,
        totalFrontEndLoad: parseFloat(totalFrontEndLoad.toFixed(2)),
        totalGrossProfit: parseFloat(totalGrossProfit.toFixed(2)),
        totalNetProfit: parseFloat(totalNetProfit.toFixed(2)),
        totalFees: parseFloat(totalFees.toFixed(2)),
        missingEodDays,
        deposits: deposits.map((d) => ({ date: d.date, amount: d.amount })),
        months: monthResults,
      };
    }

    // ═══════════════════════════════════════════════════════════════════════
    // WRITE MODE
    // ═══════════════════════════════════════════════════════════════════════

    // ── Step 1: Clean up any previous backfill data for this user ─────────
    // Deletes old isAutoBackfill:true transactions to prevent double-counting.
    const existingBackfillTxns = await db()
      .collection("transactions")
      .where("userId", "==", uid)
      .where("isAutoBackfill", "==", true)
      .get();

    if (!existingBackfillTxns.empty) {
      const txChunks = [];
      for (let i = 0; i < existingBackfillTxns.docs.length; i += 400) {
        txChunks.push(existingBackfillTxns.docs.slice(i, i + 400));
      }
      for (const chunk of txChunks) {
        const delBatch = db().batch();
        for (const d of chunk) delBatch.delete(d.ref);
        await delBatch.commit();
      }
    }

    // Clean up existing backfilled five_market_daily docs (isBackdated:true)
    const existingDailySnap = await db()
      .collection("portfolios")
      .doc(uid)
      .collection("five_market_daily")
      .get();

    const backdatedDailyDocs = existingDailySnap.docs.filter(
      (d) => d.data().isBackdated === true,
    );
    if (backdatedDailyDocs.length > 0) {
      const dayChunks = [];
      for (let i = 0; i < backdatedDailyDocs.length; i += 400) {
        dayChunks.push(backdatedDailyDocs.slice(i, i + 400));
      }
      for (const chunk of dayChunks) {
        const delBatch = db().batch();
        for (const d of chunk) delBatch.delete(d.ref);
        await delBatch.commit();
      }
    }

    // Clean up existing returnHistory entries that were from a previous backfill
    const existingHistSnap = await db()
      .collection("portfolios")
      .doc(uid)
      .collection("returnHistory")
      .get();

    const backdatedHistDocs = existingHistSnap.docs.filter(
      (d) => d.data().isBackdated === true,
    );
    if (backdatedHistDocs.length > 0) {
      const hChunks = [];
      for (let i = 0; i < backdatedHistDocs.length; i += 400) {
        hChunks.push(backdatedHistDocs.slice(i, i + 400));
      }
      for (const chunk of hChunks) {
        const delBatch = db().batch();
        for (const d of chunk) delBatch.delete(d.ref);
        await delBatch.commit();
      }
    }

    // ── Step 2: Write one deposit transaction per deposit entry (all backdated) ─
    const depositTids = [];
    for (const dep of deposits) {
      const depTs = admin.firestore.Timestamp.fromDate(
        new Date(dep.date + "T00:00:00.000Z")
      );
      const depTid =
        "DEP-BACKFILL-" +
        Date.now().toString(36).toUpperCase() +
        "-" +
        Math.random().toString(36).substring(2, 8).toUpperCase();
      await db().collection("transactions").doc(depTid).set({
        id: depTid,
        userId: uid,
        type: "deposit",
        amount: dep.amount,
        status: "approved",
        createdAt: depTs,
        updatedAt: now,
        notes: "Deposit",
        paymentMethod: "admin_entry",
        approvedBy: adminUid,
        isBackdated: true,
        backdatedBy: adminUid,
        backdatedAt: now,
        isAutoBackfill: true,
      });
      depositTids.push(depTid);
    }

    // ── Step 2b: Write front-end load fee transactions (backdated to each deposit date) ──
    const frontEndLoadTids = [];
    if (frontEndLoadPct > 0) {
      for (let di = 0; di < deposits.length; di++) {
        const dep = deposits[di];
        const fee = parseFloat((dep.amount * frontEndLoadPct / 100).toFixed(2));
        if (fee <= 0) continue;
        const felTs = admin.firestore.Timestamp.fromDate(
          new Date(dep.date + "T00:00:00.000Z"),
        );
        const felTid =
          "FEL-BACKFILL-" +
          Date.now().toString(36).toUpperCase() +
          "-" +
          Math.random().toString(36).substring(2, 8).toUpperCase();
        await db().collection("transactions").doc(felTid).set({
          id: felTid,
          userId: uid,
          type: "front_end_load_fee",
          feeKind: "front_end_load",
          amount: fee,
          status: "approved",
          feePct: frontEndLoadPct,
          feeBaseAmount: dep.amount,
          relatedTxId: depositTids[di] || "",
          periodKey: dep.date.substring(0, 7),
          createdAt: felTs,
          updatedAt: now,
          approvedBy: adminUid,
          notes: `Front-end load (${frontEndLoadPct}%) on deposit ${dep.date}`,
          isBackdated: true,
          backdatedBy: adminUid,
          backdatedAt: now,
          isAutoBackfill: true,
        });
        frontEndLoadTids.push(felTid);
      }
    }

    // ── Step 3: Write DAILY five_market_daily docs + daily transactions ────
    // Processes month by month. Within each month, writes one batch per day.
    // Also writes monthly returnHistory + fee_statement + performance_fee + management_fee.
    // Start after front-end load deductions to reflect actual invested capital.
    let portfolioCurrentValue = totalAmount - totalFrontEndLoad;

    for (const monthKey of months) {
      const md = monthlyData[monthKey];
      const monthGross = parseFloat(md.grossProfit.toFixed(2));
      const performanceFee =
        monthGross > 0 && perfFeePct > 0
          ? parseFloat(((monthGross * perfFeePct) / 100).toFixed(2))
          : 0;
      // Monthly management fee: annual rate ÷ 12 on opening portfolio value
      const prevPortfolioValue = parseFloat(portfolioCurrentValue.toFixed(2));
      const managementFee =
        prevPortfolioValue > 0 && mgmtFeePctAnnual > 0
          ? parseFloat(((prevPortfolioValue * mgmtFeePctAnnual) / 100 / 12).toFixed(2))
          : 0;
      const monthNet = parseFloat((monthGross - performanceFee - managementFee).toFixed(2));
      const monthReturnPct =
        portfolioCurrentValue > 0
          ? parseFloat(
              ((monthGross / portfolioCurrentValue) * 100).toFixed(4),
            )
          : 0;

      const lastDateStr = md.lastTradingDate || md.firstDate;
      const monthEndTs = admin.firestore.Timestamp.fromDate(
        new Date(lastDateStr + "T18:59:00.000Z"),
      );

      // --- Write individual day docs and daily profit_entry transactions ---
      for (const entry of md.dailyEntries) {
        if (entry.totalProfitPkr === 0) continue;

        const dayTs = admin.firestore.Timestamp.fromDate(
          new Date(entry.date + "T18:59:00.000Z"),
        );

        const dayBatch = db().batch();

        const dailyTxRef = db().collection("transactions").doc();
        dayBatch.set(dailyTxRef, {
          id: dailyTxRef.id,
          userId: uid,
          type: "profit_entry",
          status: "approved",
          amount: entry.totalProfitPkr,
          notes: `Five-market daily profit ${entry.date}`,
          metadata: {
            periodKey: entry.date,
            source: "five_market_daily",
            markets: entry.markets,
          },
          createdAt: dayTs,
          updatedAt: dayTs,
          approvedBy: "system_five_market_daily",
          isBackdated: true,
          backdatedBy: adminUid,
          backdatedAt: now,
          isAutoBackfill: true,
        });

        const dailyDocRef = db()
          .collection("portfolios")
          .doc(uid)
          .collection("five_market_daily")
          .doc(entry.date);

        dayBatch.set(dailyDocRef, {
          date: entry.date,
          basePkr: entry.basePkr,
          tradingDay: true,
          markets: entry.markets,
          totalProfitPkr: entry.totalProfitPkr,
          creditedToWallet: true,
          effectiveDaySource: entry.eodSource,
          notes: `Five-market daily profit ${entry.date}`,
          createdAt: dayTs,
          creditedAt: dayTs,
          transactionId: dailyTxRef.id,
          isBackdated: true,
          backdatedBy: adminUid,
        });

        await dayBatch.commit();
      }

      // --- Write monthly: returnHistory + portfolio update + fee_statement ---
      portfolioCurrentValue = prevPortfolioValue + monthNet;

      const monthBatch = db().batch();

      // Management fee transaction (silent — hidden from monthly report, visible in yearly)
      if (managementFee > 0) {
        const mgmtTxRef = db().collection("transactions").doc();
        monthBatch.set(mgmtTxRef, {
          id: mgmtTxRef.id,
          userId: uid,
          type: "management_fee",
          feeKind: "management",
          amount: managementFee,
          status: "approved",
          feePct: mgmtFeePctAnnual,
          feeBaseAmount: prevPortfolioValue,
          periodKey: monthKey,
          silentFee: true,
          createdAt: monthEndTs,
          updatedAt: monthEndTs,
          approvedBy: adminUid,
          notes: `Management fee (${mgmtFeePctAnnual}%/yr ÷ 12 months) for ${monthKey} on PKR ${prevPortfolioValue}`,
          isBackdated: true,
          backdatedBy: adminUid,
          backdatedAt: now,
          isAutoBackfill: true,
        });
      }

      // Return history entry (one per month, shows in Portfolio screen)
      const histRef = db()
        .collection("portfolios")
        .doc(uid)
        .collection("returnHistory")
        .doc();
      monthBatch.set(histRef, {
        returnPct: monthReturnPct,
        profitAmount: monthNet,
        previousValue: prevPortfolioValue,
        newValue: parseFloat(portfolioCurrentValue.toFixed(2)),
        appliedAt: monthEndTs,
        appliedBy: adminUid,
        mode: "auto_backfill",
        periodKey: monthKey,
        isBackdated: true,
        backdatedBy: adminUid,
        backdatedAt: now,
      });

      // Update portfolios/{uid} document
      monthBatch.set(
        db().collection("portfolios").doc(uid),
        {
          currentValue: parseFloat(portfolioCurrentValue.toFixed(2)),
          totalDeposited: totalAmount,
          lastMonthlyReturnPct: monthReturnPct,
          lastUpdated: monthEndTs,
          fiveMarketDailyLedger: true,
          netDeposits: totalAmount,
        },
        { merge: true },
      );

      // Monthly performance fee transaction (if applicable)
      if (performanceFee > 0) {
        const feeTxRef = db().collection("transactions").doc();
        monthBatch.set(feeTxRef, {
          id: feeTxRef.id,
          userId: uid,
          type: "performance_fee",
          feeKind: "performance",
          amount: performanceFee,
          status: "approved",
          feePct: perfFeePct,
          feeBaseAmount: monthGross,
          periodKey: monthKey,
          createdAt: monthEndTs,
          updatedAt: monthEndTs,
          approvedBy: adminUid,
          notes: "",
          isBackdated: true,
          backdatedBy: adminUid,
          backdatedAt: now,
          isAutoBackfill: true,
        });
      }

      // Fee statement (shown in Reports screen)
      // Front-end load allocated to the month(s) where deposits were made
      const frontEndLoadForThisMonth = parseFloat(
        Object.entries(frontEndLoadByDate)
          .filter(([date]) => date.startsWith(monthKey))
          .reduce((s, [, v]) => s + v, 0)
          .toFixed(2),
      );
      const totalFeeAmt = parseFloat(
        (performanceFee + managementFee + frontEndLoadForThisMonth).toFixed(2),
      );
      const effectiveFeeRatePct =
        monthGross > 0
          ? parseFloat(((totalFeeAmt / monthGross) * 100).toFixed(4))
          : 0;

      monthBatch.set(
        db()
          .collection("users")
          .doc(uid)
          .collection("fee_statements")
          .doc(monthKey),
        {
          periodKey: monthKey,
          principalAtStart: prevPortfolioValue,
          depositsThisMonth: deposits
            .filter((d) => d.date.startsWith(monthKey))
            .reduce((s, d) => s + d.amount, 0),
          withdrawalsThisMonth: 0,
          grossProfit: monthGross,
          netProfit: monthNet,
          managementFee,
          performanceFee,
          frontEndLoadFee: frontEndLoadForThisMonth,
          referralFee: 0,
          totalFees: totalFeeAmt,
          effectiveFeeRatePct,
          generatedAt: now,
          isBackdated: true,
          backdatedBy: adminUid,
          isAutoBackfill: true,
        },
        { merge: true },
      );

      await monthBatch.commit();
    }

    // ── Step 4: Recalculate wallet from all written transactions ──────────
    const { recalculateWallet } = require("./wallet_helpers");
    await recalculateWallet(uid);

    const walletSnap = await db().collection("wallets").doc(uid).get();
    if (walletSnap.exists) {
      const w = walletSnap.data();
      const netDeposits = parseFloat(
        (
          Number(w.totalDeposited || 0) - Number(w.totalWithdrawn || 0)
        ).toFixed(2),
      );
      await db()
        .collection("portfolios")
        .doc(uid)
        .set({ netDeposits, netDepositsUpdatedAt: now }, { merge: true });
    }

    await safeAppendAudit(
      adminUid,
      "admin",
      "adminAutoBackfillInvestor",
      "investor",
      uid,
      null,
      {
        deposits,
        monthsProcessed: months.length,
        tradingDaysProcessed: totalTradingDays,
        totalGrossProfit,
        totalNetProfit,
      },
    );

    return {
      ok: true,
      dryRun: false,
      monthsProcessed: months.length,
      tradingDaysProcessed: totalTradingDays,
      totalGrossProfit: parseFloat(totalGrossProfit.toFixed(2)),
      totalNetProfit: parseFloat(totalNetProfit.toFixed(2)),
      totalFees: parseFloat(totalFees.toFixed(2)),
      totalFrontEndLoad: parseFloat(totalFrontEndLoad.toFixed(2)),
      depositTransactionIds: depositTids,
      frontEndLoadTransactionIds: frontEndLoadTids,
      totalDeposited: totalAmount,
      missingEodDays,
      months: monthResults,
    };
  },
);
