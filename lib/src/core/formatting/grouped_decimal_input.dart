import "package:flutter/services.dart";
import "package:intl/intl.dart";

/// Parses a user-entered amount that may contain thousand separators (commas).
double? parseGroupedDecimal(String? raw) {
  if (raw == null) return null;
  final cleaned =
      raw.replaceAll(",", "").replaceAll(" ", "").trim();
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Thousands grouping with commas ([en_US]) while typing; max two fractional digits.
///
/// Grouping locale is fixed so Urdu (or other) UI locale does not flip separators.
class GroupedDecimalInputFormatter extends TextInputFormatter {
  static final NumberFormat _intGrouped = NumberFormat("#,##0", "en_US");

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final stripped = _stripGrouping(newValue.text);
    if (stripped.isEmpty) {
      return const TextEditingValue(
        text: "",
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final normalized = _normalizePlainNumeric(stripped);
    if (normalized == null) {
      return oldValue;
    }

    final display = _toGroupedDisplay(normalized);
    final logicalCaret = _logicalCaretIgnoringCommas(
      newValue.text,
      newValue.selection.baseOffset,
    );
    final caret = _mapLogicalCaretToOffset(display, logicalCaret);

    return TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  static String _stripGrouping(String s) =>
      s.replaceAll(",", "").replaceAll(" ", "");

  /// Digits, at most one `.`, at most two digits after `.`.
  static String? _normalizePlainNumeric(String raw) {
    final buf = StringBuffer();
    var sawDot = false;
    var fracCount = 0;
    for (var i = 0; i < raw.length; i++) {
      final c = raw.codeUnitAt(i);
      if (c == 0x2E) {
        if (sawDot) return null;
        sawDot = true;
        buf.writeCharCode(c);
      } else if (c >= 0x30 && c <= 0x39) {
        if (sawDot) {
          if (fracCount >= 2) return null;
          fracCount++;
        }
        buf.writeCharCode(c);
      } else {
        return null;
      }
    }
    return buf.toString();
  }

  static String _toGroupedDisplay(String normalized) {
    final dot = normalized.indexOf(".");
    final hasDot = dot != -1;
    final intRaw = hasDot ? normalized.substring(0, dot) : normalized;
    final fracRaw = hasDot ? normalized.substring(dot + 1) : "";
    final trailingDotOnly = hasDot && fracRaw.isEmpty;

    final intForFormat =
        intRaw.isEmpty ? (hasDot ? "0" : intRaw) : intRaw;
    final intFormatted = intForFormat.isEmpty
        ? ""
        : (_intGrouped.format(int.parse(intForFormat, radix: 10)));

    if (!hasDot) return intFormatted;

    if (trailingDotOnly) {
      return "$intFormatted.";
    }
    return "$intFormatted.$fracRaw";
  }

  /// Count digits and `.` before [selectionOffset], ignoring comma separators.
  static int _logicalCaretIgnoringCommas(String text, int selectionOffset) {
    var n = 0;
    final end = selectionOffset.clamp(0, text.length);
    for (var i = 0; i < end; i++) {
      final c = text.codeUnitAt(i);
      if (c == 0x2C || c == 0x20) continue;
      n++;
    }
    return n;
  }

  static int _mapLogicalCaretToOffset(String display, int logicalCaret) {
    if (logicalCaret <= 0) return 0;
    for (var i = 0; i <= display.length; i++) {
      var logicalBefore = 0;
      for (var j = 0; j < i && j < display.length; j++) {
        final c = display.codeUnitAt(j);
        if (c == 0x2C) continue;
        logicalBefore++;
      }
      if (logicalBefore >= logicalCaret) return i;
    }
    return display.length;
  }
}
