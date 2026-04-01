class AppConfig {
  const AppConfig({
    required this.appName,
    required this.environment,
    required this.enableAnalytics,
  });

  final String appName;
  final String environment;
  final bool enableAnalytics;

  bool get isProduction => environment == "prod";

  factory AppConfig.fromEnvironment() {
    return AppConfig(
      appName: const String.fromEnvironment(
        "APP_NAME",
        defaultValue: "Wakalat Invest",
      ),
      environment: const String.fromEnvironment("APP_ENV", defaultValue: "dev"),
      enableAnalytics: const bool.fromEnvironment(
        "ENABLE_ANALYTICS",
        defaultValue: false,
      ),
    );
  }
}
