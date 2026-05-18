import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "theme_provider.dart";

/// When auto mode is active, refreshes [themeProvider] every 60s and on app
/// resume so time-based evaluation stays accurate alongside [ThemeMode.system].
class AutoThemeWatcher extends ConsumerStatefulWidget {
  const AutoThemeWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoThemeWatcher> createState() => _AutoThemeWatcherState();
}

class _AutoThemeWatcherState extends ConsumerState<AutoThemeWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTimerIfNeeded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshIfAuto();
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    final isAuto = ref.read(themeProvider).valueOrNull == ThemeMode.system;
    if (!isAuto) return;
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshIfAuto();
    });
  }

  void _refreshIfAuto() {
    if (!mounted) return;
    final isAuto = ref.read(themeProvider).valueOrNull == ThemeMode.system;
    if (!isAuto) {
      _timer?.cancel();
      return;
    }
    ref.invalidate(themeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeProvider).valueOrNull;
    if (mode == ThemeMode.system) {
      _startTimerIfNeeded();
    } else {
      _timer?.cancel();
    }
    return widget.child;
  }
}
