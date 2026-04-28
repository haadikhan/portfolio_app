import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_test/flutter_test.dart";
import "package:portfolio_app/src/features/mpin/data/mpin_status.dart";

void main() {
  group("MpinStatus.fromUserDoc", () {
    test("returns empty for null/empty doc", () {
      expect(MpinStatus.fromUserDoc(null), MpinStatus.empty);
      expect(
        MpinStatus.fromUserDoc(<String, dynamic>{}),
        const MpinStatus(hasMpin: false, enabled: false),
      );
    });

    test("hasMpin is false when only one of hash/salt is set", () {
      expect(
        MpinStatus.fromUserDoc(<String, dynamic>{"mpinHash": "abc"}).hasMpin,
        isFalse,
      );
      expect(
        MpinStatus.fromUserDoc(<String, dynamic>{"mpinSalt": "abc"}).hasMpin,
        isFalse,
      );
    });

    test("hasMpin true when both hash and salt are non-empty", () {
      final s = MpinStatus.fromUserDoc(<String, dynamic>{
        "mpinHash": "h",
        "mpinSalt": "s",
        "mpinEnabled": true,
      });
      expect(s.hasMpin, isTrue);
      expect(s.enabled, isTrue);
    });

    test("enabled false when flag missing", () {
      final s = MpinStatus.fromUserDoc(<String, dynamic>{
        "mpinHash": "h",
        "mpinSalt": "s",
      });
      expect(s.hasMpin, isTrue);
      expect(s.enabled, isFalse);
    });

    test("lockedUntil parses Timestamp in the future", () {
      final future = DateTime.now().add(const Duration(minutes: 10));
      final s = MpinStatus.fromUserDoc(<String, dynamic>{
        "mpinHash": "h",
        "mpinSalt": "s",
        "mpinEnabled": true,
        "mpinLockedUntil": Timestamp.fromDate(future),
      });
      expect(s.lockedUntil, isNotNull);
      expect(s.isLockedNow, isTrue);
    });

    test("lockedUntil drops past timestamps", () {
      final past = DateTime.now().subtract(const Duration(minutes: 10));
      final s = MpinStatus.fromUserDoc(<String, dynamic>{
        "mpinHash": "h",
        "mpinSalt": "s",
        "mpinEnabled": true,
        "mpinLockedUntil": Timestamp.fromDate(past),
      });
      expect(s.lockedUntil, isNull);
      expect(s.isLockedNow, isFalse);
    });
  });

  group("4-digit MPIN validator", () {
    final pinRegex = RegExp(r"^\d{4}$");

    test("accepts exactly four digits", () {
      expect(pinRegex.hasMatch("0000"), isTrue);
      expect(pinRegex.hasMatch("1234"), isTrue);
      expect(pinRegex.hasMatch("9999"), isTrue);
    });

    test("rejects non-digits, wrong length, or empty", () {
      expect(pinRegex.hasMatch(""), isFalse);
      expect(pinRegex.hasMatch("123"), isFalse);
      expect(pinRegex.hasMatch("12345"), isFalse);
      expect(pinRegex.hasMatch("12a4"), isFalse);
      expect(pinRegex.hasMatch("12 4"), isFalse);
      expect(pinRegex.hasMatch("-123"), isFalse);
    });
  });
}
