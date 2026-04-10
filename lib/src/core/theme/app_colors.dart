import "package:flutter/material.dart";

@immutable
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF0F7A2C);
  static const Color primaryDark = Color(0xFF0B5F22);
  static const Color secondary = Color(0xFFE9F5EC);
  static const Color accent = Color(0xFFCFF1DA);

  static const Color backgroundTop = Color(0xFFF8FCF9);
  static const Color backgroundBottom = Color(0xFFEFF8F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF5FAF6);

  static const Color heading = Color(0xFF124B2B);
  static const Color body = Color(0xFF2A2E2B);
  static const Color bodyMuted = Color(0xFF6B726D);

  static const Color border = Color(0xFFD6E6DA);
  static const Color focus = Color(0xFF6BCB8A);
  static const Color success = Color(0xFF1D9C49);
  static const Color warning = Color(0xFFE3A008);
  static const Color error = Color(0xFFD14343);

  /// Pastel fills for dashboard quick action buttons (light theme).
  static const Color dashboardDepositTint = Color(0xFFE8F5E9);
  static const Color dashboardDepositFg = Color(0xFF2E7D32);
  static const Color dashboardWithdrawTint = Color(0xFFFFEBEE);
  static const Color dashboardWithdrawFg = Color(0xFFC62828);
  static const Color dashboardHistoryTint = Color(0xFFE3F2FD);
  static const Color dashboardHistoryFg = Color(0xFF1565C0);
  static const Color dashboardReportsTint = Color(0xFFF3E5F5);
  static const Color dashboardReportsFg = Color(0xFF6A1B9A);

  /// Quick access 2x2 tiles (reference-style saturated cards).
  static const Color quickAccessPortfolio = Color(0xFF1B4332);
  static const Color quickAccessWallet = Color(0xFF1565C0);
  static const Color quickAccessTransactions = Color(0xFF4A148C);
  static const Color quickAccessProfile = Color(0xFF00695C);

  /// Decorative circles on wallet hero (low alpha).
  static const Color walletHeroOverlayA = Color(0x33FFFFFF);
  static const Color walletHeroOverlayB = Color(0x22FFFFFF);
}
