import "package:flutter/material.dart";

/// Reusable 4-digit numeric keypad used for both the prompt dialog and the
/// setup screen. Looks similar to JazzCash / EasyPaisa entry: four dot
/// indicators on top, a 3x4 numeric grid below, and an optional [helperText]
/// rendered in red when [errorText] is set.
class MpinKeypad extends StatefulWidget {
  const MpinKeypad({
    super.key,
    required this.onCompleted,
    this.length = 4,
    this.headerText,
    this.errorText,
    this.busy = false,
    this.autoClearOnComplete = false,
  });

  final int length;
  final String? headerText;
  final String? errorText;
  final bool busy;
  final bool autoClearOnComplete;

  /// Called the moment the user enters [length] digits.
  final ValueChanged<String> onCompleted;

  @override
  State<MpinKeypad> createState() => _MpinKeypadState();
}

class _MpinKeypadState extends State<MpinKeypad> {
  String _value = "";

  void clear() {
    if (mounted) setState(() => _value = "");
  }

  void _press(String digit) {
    if (widget.busy) return;
    if (_value.length >= widget.length) return;
    setState(() {
      _value = "$_value$digit";
    });
    if (_value.length == widget.length) {
      widget.onCompleted(_value);
      if (widget.autoClearOnComplete) {
        Future.delayed(const Duration(milliseconds: 150), clear);
      }
    }
  }

  void _backspace() {
    if (widget.busy) return;
    if (_value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.headerText != null) ...[
          Text(
            widget.headerText!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(widget.length, (i) {
            final filled = i < _value.length;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? scheme.primary : Colors.transparent,
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 22,
          child: widget.errorText != null
              ? Text(
                  widget.errorText!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 4),
        _KeypadGrid(onDigit: _press, onBackspace: _backspace, busy: widget.busy),
      ],
    );
  }
}

class _KeypadGrid extends StatelessWidget {
  const _KeypadGrid({
    required this.onDigit,
    required this.onBackspace,
    required this.busy,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final keys = const [
      ["1", "2", "3"],
      ["4", "5", "6"],
      ["7", "8", "9"],
      ["", "0", "back"],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in keys)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final k in row) _KeyButton(label: k, busy: busy, onDigit: onDigit, onBackspace: onBackspace),
              ],
            ),
          ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.busy,
    required this.onDigit,
    required this.onBackspace,
  });

  final String label;
  final bool busy;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (label.isEmpty) {
      return const SizedBox(width: 70, height: 56);
    }
    final isBack = label == "back";
    return SizedBox(
      width: 70,
      height: 56,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: busy
              ? null
              : () {
                  if (isBack) {
                    onBackspace();
                  } else {
                    onDigit(label);
                  }
                },
          child: Center(
            child: isBack
                ? Icon(
                    Icons.backspace_outlined,
                    color: scheme.onSurface,
                    size: 22,
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
