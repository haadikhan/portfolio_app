# QA Document — Amanah Multi Asset Portfolio (Investor Mobile App)

**Platform:** Flutter investor app (`lib/main.dart` → `WakalatInvestApp`)  
**Router:** `go_router` in `lib/src/app/app.dart`  
**Document version:** 1.0  
**Prepared from codebase scan:** 2026-06-21

---

## Legend

| Status | Meaning |
|--------|---------|
| **Pass** | Actual result matches expected result |
| **Fail** | Actual result does not match expected result |
| **Blocked** | Test cannot be executed (environment, data, or dependency unavailable) |
| **N/A** | Test case does not apply to current build, platform, or user role |

**Notes column:** Record device/OS, build number, tester initials, screenshots, Firestore doc IDs, or defect ticket numbers.

---

## Summary Table — All Modules

| # | Module | Entry Point | Total TCs |
|---|--------|-------------|-----------|
| 1 | Onboarding & Splash | `SplashHost` / `PremiumSplashScreen` | 8 |
| 2 | Connectivity Gate | `ConnectivityGate` / `NoInternetScreen` | 6 |
| 3 | Force Update Gate | `/force-update` | 7 |
| 4 | Registration / Sign Up | `/signup` | 12 |
| 5 | Login (Email/Password) | `/login` | 10 |
| 6 | Forgot Password | `/forgot-password` | 5 |
| 7 | Auth Gate & Post-Login Routing | `/` (`AuthGateScreen`) | 10 |
| 8 | Device Trust OTP | `/login-otp` | 10 |
| 9 | Biometric / Fingerprint Setup | `/setup-fingerprint` | 8 |
| 10 | KYC Submission | `/kyc` | 14 |
| 11 | Legal Consent | `/legal` / shell overlay | 8 |
| 12 | KYC Approved Gate | Wrapper on gated routes | 6 |
| 13 | Consent Gate | Wrapper on market routes | 5 |
| 14 | Dashboard / Home | `/investor` → `UserHomeScreen` | 12 |
| 15 | Investment Portfolio Overview | `/portfolio` | 10 |
| 16 | Digital Gold Market Detail | `/five-market/gold` | 8 |
| 17 | Money Market Detail | `/five-market/money` | 8 |
| 18 | Stock / KMI30 Market Detail | `/five-market/stock` | 9 |
| 19 | Tech Market Detail | `/five-market/tech` | 7 |
| 20 | Debt Market Detail | `/five-market/debt` | 7 |
| 21 | Live Profit (Daily/Monthly/Yearly) | `/profit-live` | 12 |
| 22 | Five Market Daily Screen | `/five-market-daily` | 8 |
| 23 | KMI30 Companies Tab | `/market/kmi30-companies` | 8 |
| 24 | Market Overview | `/market` | 6 |
| 25 | Gold Price Chart | `/market/gold` | 6 |
| 26 | KMI30 Company Chart | `/market/kmi30-companies/:symbol` | 6 |
| 27 | Wallet & Ledger | `/wallet-ledger` | 10 |
| 28 | Deposit Request | `/wallet-ledger/deposit` | 14 |
| 29 | Withdrawal Request | `/wallet-ledger/withdraw` | 14 |
| 30 | Reports & PDF Generation | `/reports` | 12 |
| 31 | Report PDF Preview | `ReportPdfPreviewScreen` | 6 |
| 32 | Fee Statement Detail | `FeeStatementDetailScreen` | 5 |
| 33 | Notifications | `/notifications` | 9 |
| 34 | App Updates (Optional) | `/app-updates` | 8 |
| 35 | Investor Profile & Settings | `/profile` | 14 |
| 36 | MPIN Setup & Change | `/mpin/setup`, `/mpin/change` | 12 |
| 37 | MPIN on Withdrawal | `MpinPromptDialog` | 8 |
| 38 | Trusted Devices | `/profile/trusted-devices` | 8 |
| 39 | Service Requests | `/profile/service-requests` | 8 |
| 40 | Submit Change Request | `SubmitChangeRequestScreen` | 8 |
| 41 | Transparency Hub | `/transparency` | 5 |
| 42 | Fee Manual | `/fee-manual` | 4 |
| 43 | Session Idle Timeout | `SessionIdleWatcher` | 7 |
| 44 | Logout | Drawer / app bar | 6 |
| 45 | Device Revocation (Remote) | `currentDeviceRevokedProvider` | 5 |
| 46 | Language Toggle (EN/UR) & RTL | `language_provider.dart` | 8 |
| 47 | Theme (Light/Dark/Auto) | `theme_provider.dart` | 7 |
| 48 | Error & Loading States (Global) | Various | 8 |
| | **TOTAL** | | **399** |

---

## 1. Onboarding & Splash

**Description:** Cold-start splash animation and bootstrap before the main app shell loads.  
**Entry Point:** `lib/src/core/splash/splash_host.dart` → `PremiumSplashScreen`  
**Prerequisites:** App installed; Firebase initialized (`main.dart`).

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-001 | Splash displays on cold start | App not running | Launch app from launcher | Premium splash screen appears before home/auth | | |
| UA-002 | Splash transitions to auth when logged out | No Firebase session | Launch app | After splash, user reaches `/` AuthGate or `/login` | | |
| UA-003 | Splash transitions to investor shell when session valid | Valid session, device trusted, consent+KYC as required | Launch app | After splash, user reaches `/investor` or next gate (OTP/biometric) | | |
| UA-004 | Splash respects Urdu RTL direction | Language set to Urdu in prior session | Launch app | Splash and subsequent screens use RTL text direction | | |
| UA-005 | Firebase init failure shows error MaterialApp | Simulate Firebase init failure (test build) | Launch app | Fallback error `MaterialApp` from `main.dart` displays error message | | |
| UA-006 | FCM bootstrap runs after splash | Signed-in user, notifications permission available | Launch app, check logs/FCM token | `FcmBootstrap` registers without crash | | |
| UA-007 | Splash does not block indefinitely | Normal network | Launch app | Splash completes within reasonable time (<30s) | | |
| UA-008 | App resume from background skips full cold splash | App was backgrounded | Resume app | Returns to last route without full re-onboarding loop | | |

---

## 2. Connectivity Gate

**Description:** Blocks app usage when device has no network; shows retry screen.  
**Entry Point:** `lib/src/core/network/connectivity_gate.dart` → `NoInternetScreen`  
**Prerequisites:** App past splash.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-009 | Offline at launch shows No Internet screen | Airplane mode ON | Launch app | `NoInternetScreen` displayed instead of main content | | |
| UA-010 | Retry reconnects when network restored | Offline then online | Tap retry after enabling network | App proceeds to normal flow | | |
| UA-011 | Going offline mid-session shows gate | App open on `/investor` | Enable airplane mode | Connectivity gate or error state prevents silent failures | | |
| UA-012 | Online user never sees No Internet | Network available | Use app normally | Main content visible throughout | | |
| UA-013 | Retry button disabled/spinner while checking | Offline | Tap retry repeatedly | No crash; appropriate loading feedback | | |
| UA-014 | Urdu translation on No Internet screen | Language = Urdu | View offline screen | All labels in Urdu, RTL layout | | |

