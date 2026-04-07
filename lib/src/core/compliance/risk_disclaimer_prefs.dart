import "package:shared_preferences/shared_preferences.dart";

const String kRiskDisclaimerOneTimeShownKey = "risk_disclaimer_one_time_shown_v1";

Future<void> markRiskDisclaimerSeen() async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(kRiskDisclaimerOneTimeShownKey, true);
}

Future<bool> hasSeenRiskDisclaimer() async {
  final p = await SharedPreferences.getInstance();
  return p.getBool(kRiskDisclaimerOneTimeShownKey) ?? false;
}
