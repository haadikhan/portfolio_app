import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:portfolio_app/src/core/security/biometric_prefs_store.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test("stores and clears biometric preference state", () async {
    const storage = FlutterSecureStorage();
    final store = BiometricPrefsStore(storage);

    expect(await store.isEnabled(), isFalse);

    await store.setEnabled(enabled: true, email: "user@example.com");
    expect(await store.isEnabled(), isTrue);
    expect(await store.getEnabledEmail(), "user@example.com");

    await store.clear();
    expect(await store.isEnabled(), isFalse);
    expect(await store.getEnabledEmail(), isNull);
  });
}
