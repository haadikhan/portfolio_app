import "package:shared_preferences/shared_preferences.dart";

/// Legacy device-wide — migrated per account on first read.
const String kRiskDisclaimerOneTimeShownKey = "risk_disclaimer_one_time_shown_v1";

String _prefsKeyForUser(String firebaseUid) =>
    "risk_disclaimer_seen_v2_${firebaseUid.trim()}";

/// True after this Firebase user has tapped Continue on the onboarding note.
///
/// Migrates the old global flag so upgrades do not reshuffle acknowledgement.
Future<bool> hasSeenRiskDisclaimerForUser(String firebaseUid) async {
  final uid = firebaseUid.trim();
  if (uid.isEmpty) return true;

  final p = await SharedPreferences.getInstance();
  final keyed = p.getBool(_prefsKeyForUser(uid)) ?? false;
  if (keyed) return true;

  final legacy = p.getBool(kRiskDisclaimerOneTimeShownKey) ?? false;
  if (legacy) {
    await p.setBool(_prefsKeyForUser(uid), true);
    return true;
  }

  return false;
}

Future<void> markRiskDisclaimerSeenForUser(String firebaseUid) async {
  final uid = firebaseUid.trim();
  if (uid.isEmpty) return;

  final p = await SharedPreferences.getInstance();
  await Future.wait([
    p.setBool(_prefsKeyForUser(uid), true),
    p.setBool(kRiskDisclaimerOneTimeShownKey, true),
  ]);
}