---

## 3. Force Update Gate

**Description:** Blocks investor app when installed APK version is below required minimum from `app_releases/current_android`.  
**Entry Point:** `/force-update` → `ForceUpdateScreen`  
**Prerequisites:** Firestore `app_releases` configured; Android device.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-015 | Outdated app redirected to force update | Installed version < min required | Open app | Router redirect to `/force-update`; cannot access `/investor` | | |
| UA-016 | Current app bypasses force update | Installed version ≥ required | Open app | Normal auth/home flow | | |
| UA-017 | Force update screen shows version info | Blocked user | View `/force-update` | Required version and update action visible | | |
| UA-018 | Update action triggers download/install flow | Blocked user, valid APK URL | Tap update button | APK download/install flow starts (`update_action.dart`) | | |
| UA-019 | Grace period respected if configured | Release doc has grace days | Open app within grace | User not blocked until grace expires | | |
| UA-020 | Unblocked user at `/force-update` redirected home | Current version | Navigate to `/force-update` manually | Redirect to `/` | | |
| UA-021 | Force update screen in Urdu | Language Urdu, blocked | View screen | RTL + translated strings | | |

---

## 4. Registration / Sign Up

**Description:** Email/password registration with profile name; routes to fingerprint setup.  
**Entry Point:** `/signup` → `SignupScreen`  
**Prerequisites:** No existing account for test email; network available.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-022 | Happy path registration | Valid unused email | Enter name, email, password (≥6); submit | Account created; navigates to `/setup-fingerprint` | | |
| UA-023 | Empty name validation | On signup form | Leave name empty; submit | Validation error; no account created | | |
| UA-024 | Invalid email (no @) | On signup form | Enter `testexample.com`; submit | Validation error for email | | |
| UA-025 | Password under 6 characters | On signup form | Enter password `12345`; submit | Validation error (min 6 chars) | | |
| UA-026 | Duplicate email registration | Email already registered | Register with same email | Firebase error shown; user stays on signup | | |
| UA-027 | Network failure during signup | Offline mid-submit | Submit valid form | Error dialog; no partial orphan state | | |
| UA-028 | Firestore profile created on signup | Successful signup | Check `users/{uid}` | Profile doc exists with default fields | | |
| UA-029 | Navigate to login from signup | On signup | Tap login link | Navigates to `/login` | | |
| UA-030 | Back navigation from signup | On signup | Press system back | Returns to previous screen without crash | | |
| UA-031 | Signup form dark mode | Theme = Dark | View and submit signup | Readable fields and validation in dark theme | | |
| UA-032 | Signup form Urdu RTL | Language = Urdu | View signup | RTL layout; translated labels | | |
| UA-033 | Loading state during signup | Valid data | Submit | Submit button disabled/busy until complete | | |

---

## 5. Login (Email/Password)

**Description:** Standard Firebase email/password login; optional biometric shortcut if enabled.  
**Entry Point:** `/login` → `LoginScreen`  
**Prerequisites:** Registered user exists.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-034 | Happy path login | Valid credentials | Enter email/password; login | Navigates to `/` AuthGate then investor flow | | |
| UA-035 | Wrong password | Valid email | Enter wrong password | Error message; remains on login | | |
| UA-036 | Unknown email | Non-existent email | Attempt login | Firebase auth error displayed | | |
| UA-037 | Empty email validation | On login | Submit empty email | Validation error | | |
| UA-038 | Password under 6 chars validation | On login | Enter short password | Validation error | | |
| UA-039 | Login alert callable invoked | Valid login | Login successfully | `sendInvestorLoginAlert` called (non-blocking) | | |
| UA-040 | Biometric shortcut when enabled | Biometric enabled, session exists | Open login | Biometric prompt available | | |
| UA-041 | Navigate to signup | On login | Tap signup link | Goes to `/signup` | | |
| UA-042 | Navigate to forgot password | On login | Tap forgot password | Goes to `/forgot-password` | | |
| UA-043 | Login loading state | Valid creds | Submit | Button busy; no double submit | | |

---

## 6. Forgot Password

**Description:** Sends Firebase password reset email.  
**Entry Point:** `/forgot-password` → `ForgotPasswordScreen`  
**Prerequisites:** Registered email.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-044 | Happy path reset email | Valid registered email | Enter email; submit | Success message; reset email sent | | |
| UA-045 | Invalid email format | On form | Enter invalid email | Validation error | | |
| UA-046 | Unregistered email | Unknown email | Submit | Firebase error shown appropriately | | |
| UA-047 | Back to login | On screen | Tap back/login link | Returns to `/login` | | |
| UA-048 | Offline reset attempt | Airplane mode | Submit | Error handling; no crash | | |

---

## 7. Auth Gate & Post-Login Routing

**Description:** Central router after login: OTP requirement, biometric gate, investor home.  
**Entry Point:** `/` → `AuthGateScreen`  
**Prerequisites:** Firebase authenticated user.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-049 | Unauthenticated user sent to login | No session | Open `/` | Redirect to `/login` | | |
| UA-050 | Trusted device skips OTP | Verified phone, device trusted | Open `/` | Proceeds to biometric check or `/investor` | | |
| UA-051 | Untrusted device sent to OTP | Verified phone, device not trusted | Open `/` | Redirect to `/login-otp?phone=` | | |
| UA-052 | Biometric enabled — success | Biometric on, capability available | Authenticate successfully | Navigate to `/investor` | | |
| UA-053 | Biometric enabled — user cancels | Biometric on | Cancel biometric prompt | Logout or return to `/login` per gate logic | | |
| UA-054 | Biometric unavailable auto-disables | Biometric on, no hardware | Open gate | Biometric disabled; proceed to `/investor` | | |
| UA-055 | No verified phone skips OTP | Phone not set | Open `/` | Skip OTP branch | | |
| UA-056 | Auth loading shows progress | Session restoring | Open `/` | Loading indicator until auth settles | | |
| UA-057 | Auth gate error state | Firestore security error | Open `/` | Error displayed; no infinite spinner | | |
| UA-058 | Re-entry after OTP completes | OTP just verified | Return to `/` | Proceeds without OTP loop | | |

---

## 8. Device Trust OTP

**Description:** Firebase Phone Auth SMS verification for untrusted devices.  
**Entry Point:** `/login-otp` → `LoginOtpChallengeScreen`  
**Prerequisites:** User has `security.verifiedPhone`; device not in `trustedDevices`.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-059 | OTP SMS sent on entry | Untrusted device | Land on login-otp | SMS flow initiated; masked phone shown | | |
| UA-060 | Happy path 6-digit OTP | Valid SMS code | Enter 6 digits; verify | `markDeviceTrusted` callable; navigate `/investor` | | |
| UA-061 | Invalid OTP code | Wrong code | Enter wrong 6 digits | Error message; device remains untrusted | | |
| UA-062 | OTP expiry after 180 seconds | Wait 180s | Enter code after expiry | Expiry UI; must resend | | |
| UA-063 | Resend cooldown 30 seconds | On OTP screen | Tap resend before 30s | Resend disabled or shows cooldown | | |
| UA-064 | Resend after cooldown | 30s elapsed | Tap resend | New SMS sent; timer resets | | |
| UA-065 | Non-6-digit input blocked | OTP field | Enter 5 or 7 digits | Length limit 6; validation error | | |
| UA-066 | OTP screen back cancels flow | On OTP | Press back | Returns without marking trusted | | |
| UA-067 | Network failure during verify | Offline at verify | Submit OTP | Error dialog; can retry | | |
| UA-068 | Trusted device doc created | Successful verify | Check Firestore | `users/{uid}/trustedDevices/{hash}` exists | | |

