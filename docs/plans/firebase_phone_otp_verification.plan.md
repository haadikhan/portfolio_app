# Firebase Android phone OTP verification — execution plan

Goal: eliminate `app-not-authorized` / `17028 Invalid app info in play_integrity_token` when sending SMS OTP, by aligning **code**, **Firebase Auth (reCAPTCHA / phone flow)**, and **Android signing identities**.

## Prerequisites

- Firebase project: `portfolio-e97b1` (sender ID `500864820062`), Android package `com.example.portfolio_app`.
- Access: [Firebase Console](https://console.firebase.google.com/) and [Google Cloud Console](https://console.cloud.google.com/) for the same project.

---

## Step 1 — App bootstrap (Flutter, Android only)

**Done in repo** (verify if you pull fresh):

- After `Firebase.initializeApp`, call `configureFirebaseAndroidPhoneVerification()` before App Check activation.
- Behavior: for **debug** or when `FIREBASE_APP_CHECK_USE_PRODUCTION_ATTESTATION` is **false**, sets `FirebaseAuth.setSettings(forceRecaptchaFlow: true)` and runs `initializeRecaptchaConfig()`.

**Verify locally:**

```bash
flutter analyze lib/main.dart lib/admin_main.dart lib/src/core/firebase/firebase_auth_phone_bootstrap.dart
```

**Checkpoint:** Analyzer clean; debug logs may show `[FirebaseAuth][Android] Phone Auth: forceRecaptchaFlow=true`.

---

## Step 2 — Enable reCAPTCHA Enterprise for phone auth (console)

Firebase Phone Auth on Android can require **reCAPTCHA Enterprise** linkage. If logs show `No Recaptcha Enterprise siteKey configured`, finish this step before retesting OTP.

1. Open **Google Cloud Console** → select project **portfolio-e97b1**.
2. APIs & Services → **Enable APIs** → enable **reCAPTCHA Enterprise API** (if not already).
3. Open **Firebase Console** → **Authentication** → **Sign-in method** → **Phone** → ensure Phone is **enabled** and any linked “fraud prevention / reCAPTCHA” guidance is followed (UI text changes over time; enable what the console requests for Phone).

**Checkpoint:** No `No Recaptcha Enterprise siteKey configured` in logcat when sending code (or Enterprise key appears as configured in GCP reCAPTCHA Enterprise for this project).

---

## Step 3 — Register Android SHA-1 and SHA-256 fingerprints

Play Integrity and some Auth flows validate the app by **package name + SHA**.

1. Firebase Console → **Project settings** → **Your apps** → Android app `com.example.portfolio_app`.
2. Under **SHA certificate fingerprints**, add:
   - **Debug keystore** SHA-1 + SHA-256 (for `flutter run`).
   - **Release / upload / Play App Signing** SHA-1 + SHA-256 for every keystore you distribute with.

**Automated local values (Step 3a — run on your machine):**

From repo root:

```bash
cd android
./gradlew signingReport
```

(On Windows: `cd android` then `.\gradlew.bat signingReport`.)

Copy **Variant: debug** → `SHA1` and `SHA256` into Firebase. If you use a custom release keystore later, add that variant’s fingerprints too.

#### Step 3a — captured on this repo (DELL dev machine, `app` module)

> **Register these in Firebase** → Project settings → Your apps → Android `com.example.portfolio_app` → SHA certificate fingerprints.

| Fingerprint | Value |
|-------------|--------|
| **SHA-1** | `34:84:4A:31:DB:5E:3E:58:45:73:9C:8B:9B:24:89:D3:56:71:F5:ED` |
| **SHA-256** | `4D:15:E6:93:4D:C2:3C:B6:16:4E:50:9D:E3:3B:9C:17:EE:B7:9E:D8:40:C8:A6:04:54:2F:F3:9E:DD:20:D5:D7` |

Keystore used for **debug / release / profile** (current `build.gradle.kts`): `C:\Users\DELL\.android\debug.keystore` (release is still wired to debug signing).

**Checkpoint:** Firebase Android app lists all SHAs you use to install the APK.

---

## Step 4 — Refresh `google-services.json` (if you changed the Firebase app)

After adding SHAs or enabling APIs, download the latest **google-services.json** for the Android app and replace `android/app/google-services.json`. Regenerate if you use FlutterFire:

```bash
flutterfire configure
```

**Checkpoint:** `package_name` / `mobilesdk_app_id` unchanged unless you intentionally migrated apps.

---

## Step 5 — Clean rebuild and device QA

1. `flutter clean && flutter pub get`
2. Uninstall the app from the device (clears odd Auth state).
3. `flutter run` (or your release pipeline).
4. Attempt **Send code** on phone verification.

**Success:** SMS flow proceeds (may show reCAPTCHA in WebView when forced); no `17028` / `Invalid app info in play_integrity_token`.

**Still failing:** Capture logcat from app start through “Send code”:

- `[FirebaseAuth][Android]` lines
- `[OTP]` lines
- Any `reCAPTCHA` / `SmsRetrieverHelper` / `17028` lines

---

## Release vs sideload (dart-define)

| Build intent | Suggested |
|--------------|-----------|
| Debug / internal APK sideload | Default: `forceRecaptchaFlow` on for phone (matches non–Play Integrity attestation path). |
| Play Store + Play Integrity everywhere | Release with `--dart-define=FIREBASE_APP_CHECK_USE_PRODUCTION_ATTESTATION=true`; phone auth will not force reCAPTCHA in that mode. |

---

## Execution log (fill as you go)

| Step | Owner | Status | Notes |
|------|--------|--------|--------|
| 1 Bootstrap | Agent | ✅ | `flutter analyze` on bootstrap files — **No issues found** |
| 2 reCAPTCHA Enterprise / Phone in console | You | ☐ | GCP + Firebase Auth Phone; see Step 2 |
| 3 SHAs in Firebase | You | ☐ | Use table under Step 3a; confirm fingerprints appear in Firebase Console |
| 4 google-services sync | Agent | ✅ | Repo `google-services.json` matches `portfolio-e97b1` / `com.example.portfolio_app`; re-download after console changes |
| 5 Device QA | You | ☐ | `flutter clean`, reinstall app, retry Send code |

### Agent-run commands (audit trail)

```text
flutter analyze lib/main.dart lib/admin_main.dart lib/src/core/firebase/firebase_auth_phone_bootstrap.dart
→ Exit 0, No issues found

cd android ; .\gradlew.bat signingReport --no-daemon
→ BUILD SUCCESSFUL; app : signingReport Variant debug/release/profile use debug keystore (SHAs above)

flutter clean ; flutter pub get
→ Ready for reinstall + `flutter run` (Step 5)
```
