import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../theme/app_colors.dart";
import "connectivity_service.dart";
import "no_internet_screen.dart";

/// Wraps the entire app widget tree.
/// Shows [NoInternetScreen] when offline.
/// Passes through to [child] when online.
/// Auto-recovers without restart when internet returns.
class ConnectivityGate extends StatefulWidget {
  const ConnectivityGate({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate> {
  /// null = checking, true = online, false = offline.
  bool? _isOnline;

  @override
  void initState() {
    super.initState();
    _checkInitial();
  }

  Future<void> _checkInitial() async {
    if (kIsWeb) {
      setState(() => _isOnline = true);
      return;
    }
    final result = await ConnectivityService.hasInternet();
    if (mounted) {
      setState(() => _isOnline = result);
    }
  }

  void _onConnected() {
    if (mounted) setState(() => _isOnline = true);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return widget.child;

    if (_isOnline == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.primary,
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    if (_isOnline == false) {
      return ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: AppColors.primary,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: AppColors.primary,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          themeMode: ThemeMode.system,
          home: NoInternetScreen(onConnected: _onConnected),
        ),
      );
    }

    return widget.child;
  }
}