---

## 9. Biometric / Fingerprint Setup

**Description:** Optional post-signup biometric enrollment.  
**Entry Point:** `/setup-fingerprint` → `SetupFingerprintScreen`  
**Prerequisites:** Fresh signup or settings path.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-069 | Enable biometric happy path | Device supports biometrics | Complete setup flow | Biometric enabled in prefs; continue to app | | |
| UA-070 | Skip biometric setup | Post-signup | Tap skip | Proceeds without enabling biometric | | |
| UA-071 | Biometric unavailable on device | No biometric hardware | Open setup | Graceful skip or disable message | | |
| UA-072 | Failed biometric enrollment | User fails scan repeatedly | Attempt enable | Error message; remains disabled | | |
| UA-073 | Setup with email query param | Route `/setup-fingerprint?email=` | Open route | Screen loads with context | | |
| UA-074 | Biometric persists after restart | Biometric enabled | Kill and reopen app | Session gate prompts biometric | | |
| UA-075 | Disable biometric from profile later | Biometric enabled | Profile → disable | Biometric gate skipped on next login | | |
| UA-076 | Urdu RTL on setup screen | Language Urdu | View setup | RTL layout correct | | |

---

## 10. KYC Submission

**Description:** Full KYC form with CNIC, bank, nominee, document uploads; submits to Firestore/Storage.  
**Entry Point:** `/kyc` → `KycScreen`  
**Prerequisites:** Signed-in user; KYC not approved (or re-submit allowed).

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-077 | Happy path KYC submit | All required fields + images | Complete form; submit | `kyc/{uid}` status `underReview`; navigate `/investor` | | |
| UA-078 | CNIC too short | CNIC < 8 chars | Submit | Validation error | | |
| UA-079 | Phone required | Empty phone | Submit | Validation error on phone field | | |
| UA-080 | Address under 5 chars | Short address | Submit | Validation error | | |
| UA-081 | Bank dropdown required | No bank selected | Submit | Validation error | | |
| UA-082 | Nominee fields required | Empty nominee name/CNIC/relation | Submit | Validation errors | | |
| UA-083 | CNIC front/back/selfie required | Missing images | Submit | Validation prevents submit | | |
| UA-084 | Salaried payment proof requires salary slip | Type = salaried | Submit without slip | Validation error | | |
| UA-085 | Foreigner proof requires passport docs | Type = foreigner | Submit without passport | Validation error | | |
| UA-086 | Form locked when under review | kycStatus = underReview | Open KYC | Fields read-only/disabled | | |
| UA-087 | Form locked when approved | kycStatus = approved | Open KYC | Bank/nominee locked; service request hint | | |
| UA-088 | Image upload to Storage | Valid submission | Submit | Files at `deposit_proofs/{uid}/kyc_*` | | |
| UA-089 | KYC offline submit | Airplane mode | Submit | Error; no corrupt partial write | | |
| UA-090 | KYC Urdu RTL | Language Urdu | View form | RTL + translations | | |

---

## 11. Legal Consent

**Description:** Investor agreement acceptance required before full app access.  
**Entry Point:** `/legal` → `LegalConsentScreen`; enforced in `InvestorShellWithConsent`  
**Prerequisites:** Signed-in user; consent not yet recorded.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-091 | Consent overlay blocks shell | consentAccepted = false | Open `/investor` | Legal consent required before tabs | | |
| UA-092 | Happy path accept consent | On legal screen | Scroll paragraphs; check box; accept | `consents/{uid}` written; proceed to app | | |
| UA-093 | Cannot accept without checkbox | On legal | Tap accept without checkbox | Blocked or validation | | |
| UA-094 | Consent persists after restart | Consent accepted | Restart app | No consent overlay | | |
| UA-095 | Consent gate on `/market` | No consent | Navigate to `/market` | `ConsentGateScreen` blocks | | |
| UA-096 | Consent gate on `/transparency` | No consent | Navigate to `/transparency` | Blocked until consent | | |
| UA-097 | Legal screen Urdu | Language Urdu | View legal | RTL translated content | | |
| UA-098 | Consent loading state | Slow network | Open legal | Loading indicator until data loads | | |

---

## 12. KYC Approved Gate

**Description:** Wrapper blocking portfolio, wallet ops, reports until KYC approved.  
**Entry Point:** `KycApprovedGateScreen` on gated routes  
**Prerequisites:** Signed-in user.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-099 | Pending KYC blocks portfolio | kycStatus ≠ approved | Open `/portfolio` | Gate message with link to KYC | | |
| UA-100 | Approved KYC allows portfolio | kycStatus = approved | Open `/portfolio` | Portfolio screen loads | | |
| UA-101 | Deposit blocked without KYC | KYC pending | Open `/wallet-ledger/deposit` | Gate blocks access | | |
| UA-102 | Withdraw blocked without KYC | KYC pending | Open `/wallet-ledger/withdraw` | Gate blocks access | | |
| UA-103 | Reports blocked without KYC | KYC pending | Open `/reports` tab | Gate blocks access | | |
| UA-104 | Notifications blocked without KYC | KYC pending | Open `/notifications` | Gate blocks access | | |

---

## 13. Consent Gate

**Description:** Blocks market watch routes until legal consent accepted.  
**Entry Point:** `ConsentGateScreen`  
**Prerequisites:** Signed-in user.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-105 | Market overview requires consent | consent = false | Open `/market` | Consent gate shown | | |
| UA-106 | Gold chart requires consent | consent = false | Open `/market/gold` | Consent gate shown | | |
| UA-107 | KMI30 company chart requires consent | consent = false | Open company chart route | Consent gate shown | | |
| UA-108 | Consented user accesses market | consent = true | Open `/market` | Market overview loads | | |
| UA-109 | Gate links to legal screen | On gate | Tap accept/go to legal | Navigates to consent flow | | |

---

## 14. Dashboard / Home

**Description:** Main investor home with wallet summary, quick actions, KYC banner, navigation drawer.  
**Entry Point:** `/investor` → `UserHomeScreen`  
**Prerequisites:** Authenticated, past auth/consent gates.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-110 | Home loads wallet balance | Approved KYC, wallet exists | Open home tab | PKR balance displayed from `wallets/{uid}` | | |
| UA-111 | Mask/unmask balance toggle | Home loaded | Tap mask control | Balance hidden/shown | | |
| UA-112 | KYC banner for pending users | kycStatus pending | View home | Banner prompts KYC completion | | |
| UA-113 | Quick action — Deposit | KYC approved | Tap deposit | Navigates to deposit screen | | |
| UA-114 | Quick action — Withdraw | KYC approved | Tap withdraw | Navigates to withdrawal screen | | |
| UA-115 | Quick action — Portfolio | KYC approved | Tap portfolio | Navigates to `/portfolio` | | |
| UA-116 | Quick action — Live profit | KYC approved | Tap live profit | Navigates to `/profit-live` | | |
| UA-117 | One-time risk disclaimer dialog | First visit | Open home | Mandatory risk disclaimer shown once | | |
| UA-118 | Drawer navigation items | Home open | Open drawer | Links to profile, reports, logout, etc. | | |
| UA-119 | Home pull-to-refresh | Home open | Pull refresh | Data refreshes without crash | | |
| UA-120 | Home loading state | Slow wallet stream | Open home | Loading indicator until wallet loads | | |
| UA-121 | Home error state | Wallet stream error | Open home | Error message with retry path | | |

