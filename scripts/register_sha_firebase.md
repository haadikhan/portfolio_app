# Register Android SHA Fingerprints in Firebase Console

These fingerprints were extracted by running `./gradlew signingReport` on this project.
All build variants (debug, release, profile) use the **debug keystore** at this time.

## SHA Fingerprints to Register

| Type    | Value |
|---------|-------|
| SHA-1   | `34:84:4A:31:DB:5E:3E:58:45:73:9C:8B:9B:24:89:D3:56:71:F5:ED` |
| SHA-256 | `4D:15:E6:93:4D:C2:3C:B6:16:4E:50:9D:E3:3B:9C:17:EE:B7:9E:D8:40:C8:A6:04:54:2F:F3:9E:DD:20:D5:D7` |

## Steps

1. Open https://console.firebase.google.com/project/portfolio-e97b1/settings/general/android:com.example.portfolio_app
2. Scroll down to **SHA certificate fingerprints**.
3. Click **Add fingerprint**.
4. Paste the **SHA-1** value above and save.
5. Click **Add fingerprint** again.
6. Paste the **SHA-256** value above and save.
7. Click **Save** at the bottom of the page.
8. Download the updated `google-services.json` from the same page.
9. Replace `android/app/google-services.json` in this project with the downloaded file.

## Why this fixes the error

Firebase Phone Auth uses Google Play Integrity to verify that the SMS code request
comes from a legitimate, unmodified build of your app. Play Integrity checks:
  - Package name: `com.example.portfolio_app`  ✓ (already correct)
  - Signing certificate SHA: NOT YET REGISTERED  ← causes "Invalid app info in play_integrity_token"

Once the SHA is registered, Firebase knows the signing identity is authorised and
the Play Integrity token validates successfully, allowing OTP SMS to be dispatched.

## After updating Firebase Console

Run in project root:
```
flutterfire configure --project=portfolio-e97b1
```
This refreshes `lib/firebase_options.dart` to ensure it stays in sync.
