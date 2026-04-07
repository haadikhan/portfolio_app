const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

const db = () => admin.firestore();

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

function mapTimeSeriesDaily(payload) {
  const daily = payload?.["Time Series (Daily)"];
  if (!daily || typeof daily !== "object") return [];
  return Object.entries(daily).map(([date, v]) => ({
    date,
    open: Number(v["1. open"]) || 0,
    high: Number(v["2. high"]) || 0,
    low: Number(v["3. low"]) || 0,
    close: Number(v["4. close"]) || 0,
    volume: Number(v["5. volume"]) || 0,
  }));
}

async function fetchDailyBarsFromApi({ ticker, exchange }) {
  const apiKey = process.env.MARKET_DATA_API_KEY || "";
  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "Missing MARKET_DATA_API_KEY env var.",
    );
  }
  const symbol = exchange ? `${exchange}:${ticker}` : ticker;
  const url = new URL("https://www.alphavantage.co/query");
  url.searchParams.set("function", "TIME_SERIES_DAILY");
  url.searchParams.set("symbol", symbol);
  url.searchParams.set("outputsize", "compact");
  url.searchParams.set("apikey", apiKey);

  const res = await fetch(url.toString());
  if (!res.ok) {
    throw new HttpsError(
      "unavailable",
      `Market API failed with status ${res.status}`,
    );
  }
  const json = await res.json();
  const bars = mapTimeSeriesDaily(json);
  if (bars.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "No market bars returned from provider.",
    );
  }
  return bars;
}

async function writeBars(companyId, bars, source = "api") {
  const batch = db().batch();
  let written = 0;
  for (const b of bars.slice(0, 60)) {
    const ref = db()
      .collection("market_companies")
      .doc(companyId)
      .collection("daily_bars")
      .doc(b.date);
    batch.set(
      ref,
      {
        date: admin.firestore.Timestamp.fromDate(new Date(`${b.date}T00:00:00Z`)),
        open: b.open,
        high: b.high,
        low: b.low,
        close: b.close,
        volume: b.volume,
        source,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    written += 1;
  }
  batch.set(
    db().collection("market_meta").doc(companyId),
    {
      companyId,
      provider: "alphavantage",
      delayMinutes: 15,
      lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await batch.commit();
  return written;
}

exports.syncMarketDailyBars = onCall({ region: "us-central1" }, async (req) => {
  if (!req.auth?.uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  await assertAdmin(req.auth.uid);
  const companyId = String(req.data?.companyId || "").trim();
  if (!companyId) {
    throw new HttpsError("invalid-argument", "companyId is required.");
  }
  const companyDoc = await db().collection("market_companies").doc(companyId).get();
  if (!companyDoc.exists) {
    throw new HttpsError("not-found", "Company not found.");
  }
  const c = companyDoc.data() || {};
  const ticker = String(c.ticker || "").trim();
  const exchange = String(c.exchange || "").trim();
  if (!ticker) {
    throw new HttpsError("failed-precondition", "Company ticker is missing.");
  }

  const bars = await fetchDailyBarsFromApi({ ticker, exchange });
  const written = await writeBars(companyId, bars, "api");
  return { ok: true, written };
});

exports.fetchLatestMarketSnapshot = onCall(
  { region: "us-central1" },
  async (req) => {
    if (!req.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const companyId = String(req.data?.companyId || "").trim();
    if (!companyId) {
      throw new HttpsError("invalid-argument", "companyId is required.");
    }
    const snap = await db()
      .collection("market_companies")
      .doc(companyId)
      .collection("daily_bars")
      .orderBy("date", "desc")
      .limit(1)
      .get();
    if (snap.empty) return { latest: null };
    const d = snap.docs[0].data();
    return {
      latest: {
        date: d.date?.toDate?.()?.toISOString?.() || null,
        open: d.open ?? 0,
        close: d.close ?? 0,
        source: d.source || "manual",
      },
    };
  },
);

exports.syncMarketDailyBarsNightly = onSchedule(
  {
    region: "us-central1",
    schedule: "every day 20:30",
    timeZone: "Asia/Karachi",
  },
  async () => {
    const companies = await db()
      .collection("market_companies")
      .where("isActive", "==", true)
      .get();
    for (const c of companies.docs) {
      const data = c.data();
      const ticker = String(data.ticker || "").trim();
      const exchange = String(data.exchange || "").trim();
      if (!ticker) continue;
      try {
        const bars = await fetchDailyBarsFromApi({ ticker, exchange });
        await writeBars(c.id, bars, "api");
      } catch (_) {
        // Best effort nightly sync; failures are tolerated.
      }
    }
  },
);