---

## 15. Investment Portfolio Overview

**Description:** Five-market allocation tabs with pie chart, performance metrics, links to market details.  
**Entry Point:** `/portfolio` → `InvestmentPortfolioScreen`  
**Prerequisites:** KYC approved; wallet funded.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-122 | Portfolio loads all five tabs | KYC approved | Open portfolio | Gold, Money, Stock, Tech, Debt tabs visible | | |
| UA-123 | Allocation pie chart renders | Portfolio data loaded | View chart | Percentages match `settings/five_market_calc` | | |
| UA-124 | Tap Gold tab opens gold detail | On portfolio | Tap gold row/tab | Navigates to `/five-market/gold` | | |
| UA-125 | Tap Stock tab opens stock detail | On portfolio | Tap stock | Navigates to `/five-market/stock` | | |
| UA-126 | Sleeve balances from live engine | Trading day | View allocations | Allocated PKR matches sleeve snapshot logic | | |
| UA-127 | Off-day pending profit zero | Non-trading day | View portfolio | Pending today = 0 when not trading day | | |
| UA-128 | Portfolio refresh | On screen | Pull refresh | Providers invalidated; data reloads | | |
| UA-129 | Portfolio loading state | Slow streams | Open portfolio | Loading indicators shown | | |
| UA-130 | Portfolio Urdu RTL | Language Urdu | View portfolio | RTL layout correct | | |
| UA-131 | Portfolio dark mode | Theme dark | View portfolio | Readable charts and text | | |

---

## 16. Digital Gold Market Detail

**Description:** Gold sleeve detail with allocation, profit, chart link.  
**Entry Point:** `/five-market/gold` → `GoldMarketDetailScreen`  
**Prerequisites:** KYC approved.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-132 | Gold detail loads sleeve data | Funded wallet | Open gold detail | Allocated PKR and display value shown | | |
| UA-133 | Gold change % on trading day | Trading day, gold quote live | View hero | Non-zero change when market moves | | |
| UA-134 | Gold change zeroed off-day | Non-trading day | View hero | Change % shows 0 | | |
| UA-135 | Sleeve report PDF download | On gold detail | Tap download report | PDF generated via `sleeve_report_pdf_builder` | | |
| UA-136 | Back navigation | On gold detail | Press back | Returns to portfolio/previous | | |
| UA-137 | Gold detail loading | Slow providers | Open screen | Loading state shown | | |
| UA-138 | Gold detail error | Provider error | Open screen | Error state handled | | |

---

## 17. Money Market Detail

**Description:** Money market sleeve with fixed accrual display.  
**Entry Point:** `/five-market/money` → `MoneyMarketDetailScreen`  
**Prerequisites:** KYC approved.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-139 | Money sleeve loads | Funded wallet | Open money detail | Allocation and balance shown | | |
| UA-140 | Withdrawable balance displayed | MM credits exist | View detail | Matches `moneyMarketAvailableFromWallet` | | |
| UA-141 | Fixed accrual label on trading day | Trading day, market hours | View profit | Accruing per second or realized label | | |
| UA-142 | No accrual off-day | Non-trading day | View profit | Zero / no accrual message | | |
| UA-143 | Sleeve PDF download | On screen | Download report | PDF generates successfully | | |
| UA-144 | Back navigation | On screen | Press back | Returns correctly | | |
| UA-145 | Urdu RTL on money detail | Language Urdu | View screen | RTL correct | | |
| UA-146 | Dark mode on money detail | Theme dark | View screen | Readable UI | | |

---

## 18. Stock / KMI30 Market Detail

**Description:** Stock sleeve tied to KMI30 index live tick and EOD snapshot.  
**Entry Point:** `/five-market/stock` → `StockMarketDetailScreen`  
**Prerequisites:** KYC approved.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-147 | Stock detail loads KMI30 tick | Trading day, PSX open | Open stock detail | Live change % from websocket tick | | |
| UA-148 | KMI30 zeroed off-day | Non-trading day | View stock detail | Change % = 0 | | |
| UA-149 | After PSX close uses EOD | Trading day, after 16:00 PKT | View stock detail | EOD snapshot change used | | |
| UA-150 | Friday prayer break frozen | Friday 12:00–14:30 PKT | View during break | Stock session frozen per `market_hours.dart` | | |
| UA-151 | Sleeve allocation display | Funded wallet | View detail | Stock allocated PKR shown | | |
| UA-152 | Sleeve PDF download | On screen | Download | PDF success | | |
| UA-153 | Loading/error states | Simulate slow/error | Open screen | Appropriate UI | | |
| UA-154 | Navigation back | On screen | Back | Returns to portfolio | | |
| UA-155 | Urdu on stock detail | Language Urdu | View | RTL + translations | | |

---

## 19. Tech Market Detail

**Description:** Tech benchmark sleeve with fixed daily accrual.  
**Entry Point:** `/five-market/tech` → `TechMarketDetailScreen`  
**Prerequisites:** KYC approved.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-156 | Tech detail loads | Funded wallet | Open tech detail | Allocation and annual rate shown | | |
| UA-157 | Intraday accrual during hours | Trading day, market open | View profit | Per-second accrual display | | |
| UA-158 | Off-day zero profit | Non-trading day | View profit | Zero accrual | | |
| UA-159 | Sleeve PDF download | On screen | Download | PDF success | | |
| UA-160 | Back navigation | On screen | Back | Returns correctly | | |
| UA-161 | Loading state | Slow data | Open | Spinner shown | | |
| UA-162 | Dark mode | Theme dark | View | Readable | | |

---

## 20. Debt Market Detail

**Description:** Debt sleeve with fixed annual accrual.  
**Entry Point:** `/five-market/debt` → `DebtMarketDetailScreen`  
**Prerequisites:** KYC approved.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-163 | Debt detail loads | Funded wallet | Open debt detail | Allocation shown | | |
| UA-164 | Accrual during market hours | Trading day open | View profit | Accruing display | | |
| UA-165 | Off-day zero | Non-trading day | View | Zero profit | | |
| UA-166 | PDF download | On screen | Download | Success | | |
| UA-167 | Back navigation | On screen | Back | Correct | | |
| UA-168 | Urdu RTL | Language Urdu | View | RTL OK | | |
| UA-169 | Error state | Stream error | Open | Error handled | | |

---

## 21. Live Profit (Daily/Monthly/Yearly)

