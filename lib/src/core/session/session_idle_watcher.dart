import "dart:async";

import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../admin/providers/admin_providers.dart";
import "../../providers/auth_providers.dart";
import "../i18n/app_translations.dart";

const Duration _kSessionIdleTimeout = Duration(minutes: 3);

/// Signs out investor sessions after [_kSessionIdleTimeout] without pointer
/// activity, and after the same wall time when returning from background.
/// Staff roles (`admin`, `crm`, `team`) are excluded once [adminRoleProvider]
/// has data.
class SessionIdleWatcher extends ConsumerStatefulWidget {
  const SessionIdleWatcher({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<SessionIdleWatcher> createState() =>
      _SessionIdleWatcherState();
}

class _SessionIdleWatcherState extends ConsumerState<SessionIdleWatcher>
    with WidgetsBindingObserver {
  DateTime _lastActivity = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_eligible()) return;
    final elapsed = DateTime.now().difference(_lastActivity);
    if (elapsed >= _kSessionIdleTimeout) {
      unawaited(_performAutoLogout());
    } else {
      _syncIdleTimer();
    }
  }

  bool _eligible() {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;
    final roleAsync = ref.read(adminRoleProvider);
    return roleAsync.when(
      data: (role) {
        final r = (role ?? "").trim().toLowerCase();
        return r.isEmpty || r == "investor";
      },
      loading: () => false,
      error: (_, __) => false,
    );
  }

  void _syncIdleTimer() {
    _timer?.cancel();
    if (!_eligible()) return;
    final elapsed = DateTime.now().difference(_lastActivity);
    if (elapsed >= _kSessionIdleTimeout) {
      unawaited(_performAutoLogout());
      return;
    }
    final remaining = _kSessionIdleTimeout - elapsed;
    _timer = Timer(remaining, () {
      if (!mounted) return;
      if (_eligible() &&
          DateTime.now().difference(_lastActivity) >= _kSessionIdleTimeout) {
        unawaited(_performAutoLogout());
      }
    });
  }

  void _handlePointerDown(PointerDownEvent _) {
    if (!_eligible()) return;
    _lastActivity = DateTime.now();
    _syncIdleTimer();
  }

  Future<void> _performAutoLogout() async {
    _timer?.cancel();
    if (!_eligible()) return;
    try {
      await ref.read(authControllerProvider.notifier).logout();
    } catch (_) {}
    if (!mounted) return;
    final ctx = widget.navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(ctx.tr("session_timeout_snackbar"))),
      );
      ctx.go("/login");
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<User?>(currentUserProvider, (prev, next) {
      if (next == null) {
        _timer?.cancel();
        return;
      }
      if (prev == null) {
        _lastActivity = DateTime.now();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncIdleTimer();
        });
      }
    });

    ref.listen<AsyncValue<String?>>(adminRoleProvider, (prev, next) {
      next.when(
        loading: () => _timer?.cancel(),
        error: (_, __) => _timer?.cancel(),
        data: (role) {
          final nextR = (role ?? "").trim().toLowerCase();
          final prevR = prev?.whenOrNull(
            data: (v) => (v ?? "").trim().toLowerCase(),
          );
          if (prev is AsyncData && prevR == nextR) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _syncIdleTimer();
          });
        },
      );
    });

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: widget.child,
    );
  }
}
