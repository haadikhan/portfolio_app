import "package:flutter/material.dart";

const _en = <String, String>{
  "profile": "Profile",
  "app_preferences": "App preferences",
  "dark_mode": "Dark mode",
  "light_mode": "Light mode",
  "language": "Language",
  "urdu": "Urdu",
  "english": "English",
  "admin_access_required": "Admin access required",
  "admin_role_required":
      "This account does not have the admin role. Sign in with an admin account.",
  "back_to_login": "Back to login",
  "sign_out": "Sign out",
  "overview": "Overview",
  "kyc_queue": "KYC queue",
  "deposits": "Deposits",
  "withdrawals": "Withdrawals",
  "investors": "Investors",
  "returns": "Returns",
  "total_users": "Total users",
  "pending_kyc": "Pending KYC",
};

const _ur = <String, String>{
  "profile": "پروفائل",
  "app_preferences": "ایپ کی ترجیحات",
  "dark_mode": "ڈارک موڈ",
  "light_mode": "لائٹ موڈ",
  "language": "زبان",
  "urdu": "اردو",
  "english": "انگریزی",
  "admin_access_required": "ایڈمن رسائی درکار ہے",
  "admin_role_required":
      "اس اکاؤنٹ میں ایڈمن کا کردار نہیں۔ ایڈمن اکاؤنٹ سے سائن ان کریں۔",
  "back_to_login": "لاگ ان پر واپس",
  "sign_out": "سائن آؤٹ",
  "overview": "جائزہ",
  "kyc_queue": "KYC قطار",
  "deposits": "جمع",
  "withdrawals": "نکالنا",
  "investors": "سرمایہ کار",
  "returns": "واپسی",
  "total_users": "کل صارفین",
  "pending_kyc": "زیر التواء KYC",
};

extension AppTranslations on BuildContext {
  String tr(String key) {
    final code = Localizations.localeOf(this).languageCode;
    final table = code == "ur" ? _ur : _en;
    return table[key] ?? _en[key] ?? key;
  }
}