**Description:** Tabbed live P&L with daily intraday, monthly/yearly period summaries.  
**Entry Point:** `/profit-live` → `LiveProfitScreen`  
**Prerequisites:** KYC approved; wallet balance > 0.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-170 | Daily tab shows live profit | Trading day, funded | Open daily tab | Per-market profit and total shown | | |
| UA-171 | Daily tab off-day banner | Non-trading day | View daily | Closed-day banner; zero profits | | |
| UA-172 | Daily countdown to close | Trading day | View status row | Countdown/market status accurate | | |
| UA-173 | Monthly tab calendar trading days | Mid-month | Open monthly tab | Primary count = calendar days elapsed | | |
| UA-174 | Monthly verified days secondary | Ledger docs exist | View monthly header | "X verified" credited days shown | | |
| UA-175 | Monthly loading spinner | History loading | Open monthly | Spinner until history+holidays load | | |
| UA-176 | Monthly ledger not ready card | No credited docs, loaded | View monthly | `_LedgerNotReadyCard`; wallet hero total | | |
| UA-177 | Yearly tab same patterns | Mid-year | Open yearly tab | Calendar + verified + charts when ledger ready | | |
| UA-178 | Pull refresh all tabs | On live profit | Pull refresh | Providers invalidated | | |
| UA-179 | No wallet data message | wallet balance 0 | Open screen | "No wallet data" message | | |
| UA-180 | Wallet loading gate | Wallet loading | Open screen | Full-screen spinner | | |
| UA-181 | Urdu on live profit | Language Urdu | View all tabs | RTL + translations | | |

---

## 22. Five Market Daily Screen

**Description:** Daily breakdown of five-market engine results.  
**Entry Point:** `/five-market-daily` → `FiveMarketDailyScreen`  
**Prerequisites:** KYC approved.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-182 | Daily screen loads today result | KYC approved | Open screen | Today's five-market breakdown shown | | |
| UA-183 | KMI30 hero off-day zero | Non-trading day | View KMI30 card | Change % = 0 | | |
| UA-184 | History list from ledger | Credited docs exist | View history section | Past days listed from `five_market_daily` | | |
| UA-185 | Pull refresh | On screen | Refresh | Data reloads | | |
| UA-186 | Trading day closed banner | Off-day | View | Closed day banner visible | | |
| UA-187 | Loading state | Slow streams | Open | Loading indicators | | |
| UA-188 | Back navigation | On screen | Back | Returns correctly | | |
| UA-189 | Dark mode | Theme dark | View | Readable | | |

---

## 23. KMI30 Companies Tab

**Description:** Bottom nav stocks tab listing KMI30 companies with live ticks.  
**Entry Point:** `/market/kmi30-companies` → `Kmi30CompaniesScreen`  
**Prerequisites:** Signed in (consent may apply for charts).

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-190 | Company list loads | Network available | Open Stocks tab | KMI30 companies listed | | |
| UA-191 | Live tick updates | Trading day PSX open | Watch list | Prices/change update | | |
| UA-192 | Off-day zero P/L on companies | Non-trading day | View list | Today P/L = 0 per company | | |
| UA-193 | Tap company opens chart | On list | Tap symbol | Navigates to company chart route | | |
| UA-194 | Hero header off-day message | Non-trading day | View header | Off-day messaging shown | | |
| UA-195 | List loading state | Slow Firestore | Open tab | Loading shown | | |
| UA-196 | List error state | Firestore error | Open tab | Error handled | | |
| UA-197 | Urdu RTL on stocks tab | Language Urdu | View tab | RTL correct | | |

---

## 24. Market Overview

**Description:** Consent-gated market watch landing.  
**Entry Point:** `/market` → `MarketOverviewScreen`  
**Prerequisites:** Consent accepted.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-198 | Overview loads | Consent + network | Open `/market` | Overview cards/links visible | | |
| UA-199 | Link to gold chart | On overview | Tap gold | Navigates to `/market/gold` | | |
| UA-200 | Link to KMI30 | On overview | Tap stocks | Navigates to companies | | |
| UA-201 | Blocked without consent | No consent | Open `/market` | Consent gate | | |
| UA-202 | Loading state | Slow data | Open | Spinner | | |
| UA-203 | Back navigation | On screen | Back | Correct stack | | |

---

## 25. Gold Price Chart

**Description:** Gold price chart screen.  
**Entry Point:** `/market/gold` → `GoldPriceChartScreen`  
**Prerequisites:** Consent accepted.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-204 | Chart loads gold quote | Consent + network | Open chart | Current price and chart render | | |
| UA-205 | Off-day change display | Non-trading day | View card | Change may show 0 on linked widgets | | |
| UA-206 | Chart interaction | Data loaded | Pan/zoom if supported | No crash | | |
| UA-207 | Loading state | Slow stream | Open | Loading shown | | |
| UA-208 | Error state | Quote stream fails | Open | Error message | | |
| UA-209 | Urdu RTL | Language Urdu | View | RTL OK | | |

---

## 26. KMI30 Company Chart

**Description:** Individual company OHLC chart.  
**Entry Point:** `/market/kmi30-companies/:symbol` → `Kmi30CompanyChartScreen`  
**Prerequisites:** Consent accepted.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-210 | Chart loads for valid symbol | Symbol in `market_companies` | Open route | Chart and bars render | | |
| UA-211 | Invalid symbol handling | Unknown symbol | Open route | Error/empty state | | |
| UA-212 | Daily bars from Firestore | Company has bars | View chart | Historical bars displayed | | |
| UA-213 | Back navigation | On chart | Back | Returns to list | | |
| UA-214 | Loading state | Slow fetch | Open | Spinner | | |
| UA-215 | Dark mode chart | Theme dark | View | Readable | | |

---

## 27. Wallet & Ledger

**Description:** Wallet summary, transaction list, history tab.  
**Entry Point:** `/wallet-ledger` → `WalletLedgerScreen`  
**Prerequisites:** KYC approved for full ops.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-216 | Wallet tab shows balances | KYC approved | Open wallet tab | Deposited, profit, MM totals shown | | |
| UA-217 | History tab groups by month | Transactions exist | Switch to history tab | Grouped transaction list | | |
| UA-218 | Tab query param `?tab=history` | Deep link | Open `/wallet-ledger?tab=history` | History tab selected | | |
| UA-219 | Deposit button navigation | KYC approved | Tap deposit | `/wallet-ledger/deposit` | | |
| UA-220 | Withdraw button navigation | KYC approved | Tap withdraw | `/wallet-ledger/withdraw` | | |
| UA-221 | Wallet loading state | Slow stream | Open | Loading indicator | | |
| UA-222 | Wallet error state | Stream error | Open | Error with message | | |
| UA-223 | Pull refresh | On ledger | Refresh | Data reloads | | |
| UA-224 | Urdu on wallet screen | Language Urdu | View | RTL + translations | | |
| UA-225 | Dark mode wallet | Theme dark | View | Readable balances | | |

---

## 28. Deposit Request

