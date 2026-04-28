import "package:cloud_functions/cloud_functions.dart";

/// Coarse classification of MPIN call failures, used by UI to pick the right
/// localized message. Parsed from `FirebaseFunctionsException.message` which
/// the backend sets to one of `MPIN_*` strings.
enum MpinErrorKind {
  wrong,
  locked,
  invalidFormat,
  notSet,
  needsCurrentPin,
  unauthenticated,
  generic,
}

/// Wraps a backend MPIN failure with a typed `kind` for UI mapping.
class MpinException implements Exception {
  const MpinException(this.kind, {this.code, this.message});

  final MpinErrorKind kind;
  final String? code;
  final String? message;

  @override
  String toString() => "MpinException(${kind.name}, code=$code, message=$message)";
}

/// Thin wrapper around the four MPIN callables. All errors from the backend
/// are normalized into [MpinException] so UI never has to inspect raw codes.
class MpinService {
  MpinService({FirebaseFunctions? functions})
    : _f = functions ?? FirebaseFunctions.instanceFor(region: "us-central1");

  final FirebaseFunctions _f;

  Future<void> setMpin({required String newPin, String? currentPin}) async {
    try {
      await _f.httpsCallable("setMpin").call(<String, dynamic>{
        "newPin": newPin,
        if (currentPin != null && currentPin.isNotEmpty)
          "currentPin": currentPin,
      });
    } on FirebaseFunctionsException catch (e) {
      throw _toMpinException(e);
    }
  }

  Future<void> clearMpin({required String currentPin}) async {
    try {
      await _f.httpsCallable("clearMpin").call(<String, dynamic>{
        "currentPin": currentPin,
      });
    } on FirebaseFunctionsException catch (e) {
      throw _toMpinException(e);
    }
  }

  Future<void> setMpinEnabled({
    required bool enabled,
    required String currentPin,
  }) async {
    try {
      await _f.httpsCallable("setMpinEnabled").call(<String, dynamic>{
        "enabled": enabled,
        "currentPin": currentPin,
      });
    } on FirebaseFunctionsException catch (e) {
      throw _toMpinException(e);
    }
  }

  Future<Map<String, dynamic>> getMpinStatus() async {
    try {
      final result = await _f.httpsCallable("getMpinStatus").call();
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw _toMpinException(e);
    }
  }

  static MpinException _toMpinException(FirebaseFunctionsException e) {
    final raw = e.message?.trim() ?? "";
    if (raw == "MPIN_LOCKED") {
      return MpinException(MpinErrorKind.locked, code: e.code, message: raw);
    }
    if (raw == "MPIN_WRONG") {
      return MpinException(MpinErrorKind.wrong, code: e.code, message: raw);
    }
    if (raw == "MPIN_INVALID_FORMAT") {
      return MpinException(
        MpinErrorKind.invalidFormat,
        code: e.code,
        message: raw,
      );
    }
    if (raw == "MPIN_NEEDS_CURRENT") {
      return MpinException(
        MpinErrorKind.needsCurrentPin,
        code: e.code,
        message: raw,
      );
    }
    if (raw == "MPIN_NOT_SET") {
      return MpinException(MpinErrorKind.notSet, code: e.code, message: raw);
    }
    if (e.code == "unauthenticated") {
      return MpinException(
        MpinErrorKind.unauthenticated,
        code: e.code,
        message: raw,
      );
    }
    return MpinException(MpinErrorKind.generic, code: e.code, message: raw);
  }
}
