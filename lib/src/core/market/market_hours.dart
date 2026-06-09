// Market hours helpers for ISC-WAI five-market system.
// All times in PKT (Asia/Karachi, UTC+5).
// Gold: 24 hours — no time gate.
// Stock (PSX): Mon–Thu 09:00–16:00 PKT
//              Fri: 09:00–12:00 and 14:30–16:00 PKT
//              Fri 12:00–14:30 = prayer break (frozen)

/// Returns current PKT DateTime
DateTime nowPkt() =>
    DateTime.now().toUtc().add(const Duration(hours: 5));

/// Returns true if current PKT time is within
/// PSX stock market trading hours.
/// Accounts for Friday Jumu'ah prayer break.
bool isStockMarketOpen() {
  final pkt = nowPkt();
  final h = pkt.hour;
  final m = pkt.minute;
  final totalMinutes = h * 60 + m;

  // Saturday = 6, Sunday = 7 in DateTime.weekday
  if (pkt.weekday == DateTime.saturday || pkt.weekday == DateTime.sunday) {
    return false;
  }

  // Friday — two sessions with prayer break
  if (pkt.weekday == DateTime.friday) {
    // Session 1: 09:00–12:00 (540–720 minutes)
    if (totalMinutes >= 540 && totalMinutes < 720) {
      return true;
    }
    // Prayer break: 12:00–14:30 (720–870 minutes)
    if (totalMinutes >= 720 && totalMinutes < 870) {
      return false; // frozen during Jumu'ah
    }
    // Session 2: 14:30–16:00 (870–960 minutes)
    if (totalMinutes >= 870 && totalMinutes < 960) {
      return true;
    }
    return false;
  }

  // Monday–Thursday: 09:00–16:00 (540–960 minutes)
  return totalMinutes >= 540 && totalMinutes < 960;
}

/// Returns true if stock market is in Friday
/// prayer break (12:00–14:30 PKT)
bool isFridayPrayerBreak() {
  final pkt = nowPkt();
  if (pkt.weekday != DateTime.friday) return false;
  final totalMinutes = pkt.hour * 60 + pkt.minute;
  return totalMinutes >= 720 && totalMinutes < 870;
}

/// Gold market is ALWAYS open — 24 hours.
/// Returns true always.
/// Gold profit freezes only at 00:05 PKT credit time.
bool isGoldMarketOpen() => true;

/// Returns elapsed seconds within today's PKT
/// stock trading session (for display purposes).
/// Accounts for Friday prayer break.
int elapsedStockSessionSeconds() {
  final pkt = nowPkt();
  final h = pkt.hour;
  final m = pkt.minute;
  final s = pkt.second;
  final totalSeconds = h * 3600 + m * 60 + s;

  if (pkt.weekday == DateTime.saturday || pkt.weekday == DateTime.sunday) {
    return 0;
  }

  const sessionStart = 9 * 3600; // 09:00
  const sessionEnd = 16 * 3600; // 16:00
  const breakStart = 12 * 3600; // 12:00
  const breakEnd = 14 * 3600 + 30 * 60; // 14:30
  const breakDuration = breakEnd - breakStart; // 9000s
  const fridaySession = sessionEnd - sessionStart - breakDuration; // 23400s
  const fullSession = sessionEnd - sessionStart; // 25200s

  if (totalSeconds < sessionStart) return 0;
  if (totalSeconds >= sessionEnd) {
    // After close
    return pkt.weekday == DateTime.friday ? fridaySession : fullSession;
  }

  if (pkt.weekday == DateTime.friday) {
    if (totalSeconds < breakStart) {
      // Session 1
      return (totalSeconds - sessionStart).clamp(0, 10800);
    }
    if (totalSeconds < breakEnd) {
      // During prayer break — frozen at session 1 end
      return 10800; // 3 hours elapsed
    }
    // Session 2: session1 + (current - breakEnd)
    return 10800 + (totalSeconds - breakEnd);
  }

  // Mon–Thu
  return (totalSeconds - sessionStart).clamp(0, fullSession);
}