**Description:** Submit deposit with amount, payment method, optional proof image.  
**Entry Point:** `/wallet-ledger/deposit` → `DepositRequestScreen`  
**Prerequisites:** KYC approved.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-226 | Happy path deposit submit | Amount ≥100 PKR | Fill form; optional proof; submit | `createDepositRequest` success; snackbar; return | | |
| UA-227 | Minimum amount 100 PKR | On form | Enter 99 PKR | Validation `err_min_deposit` | | |
| UA-228 | Zero/empty amount | On form | Leave amount empty | Validation error | | |
| UA-229 | Invalid amount format | On form | Enter non-numeric | `err_amount_valid` | | |
| UA-230 | Payment method selection | On form | Select each method | Method sent in callable | | |
| UA-231 | Proof image optional | Valid amount | Submit without proof | Request created with null proofUrl | | |
| UA-232 | Proof image upload | Valid amount + image | Pick gallery image; submit | Storage upload; URL in request | | |
| UA-233 | Front-end load fee preview | Fee config loaded | Enter amount | Fee preview updates from `getFeeConfig` | | |
| UA-234 | Deposit bank instructions display | `settings/deposit_instructions` exists | View screen | Company bank details shown | | |
| UA-235 | KYC not approved blocked | KYC pending | Open deposit route | KYC gate blocks | | |
| UA-236 | Network failure on submit | Offline | Submit | Error dialog; not stuck busy | | |
| UA-237 | Busy state prevents double submit | Submitting | Tap submit twice | Only one request | | |
| UA-238 | Back navigation cancels | On form | Back without submit | No request created | | |
| UA-239 | Urdu deposit form | Language Urdu | View/submit | RTL + translations | | |

---

## 29. Withdrawal Request

**Description:** Withdraw from money-market available balance; MPIN if enabled.  
**Entry Point:** `/wallet-ledger/withdraw` → `WithdrawalRequestScreen`  
**Prerequisites:** KYC approved; MM balance > 0.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-240 | Happy path withdrawal | Amount ≤ MM available, MPIN ok | Enter amount; confirm MPIN if required; submit | `createWithdrawalRequest` success | | |
| UA-241 | Zero/invalid amount | On form | Enter 0 or invalid | `enter_valid_amount` error | | |
| UA-242 | Exceeds money market balance | MM available = X | Enter X+1 | `withdrawal_exceeds_money_market` | | |
| UA-243 | Wallet still loading | Wallet loading | Submit | `wallet_balance_still_loading` | | |
| UA-244 | Wallet error | Wallet stream error | Submit | `wallet_balance_unavailable` | | |
| UA-245 | MPIN prompt when enabled | MPIN enabled | Submit valid amount | `MpinPromptDialog` appears | | |
| UA-246 | MPIN cancel aborts withdrawal | MPIN dialog open | Cancel dialog | Withdrawal not submitted | | |
| UA-247 | Wrong MPIN | MPIN enabled | Enter wrong MPIN | `MPIN_WRONG` error | | |
| UA-248 | Locked MPIN | MPIN locked | Submit | `mpin_locked` message with time | | |
| UA-249 | No MPIN skips prompt | MPIN not set | Submit | Withdrawal proceeds without dialog | | |
| UA-250 | Server insufficient balance | Race condition | Submit edge amount | Server error handled | | |
| UA-251 | Busy state | Submitting | Double tap | Single request | | |
| UA-252 | KYC gate | KYC pending | Open withdraw | Blocked | | |
| UA-253 | Urdu withdrawal screen | Language Urdu | View | RTL OK | | |

---

## 30. Reports & PDF Generation

**Description:** Period reports, fee statements, admin-uploaded reports.  
**Entry Point:** `/reports` → `ReportsScreen`  
**Prerequisites:** KYC approved.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-254 | Reports screen loads | KYC approved | Open reports tab | Period presets and lists visible | | |
| UA-255 | This month PDF generate | Transactions exist | Select this month; generate | PDF built client-side; preview opens | | |
| UA-256 | This year PDF generate | Transactions exist | Select this year; generate | PDF with year range | | |
| UA-257 | Custom date range PDF | Valid range | Pick start/end; generate | PDF filtered to range | | |
| UA-258 | Empty period PDF | No transactions in range | Generate | PDF with empty/summary only | | |
| UA-259 | Fee statements list | Fee docs exist | View fee section | Lists `users/{uid}/fee_statements` | | |
| UA-260 | Admin uploaded reports | Reports in collection | View uploaded section | Filtered reports for user/all | | |
| UA-261 | KYC gate on reports | KYC pending | Open reports tab | Blocked | | |
| UA-262 | PDF save/share | PDF preview open | Save/share | `file_saver` / share works | | |
| UA-263 | Loading transactions | Slow stream | Open reports | Loading state | | |
| UA-264 | Error loading transactions | Stream error | Open | Error message | | |
| UA-265 | Urdu reports screen | Language Urdu | View | RTL OK | | |

---

## 31. Report PDF Preview

**Description:** In-app PDF preview before save.  
**Entry Point:** `ReportPdfPreviewScreen` (pushed from reports)  
**Prerequisites:** PDF bytes generated.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-266 | Preview renders PDF | PDF generated | Open preview | Pages render via printing package | | |
| UA-267 | Share from preview | Preview open | Tap share | OS share sheet | | |
| UA-268 | Save from preview | Preview open | Tap save | File saved to device | | |
| UA-269 | Back closes preview | Preview open | Back | Returns to reports | | |
| UA-270 | Large PDF performance | Many transactions | Preview | No OOM crash | | |
| UA-271 | Urdu PDF labels | Language Urdu | Generate preview | Translated headers where applicable | | |

---

## 32. Fee Statement Detail

**Description:** View individual monthly fee statement.  
**Entry Point:** `FeeStatementDetailScreen`  
**Prerequisites:** Fee statement doc exists.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-272 | Fee detail loads | Statement exists | Tap statement in list | Detail screen with amounts | | |
| UA-273 | Open PDF URL if present | Statement has pdfUrl | Tap open | External viewer opens | | |
| UA-274 | Missing PDF graceful | No pdfUrl | View detail | No crash | | |
| UA-275 | Back navigation | On detail | Back | Returns to reports | | |
| UA-276 | Loading state | Slow fetch | Open | Spinner | | |

---

## 33. Notifications

**Description:** In-app notification inbox with read state and deep links.  
**Entry Point:** `/notifications` → `NotificationsScreen`  
**Prerequisites:** KYC approved.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-277 | Notifications list loads | Docs in inbox | Open notifications | Up to 100 notifications shown | | |
| UA-278 | Tap marks as read | Unread notification | Tap item | `read` field updated | | |
| UA-279 | Mark all read | Multiple unread | Tap mark all | All marked read | | |
| UA-280 | Deep link open_wallet | Notification type open_wallet | Tap | Navigates to `/wallet-ledger` | | |
| UA-281 | Deep link open_portfolio | type open_portfolio | Tap | Navigates to `/portfolio` | | |
| UA-282 | Empty inbox | No notifications | Open | Empty state message | | |
| UA-283 | Loading state | Slow stream | Open | Spinner | | |
| UA-284 | Error state | Stream error | Open | Error message | | |
| UA-285 | KYC gate | KYC pending | Open | Blocked | | |

---

## 34. App Updates (Optional)

