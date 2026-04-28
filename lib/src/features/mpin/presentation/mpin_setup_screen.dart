import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../providers/mpin_providers.dart";
import "../data/mpin_service.dart";
import "../data/mpin_status.dart";
import "mpin_keypad.dart";

enum MpinSetupMode {
  /// First-time setup. No current PIN required (also used after a successful
  /// password re-authentication for the "Forgot MPIN" flow — backend accepts
  /// `setMpin` with no `currentPin` because `auth_time` is fresh).
  setup,

  /// Change existing PIN. Requires current PIN, new PIN, confirm.
  change,
}

class MpinSetupScreen extends ConsumerStatefulWidget {
  const MpinSetupScreen({super.key, this.mode = MpinSetupMode.setup});

  final MpinSetupMode mode;

  @override
  ConsumerState<MpinSetupScreen> createState() => _MpinSetupScreenState();
}

enum _SetupStep { current, choose, confirm }

class _MpinSetupScreenState extends ConsumerState<MpinSetupScreen> {
  late _SetupStep _step = widget.mode == MpinSetupMode.change
      ? _SetupStep.current
      : _SetupStep.choose;

  String? _currentPin;
  String? _newPin;
  String? _error;
  bool _busy = false;

  String _stepLabel(BuildContext context) {
    if (widget.mode == MpinSetupMode.change) {
      switch (_step) {
        case _SetupStep.current:
          return context.tr("mpin_change_step_current");
        case _SetupStep.choose:
          return context.tr("mpin_change_step_new");
        case _SetupStep.confirm:
          return context.tr("mpin_change_step_confirm");
      }
    }
    return _step == _SetupStep.confirm
        ? context.tr("mpin_setup_step_confirm")
        : context.tr("mpin_setup_step_choose");
  }

  String _headerText(BuildContext context) {
    switch (_step) {
      case _SetupStep.current:
        return context.tr("mpin_enter_current");
      case _SetupStep.choose:
        return context.tr("mpin_enter_new");
      case _SetupStep.confirm:
        return context.tr("mpin_confirm_new");
    }
  }

  Future<void> _onCompleted(String value) async {
    if (_busy) return;
    setState(() => _error = null);

    if (_step == _SetupStep.current) {
      _currentPin = value;
      setState(() => _step = _SetupStep.choose);
      return;
    }
    if (_step == _SetupStep.choose) {
      _newPin = value;
      setState(() => _step = _SetupStep.confirm);
      return;
    }
    if (value != _newPin) {
      setState(() {
        _error = context.tr("mpin_mismatch");
        _step = _SetupStep.choose;
        _newPin = null;
      });
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(mpinServiceProvider).setMpin(
        newPin: _newPin!,
        currentPin: _currentPin,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.mode == MpinSetupMode.change
                ? context.tr("mpin_changed_success")
                : context.tr("mpin_set_success"),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on MpinException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _mapError(context, e);
        if (e.kind == MpinErrorKind.wrong) {
          _step = _SetupStep.current;
          _currentPin = null;
          _newPin = null;
        } else if (e.kind == MpinErrorKind.invalidFormat) {
          _step = _SetupStep.choose;
          _newPin = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  String _mapError(BuildContext context, MpinException e) {
    switch (e.kind) {
      case MpinErrorKind.wrong:
        return context.tr("mpin_wrong");
      case MpinErrorKind.locked:
        return context.tr("mpin_locked_short");
      case MpinErrorKind.invalidFormat:
        return context.tr("mpin_invalid_format");
      case MpinErrorKind.needsCurrentPin:
        return context.tr("mpin_enter_current");
      case MpinErrorKind.notSet:
      case MpinErrorKind.unauthenticated:
      case MpinErrorKind.generic:
        return e.message ?? e.code ?? context.tr("error_alert_title");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == MpinSetupMode.change
              ? context.tr("mpin_change_cta")
              : context.tr("mpin_setup_cta"),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                _stepLabel(context),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              MpinKeypad(
                key: ValueKey(_step),
                headerText: _headerText(context),
                errorText: _error,
                busy: _busy,
                onCompleted: _onCompleted,
              ),
              const Spacer(),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convenience widget that wraps the [MpinSetupScreen] in a route used after
/// a successful password re-authentication (Forgot MPIN flow). Same as the
/// `setup` mode but preserved separately so callers can express intent.
class MpinForgotResetScreen extends StatelessWidget {
  const MpinForgotResetScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const MpinSetupScreen(mode: MpinSetupMode.setup);
}

/// Lightweight watcher that pops itself when the user becomes lockedOut,
/// useful as a trailing widget. Currently unused but kept here since the
/// dialog flow may reuse it later.
class MpinLockoutGuard extends ConsumerWidget {
  const MpinLockoutGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref
        .watch(mpinStatusStreamProvider)
        .maybeWhen(data: (v) => v, orElse: () => MpinStatus.empty);
    if (s.isLockedNow && Navigator.of(context).canPop()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    }
    return child;
  }
}
