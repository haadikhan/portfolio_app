# Firebase Integration Setup

The app now includes production Firebase Auth + Firestore code.  
Complete these one-time setup steps to run against your Firebase project.

## 1) Create Firebase project and apps
- Create a Firebase project in Firebase Console.
- Add Android app using package id from `android/app/build.gradle.kts`.
- Add iOS app using bundle id from Xcode Runner target.
- Add web app if web support is needed.

## 2) Generate FlutterFire config
Run from project root:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart`.

## 3) Add platform files
- Android: place `google-services.json` in `android/app/`
- iOS: place `GoogleService-Info.plist` in `ios/Runner/`

## 4) Firestore rules deployment
Deploy security rules:

```bash
firebase deploy --only firestore:rules
```

## 5) Enable services in Firebase Console
- Authentication -> enable Email/Password
- Firestore Database -> create database (production mode recommended with rules)

## App Check (Flutter Web)

Keep `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_app_check`, and other `firebase_*` packages in this project **version-aligned** (see `pubspec.yaml`). `firebase_app_check` depends on a matching `firebase_core` major line; mismatched versions fail `flutter pub get`.

Firebase App Check on **web** needs a registered **Web** provider (reCAPTCHA Enterprise or v3), or a **debug** provider for local development. The app activates App Check during startup (`activateFirebaseAppCheckBootstrap`).

- Register your web app under **Firebase Console → App Check** for the Firebase Web app ID you use locally.
- Copy the **reCAPTCHA site key** shown after registration.

**Local builds and CI:** pass the site key when you want App Check on web:

```bash
flutter run -d chrome -t lib/admin_main.dart \
  --dart-define=FIREBASE_APP_CHECK_WEB_RECAPTCHA_SITE_KEY=YOUR_SITE_KEY
```

Optional: choose the provider type if it differs from Enterprise (Firebase’s default registration path is Enterprise):

```bash
--dart-define=FIREBASE_APP_CHECK_WEB_PROVIDER=enterprise   # default
--dart-define=FIREBASE_APP_CHECK_WEB_PROVIDER=v3           # classic reCAPTCHA v3 registration only
```

### Web with no reCAPTCHA site key (debug, profile, and release)

When **`FIREBASE_APP_CHECK_WEB_RECAPTCHA_SITE_KEY` is empty**, every web build uses **`WebDebugProvider`** so App Check still **activates**. That avoids “no token” failures when **App Check enforcement** is on for **Authentication** — including **`flutter run --profile`**, release builds, and hosted sites that do not pass a reCAPTCHA dart-define.

You **must** register a debug token **that matches what the SDK sends**. Flutter often prints **`App Check debug token: …` in the terminal** (Chrome run) — it is **not enough** to only glance at the browser console; use the UUID from whichever log matches your run.

**Option A — Quick (rotate per cold start)**

1. Start `flutter run -d chrome -t lib/admin_main.dart` and find the line: `App Check debug token: <uuid>`.
2. **Firebase Console → App Check → Apps** → select your **Web** app → **Manage debug tokens**.
3. Add a debug token whose **Value** is **exactly that `<uuid>`** (each new run without a pinned token may log a **new** UUID — register that new one if you still see HTTP 403).
4. **Stop and cold-restart** `flutter run` (hot reload is not sufficient for App Check onboarding).

**Option B — Stable (recommended for CI / admins)**

1. In **Manage debug tokens**, use **Generate token**, **Save**, and copy the value.
2. Register it (Console already has it after Save).
3. Pin the client to **the same** UUID:

```bash
flutter run -d chrome -t lib/admin_main.dart \
  --dart-define=FIREBASE_APP_CHECK_WEB_DEBUG_TOKEN=PASTE_EXACT_CONSOLE_UUID_HERE
```

**Important:** Do **not** register only a Console-generated token while the app emits a **different** auto-generated UUID, unless that Console UUID is wired through `FIREBASE_APP_CHECK_WEB_DEBUG_TOKEN` above. Mixed tokens produce **HTTP 403** during `getToken`.

### HTTP 403 / `fetch-status-error` on web

If startup logs contain:

`AppCheck: Fetch server returned an HTTP error status. HTTP status: 403`

or **`app-check/fetch-status-error`**, the App Check backend rejected the debug exchange:

- **Most common:** token **Value** in Console does **not** match the **`App Check debug token:`** line from the Flutter terminal (or pinned dart-define).
- **Also check:** Debug tokens live under **App Check → your Web app**, same Firebase project / web `appId` as `lib/firebase_options.dart`; after fixing tokens use a **cold** restart.

For **real production** traffic, prefer a registered **reCAPTCHA** site key + `FIREBASE_APP_CHECK_WEB_RECAPTCHA_SITE_KEY` rather than relying on debug tokens long term.

### Release / profile note

Skipping activation is no longer used on web without a key; if you ship without a reCAPTCHA key, treat the debug token as mandatory for App Check until you add a site key.

### reCAPTCHA site key on localhost

- Allow your dev host (for example `localhost`) in the reCAPTCHA / Enterprise key **domain** settings in Google Cloud Console as required by your key type.
- `FIREBASE_APP_CHECK_WEB_PROVIDER` must match whether the app was registered in App Check as **Enterprise** or **v3**.

### If sign-in still fails with “token invalid”

- Confirm **project** and **web app id** match `firebase_options.dart`.
- Retry after registering the **debug** token (when no reCAPTCHA key) or fixing **provider type** / **domains** for reCAPTCHA.
- Ensure enforcement in Console matches what you configured on the client.

Mobile (Android / iOS) uses the existing debug vs production attestation flow and is unaffected by these defines.

## 6) Collections used
- `users/{uid}`
  - `name` (string)
  - `email` (string)
  - `createdAt` (ISO timestamp string)

## 7) App flow
- App starts at auth gate (`/`)
- Unauthenticated users are routed to login/signup
- On signup, profile document is created in Firestore
- Authenticated users land on home profile screen with realtime stream