**Description:** View release notes and optional APK update.  
**Entry Point:** `/app-updates` → `AppUpdatesScreen`  
**Prerequisites:** Android device for APK install.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-286 | Updates screen loads | Signed in | Open app updates | Current release info shown | | |
| UA-287 | New version available banner | Newer APK in Firestore | View screen | Update available UI | | |
| UA-288 | Download and install APK | Update available | Tap update | Download + install flow | | |
| UA-289 | Acknowledge release | On screen | Acknowledge | Preference saved | | |
| UA-290 | No update needed | Current version latest | View | Up to date message | | |
| UA-291 | Release history list | History docs exist | Scroll history | Past releases listed | | |
| UA-292 | Loading state | Slow Firestore | Open | Spinner | | |
| UA-293 | Urdu updates screen | Language Urdu | View | RTL OK | | |

---

## 35. Investor Profile & Settings

**Description:** Profile view, theme, language, security, KYC badge, logout entry.  
**Entry Point:** `/profile` → `InvestorProfileScreen`  
**Prerequisites:** Signed in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-294 | Profile loads user data | Signed in | Open profile tab | Name, email, phone, KYC badge | | |
| UA-295 | Theme toggle Light | Any | Select Light | App uses light theme | | |
| UA-296 | Theme toggle Dark | Any | Select Dark | Dark theme applied | | |
| UA-297 | Theme toggle Auto | Any | Select Auto | Light 7am–9pm PKT approx | | |
| UA-298 | Language English | Any | Select English | LTR; English strings | | |
| UA-299 | Language Urdu | Any | Select Urdu | RTL; Urdu font; translated strings | | |
| UA-300 | Navigate trusted devices | On profile | Tap trusted devices | `/profile/trusted-devices` | | |
| UA-301 | Navigate service requests | On profile | Tap service requests | `/profile/service-requests` | | |
| UA-302 | MPIN section visible | On profile | View security | Setup/change/toggle MPIN options | | |
| UA-303 | Biometric toggle | Device supports | Enable/disable | Preference persisted | | |
| UA-304 | KYC link from profile | KYC not approved | Tap KYC | Navigates to `/kyc` | | |
| UA-305 | Submit change request entry | Approved KYC | Tap submit change | Opens `SubmitChangeRequestScreen` | | |
| UA-306 | Profile loading | Slow stream | Open | Loading indicator | | |
| UA-307 | Profile persists theme after restart | Theme changed | Restart app | Theme retained from SharedPreferences | | |

---

## 36. MPIN Setup & Change

**Description:** 4-digit MPIN lifecycle via Cloud Functions.  
**Entry Point:** `/mpin/setup`, `/mpin/change` → `MpinSetupScreen`  
**Prerequisites:** Signed in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-308 | Setup happy path | No MPIN | Enter 4 digits; confirm | `setMpin` success | | |
| UA-309 | Setup mismatch reset | Setup flow | Enter different confirm | Reset to step 1 | | |
| UA-310 | Non-numeric rejected | Setup | Enter letters | Validation error | | |
| UA-311 | Change requires current PIN | MPIN exists | Change flow | Current PIN step first | | |
| UA-312 | Wrong current PIN on change | MPIN exists | Wrong current | `MPIN_WRONG` error | | |
| UA-313 | Enable/disable toggle | MPIN set | Toggle in profile | `setMpinEnabled` called | | |
| UA-314 | Remove MPIN | MPIN set | Remove with password reauth | `clearMpin` success | | |
| UA-315 | Forgot MPIN via password | MPIN set | Use forgot flow | Reauth + reset path | | |
| UA-316 | Locked MPIN message | Too many failures | Attempt verify | Lock message with time | | |
| UA-317 | MPIN persists after restart | MPIN set | Restart | Status still has MPIN | | |
| UA-318 | Urdu MPIN screens | Language Urdu | Setup/change | RTL OK | | |
| UA-319 | Network error on setMpin | Offline | Submit | Error dialog | | |

---

## 37. MPIN on Withdrawal

**Description:** MPIN gate specifically on withdrawal flow.  
**Entry Point:** `MpinPromptDialog` from withdrawal screen  
**Prerequisites:** MPIN enabled.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-320 | Dialog non-dismissible | MPIN required | Tap outside | Dialog stays (barrierDismissible false) | | |
| UA-321 | Correct MPIN proceeds | Valid MPIN | Enter correct | Withdrawal submits | | |
| UA-322 | Wrong MPIN shows error | Valid session | Wrong PIN | Error; can retry | | |
| UA-323 | Cancel returns null | Dialog open | Cancel | Withdrawal aborted | | |
| UA-324 | Keypad entry 4 digits | Dialog open | Enter via keypad | 4 dots filled | | |
| UA-325 | Locked MPIN blocks before dialog | MPIN locked | Submit withdraw | Error before dialog | | |
| UA-326 | MPIN not enabled skips | MPIN disabled | Submit withdraw | No dialog | | |
| UA-327 | Urdu MPIN dialog | Language Urdu | Open dialog | RTL keypad | | |

---

## 38. Trusted Devices

**Description:** List and revoke trusted devices.  
**Entry Point:** `/profile/trusted-devices` → `TrustedDevicesScreen`  
**Prerequisites:** Verified phone; multiple devices for revoke test.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-328 | Device list loads | Trusted devices exist | Open screen | List from `trustedDevices` subcollection | | |
| UA-329 | Current device indicated | Multiple devices | View list | Current device marked | | |
| UA-330 | Revoke other device | Two devices | Revoke non-current | `removeTrustedDevice` success | | |
| UA-331 | Revoke requires MPIN if enabled | MPIN on | Revoke | MPIN prompt if required | | |
| UA-332 | Revoked device forced logout | Other device revoked | On revoked device | Auto logout via listener | | |
| UA-333 | Empty list state | Single device only | View | Appropriate UI | | |
| UA-334 | Loading state | Slow stream | Open | Spinner | | |
| UA-335 | Urdu trusted devices | Language Urdu | View | RTL OK | | |

---

## 39. Service Requests

**Description:** View submitted profile/bank/nominee change tickets.  
**Entry Point:** `/profile/service-requests` → `ServiceRequestsScreen`  
**Prerequisites:** Signed in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-336 | Request list loads | Requests exist | Open screen | Tickets from `changeRequests` | | |
| UA-337 | Pending status displayed | Pending ticket | View item | Status pending shown | | |
| UA-338 | Approved status displayed | Approved ticket | View item | Status approved | | |
| UA-339 | Rejected with reason | Rejected ticket | View item | Rejection reason visible | | |
| UA-340 | Empty list | No requests | Open | Empty state | | |
| UA-341 | Navigate to submit new | On screen | Tap submit | Opens submit screen | | |
| UA-342 | Loading state | Slow query | Open | Spinner | | |
| UA-343 | Urdu service requests | Language Urdu | View | RTL OK | | |

---

## 40. Submit Change Request

