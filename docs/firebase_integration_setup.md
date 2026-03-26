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
