# OTP on new device only (plan)

This document is the implementation spec for investor login: **a one-time SMS code only when the app does not recognize the current device**. There is **no** setting that forces OTP on **every** login from a **trusted / same** device.

---

## Product rules

1. **Primary sign-in** stays **email + password** (unchanged, non-breaking).
2. **After** a successful email/password sign-in, the app checks whether this physical device is **trusted** for this user.
3. **Trusted device** → go straight to the app (no OTP).
4. **Untrusted (new) device** → user must complete **Firebase Phone Auth** (SMS with OS auto-fill on Android / suggestion on iOS where supported).
5. **After** a successful OTP on that device, the server records the device as **trusted** so **future logins on that device do not ask for OTP again** (until revoke, logout-on-this-device, reinstall, or phone change policy below).
6. **Explicitly out of scope (do not implement, do not document in UI)**:
   - Any toggle or mode like “require OTP every time I log in” or “OTP on this device every login”.
   - Any option that deliberately breaks “trust until revoke / logout / reinstall” for normal same-device use.

Optional **support-style** controls (only if needed later): revoke all trusted devices, or change verified phone with full re-trust — not a “same device every time” OTP switch.

---

## Trust model

| Event | Effect on trust |
|--------|------------------|
| Successful OTP on a new device | That device is added to `trustedDevices`. |
| User logs out on this device | Remove **this** device’s trust record only (same as prior spec). |
| User revokes a device in “Trusted devices” | That device is removed; next login there requires OTP again. |
| App reinstall / OS reset / new raw device id | Treated as new device → OTP again. |
| Verified phone number changed (admin/user flow) | Clear all trusted devices; every device must re-verify. |

---

## Data model (Firestore)

- `users/{uid}.security` (or top-level fields — keep merge-safe):
  - `verifiedPhone` — E.164, e.g. `+923001234567`
  - `verifiedPhoneAt` — timestamp
  - **Do not** add `otpOnNewDeviceEnabled` or any “every login OTP” flag; gating is purely **device list + verified phone**.
- `users/{uid}/trustedDevices/{deviceHash}`:
  - `deviceName`, `platform`, `firstSeenAt`, `lastSeenAt`, `appVersion`
- Rules: clients **read** own trusted devices; **writes only via Cloud Functions** (Admin SDK).

---

## Backend (Cloud Functions)

Callable functions (names can match existing WIP):

1. **`verifyPhoneAndTrustCurrentDevice`** — After client completes Phone Auth and links then unlinks (proof), server sets `verifiedPhone`, writes current `deviceHash` to `trustedDevices`. Use when user first adds phone or changes phone (clears others first).
2. **`markDeviceTrusted`** — Same trust write after a **new-device login** OTP (user already has `verifiedPhone` from before).
3. **`removeTrustedDevice`** — Logout (current device) or user revokes a row.
4. **`changeVerifiedPhone`** — Optional: clears all `trustedDevices`, updates `verifiedPhone`, trusts current device only.

No callables for “enable/disable OTP globally” if that doubles as a confusing master switch; if an opt-out is required later, name it clearly (e.g. “Allow login without phone verification”) and keep it **off** the main profile for v1.

---

## Client (Flutter)

- **`device_fingerprint.dart`** — Stable `deviceHash` per user + device (already outlined).
- **`otp_service.dart`** — `verifyPhoneNumber`, handle auto-retrieval, `link`/`unlink` pattern (already outlined).
- **`login_otp_challenge_screen.dart`** — Shown only when: signed in with email/password **and** `verifiedPhone` is set **and** current `deviceHash` ∉ `trustedDevices`.
- **`auth_gate_screen.dart`** — After auth, run the gate; never show OTP for trusted devices.
- **`auth_service.logout`** — Best-effort `removeTrustedDevice` for current `deviceHash` before `signOut`.
- **Profile / security UI**:
  - Show **verified phone** and **Trusted devices** list with revoke.
  - **Do not** add a switch “OTP every login” or “OTP on same device”.
  - Flow to **add or change** verified phone (with SMS) is required so new-device OTP has a destination number.

---

## Firebase Console

- Enable **Phone** sign-in provider (for SMS only; not switching primary login to phone).

---

## i18n

Use the security / OTP strings already added in `app_translations.dart`; adjust copy so nothing implies “every login on this device”.

---

## Deploy order

1. Firestore rules (trustedDevices subcollection).
2. New/updated Cloud Functions.
3. Ship app build.

---

## Non-breaking behavior

- Users **without** `verifiedPhone`: define behavior in implementation — either block new-device gate until phone is verified, or skip OTP until phone is set (weaker). Prefer **prompt to verify phone** before investor actions, aligned with KYC/profile.

This plan intentionally omits any **setting to turn on OTP on the same device every time**.