**Description:** Submit profile/phone/bank/nominee change for admin approval.  
**Entry Point:** `SubmitChangeRequestScreen` (from profile)  
**Prerequisites:** KYC approved for bank/nominee changes.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-344 | Submit profile name change | Approved KYC | Change name; submit | Ticket created pending | | |
| UA-345 | Submit phone change | Approved KYC | Change phone; submit | Ticket created | | |
| UA-346 | Submit bank change | Approved KYC | Change bank fields; submit | Ticket created | | |
| UA-347 | Submit nominee change | Approved KYC | Change nominee; submit | Ticket created | | |
| UA-348 | Pending request locks fields | Pending ticket exists | Open profile fields | Locked per `pendingProfileChanges` | | |
| UA-349 | Validation empty required | On form | Submit empty | Validation errors | | |
| UA-350 | Network error on submit | Offline | Submit | Error dialog | | |
| UA-351 | Success navigates back | Valid submit | Submit | Success message; pop screen | | |

---

## 41. Transparency Hub

**Description:** Founder performance / transparency content.  
**Entry Point:** `/transparency` → `TransparencyHubScreen`  
**Prerequisites:** Consent accepted.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-352 | Hub loads with consent | Consent true | Open `/transparency` | Content displayed | | |
| UA-353 | Blocked without consent | Consent false | Open route | Consent gate | | |
| UA-354 | External links open | Links present | Tap link | Browser opens | | |
| UA-355 | Back navigation | On hub | Back | Returns correctly | | |
| UA-356 | Urdu transparency | Language Urdu | View | RTL OK | | |

---

## 42. Fee Manual

**Description:** Static fee schedule documentation for investors.  
**Entry Point:** `/fee-manual` → `FeeManualScreen`  
**Prerequisites:** Signed in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-357 | Fee manual loads | Signed in | Open fee manual | Fee sections displayed | | |
| UA-358 | Scroll long content | On screen | Scroll | No overflow errors | | |
| UA-359 | Urdu fee manual | Language Urdu | View | RTL translated content | | |
| UA-360 | Back navigation | On screen | Back | Returns correctly | | |

---

## 43. Session Idle Timeout

**Description:** Auto-logout after 3 minutes idle for investors.  
**Entry Point:** `SessionIdleWatcher` (app wrapper)  
**Prerequisites:** Signed-in investor (not admin/crm staff role).

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-361 | Idle 3 min logs out | Investor session | No touch 3 minutes | Logout; snackbar `session_timeout_snackbar`; `/login` | | |
| UA-362 | Touch resets timer | Investor session | Touch at 2:50 | Timer resets; no logout at 3:00 | | |
| UA-363 | Background resume idle logout | App backgrounded 3+ min | Resume app | Auto logout if idle threshold met | | |
| UA-364 | Background resume within window | Background <3 min idle | Resume | Session continues | | |
| UA-365 | Admin role excluded | User role admin | Idle 3 min | No auto logout (staff excluded) | | |
| UA-366 | Logged out user no timer | On login screen | Wait 3 min | No erroneous logout | | |
| UA-367 | Urdu timeout snackbar | Language Urdu | Trigger timeout | Urdu snackbar message | | |

---

## 44. Logout

**Description:** Manual sign-out from drawer/app bar.  
**Entry Point:** Drawer in `UserHomeScreen`; `app_bar_actions.dart`  
**Prerequisites:** Signed in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-368 | Manual logout happy path | Signed in | Tap logout; confirm | Firebase signOut; navigate login | | |
| UA-369 | Device trust preserved on logout | Trusted device | Logout; login again | OTP may still be required per device state | | |
| UA-370 | Logout clears sensitive UI | Was on wallet | Logout | Cannot navigate back to wallet without auth | | |
| UA-371 | Logout during form entry | On deposit form | Logout from drawer | Form cleared; session ended | | |
| UA-372 | Logout error handling | Simulate signOut error | Logout | Error shown; graceful state | | |
| UA-373 | Urdu logout confirmation | Language Urdu | Logout | Translated confirm dialog | | |

---

## 45. Device Revocation (Remote)

**Description:** Forced logout when admin/user revokes current device.  
**Entry Point:** `currentDeviceRevokedProvider` in auth flow  
**Prerequisites:** Two devices; revoke from trusted devices.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-374 | Revoked device auto logout | Device A active | Revoke A from device B | A logs out automatically | | |
| UA-375 | Revoked device sent to login | After revoke | On device A | `/login` shown | | |
| UA-376 | Re-trust requires OTP | After revoke | Login on A | OTP challenge required | | |
| UA-377 | Non-revoked device unaffected | Two devices | Revoke A only | B session continues | | |
| UA-378 | Revoke listener no crash | Rapid revoke | Revoke while navigating | No crash | | |

---

## 46. Language Toggle (EN/UR) & RTL

**Description:** App-wide locale switching with RTL for Urdu.  
**Entry Point:** `language_provider.dart`; profile settings  
**Prerequisites:** Signed in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-379 | Switch to Urdu | English active | Profile → Urdu | Immediate RTL; Urdu strings | | |
| UA-380 | Switch to English | Urdu active | Profile → English | LTR; English strings | | |
| UA-381 | Language persists restart | Urdu selected | Kill app; reopen | Urdu retained from SharedPreferences | | |
| UA-382 | RTL on home screen | Urdu | View home | Layout mirrored correctly | | |
| UA-383 | RTL on forms | Urdu | View KYC/deposit | Fields align RTL | | |
| UA-384 | Urdu font applied | Urdu | View text | Urdu font from theme | | |
| UA-385 | trParams placeholders | Urdu | View MPIN locked msg | Placeholders render correctly | | |
| UA-386 | Numbers/currency LTR in Urdu | Urdu | View PKR amounts | Amounts readable | | |

---

## 47. Theme (Light/Dark/Auto)

**Description:** Theme mode selection with auto day/night window.  
**Entry Point:** `theme_provider.dart`; profile  
**Prerequisites:** Signed in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-387 | Light theme colors | Light selected | View screens | Light `AppTheme` colors | | |
| UA-388 | Dark theme colors | Dark selected | View screens | Dark theme; readable contrast | | |
| UA-389 | Auto theme daytime | Auto; time 10:00 PKT | View app | Light theme active | | |
| UA-390 | Auto theme nighttime | Auto; time 22:00 PKT | View app | Dark theme active | | |
| UA-391 | Theme persists restart | Dark selected | Restart | Dark retained | | |
| UA-392 | Charts readable dark | Dark + portfolio | View charts | No invisible segments | | |
| UA-393 | Theme independent of language | Urdu + Dark | View | Both apply correctly | | |

---

## 48. Error & Loading States (Global)

**Description:** Cross-cutting error dialogs, connectivity, async gates.  
**Entry Point:** `app_error_dialog.dart`, various providers  
**Prerequisites:** Signed in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| UA-394 | showAppErrorDialog displays | Trigger server error | Cause callable failure | Modal with message | | |
| UA-395 | Error dialog dismiss | Dialog open | Tap OK | Dialog closes | | |
| UA-396 | AsyncValue loading spinners | Slow Firestore | Open gated screens | Spinners not blank screens | | |
| UA-397 | AsyncValue error retry | Stream error | View error UI | User can navigate away/retry | | |
| UA-398 | Firebase Auth token refresh | Long session | Use app 1hr+ | Firestore streams reconnect via token refresh | | |
| UA-399 | Signed-out Firestore streams empty | Logged out | Observe providers | `authBoundFirestoreStream` returns empty defaults | | |

---

*End of QA_UserApp.md — 399 test cases (UA-001 through UA-399)*
