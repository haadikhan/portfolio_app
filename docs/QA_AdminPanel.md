# QA Document — Amanah Multi Asset Portfolio (Admin Panel)

**Platform:** Flutter admin web app (`lib/admin_main.dart` → `WakalatAdminApp`)  
**Router:** `go_router` in `lib/src/admin/admin_app.dart`  
**Legacy mobile admin:** Embedded routes in investor app (`/admin`, `/admin/finance`)  
**Document version:** 1.0  
**Prepared from codebase scan:** 2026-06-21

---

## Legend

| Status | Meaning |
|--------|---------|
| **Pass** | Actual result matches expected result |
| **Fail** | Actual result does not match expected result |
| **Blocked** | Test cannot be executed (environment, data, or dependency unavailable) |
| **N/A** | Test case does not apply to current build, platform, or role |

**Notes column:** Record browser, admin UID, investor UID, transaction ID, Firestore doc path, or defect ticket.

---

## Summary Table — All Modules

| # | Module | Entry Point | Total TCs |
|---|--------|-------------|-----------|
| 1 | Admin Login & Auth | `/login` | 10 |
| 2 | Forgot Password (Admin) | `/forgot-password` | 4 |
| 3 | Role-Based Routing (Admin vs CRM) | `admin_app.dart` redirects | 8 |
| 4 | Admin Dashboard / Overview | `/dashboard` | 10 |
| 5 | KYC Review — List | `/kyc` | 8 |
| 6 | KYC Review — Detail | `/kyc/:userId` | 10 |
| 7 | Deposits Queue | `/deposits` | 12 |
| 8 | Deposit Settings | `/deposit-settings` | 8 |
| 9 | Withdrawals Queue | `/withdrawals` | 10 |
| 10 | Change Requests (Service Requests) | `/change-requests` | 10 |
| 11 | Investor Management — List | `/investors` | 10 |
| 12 | Investor Management — Detail | `/investors/:userId` | 14 |
| 13 | Returns / Profit Rates / NAV | `/returns` | 10 |
| 14 | Five Market Admin | `/five-market` | 14 |
| 15 | Fee Configuration | `/fees` | 10 |
| 16 | Earnings Dashboard | `/earnings` | 6 |
| 17 | Company Fee Ledger | `/fee-ledger` | 7 |
| 18 | Market Data Admin (PSX Companies) | `/market` | 9 |
| 19 | Upload Investor Reports (PDF) | `/upload-reports` | 8 |
| 20 | App Update Management | `/app-updates` | 10 |
| 21 | Admin Notifications Inbox | `/notifications` | 6 |
| 22 | Broadcast Announcements | `/broadcast` | 8 |
| 23 | CRM Dashboard | `/crm` | 6 |
| 24 | CRM Investor List | `/crm/investors` | 7 |
| 25 | CRM Investor Detail | `/crm/investors/:userId` | 8 |
| 26 | CRM Team Management | `/crm/team` | 8 |
| 27 | Admin Shell Navigation | `AdminShell` drawer/rail | 6 |
| 28 | Legacy Embedded Admin Dashboard | `/admin` (investor app) | 5 |
| 29 | Legacy Finance Console | `/admin/finance` (investor app) | 10 |
| 30 | Firestore Rules & Access Control | `firebase/firestore.rules` | 12 |
| | **TOTAL** | | **257** |

---

## 1. Admin Login & Auth

**Description:** Email/password login for staff with role verification (`admin` or `crm`).  
**Entry Point:** `/login` → `lib/src/admin/screens/admin_login_screen.dart`  
**Prerequisites:** Staff account in Firebase Auth; `users/{uid}.role` set.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-001 | Admin happy path login | role=admin | Enter valid email/password; sign in | Redirect to `/dashboard` | | |
| AP-002 | CRM happy path login | role=crm | Sign in | Redirect to `/crm` | | |
| AP-003 | Investor role denied | role=investor or empty | Attempt admin login | Access denied; signed out or error | | |
| AP-004 | Invalid password | Admin account | Wrong password | Error message; stay on login | | |
| AP-005 | Invalid email format | On login | Email without `@` | Validation error | | |
| AP-006 | Password under 6 chars | On login | Short password | Validation error | | |
| AP-007 | Session resume redirect admin | Previously logged admin | Reload app | Auto redirect to `/dashboard` | | |
| AP-008 | Session resume redirect CRM | Previously logged CRM | Reload app | Auto redirect to `/crm` | | |
| AP-009 | App Check retry on web | Web admin | Login with App Check | Login succeeds or retries per bootstrap | | |
| AP-010 | Logout from admin shell | Logged in admin | Sign out | Redirect to `/login` | | |

---

## 2. Forgot Password (Admin)

**Description:** Password reset for staff accounts.  
**Entry Point:** `/forgot-password` → `ForgotPasswordScreen`  
**Prerequisites:** Registered staff email.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-011 | Reset email sent | Valid staff email | Submit email | Success message | | |
| AP-012 | Invalid email | On form | Bad format | Validation error | | |
| AP-013 | Unknown email | Unregistered | Submit | Firebase error | | |
| AP-014 | Return to login | On screen | Back link | `/login` | | |

---

## 3. Role-Based Routing (Admin vs CRM)

**Description:** GoRouter redirects and nav visibility by role.  
**Entry Point:** `lib/src/admin/admin_app.dart`, `admin_role_refresh.dart`  
**Prerequisites:** Admin and CRM test accounts.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-015 | CRM blocked from `/dashboard` | CRM logged in | Navigate to `/dashboard` | Redirect to `/crm` or access denied | | |
| AP-016 | CRM blocked from `/investors` | CRM logged in | Navigate to `/investors` | Blocked/redirect | | |
| AP-017 | Admin can access all admin routes | Admin logged in | Open KYC, deposits, fees | Screens load | | |
| AP-018 | CRM can access `/crm/*` | CRM logged in | Open CRM routes | Screens load | | |
| AP-019 | CRM can access `/notifications` | CRM logged in | Open notifications | Admin shell notifications load | | |
| AP-020 | Unauthenticated `/dashboard` redirect | Logged out | Open `/dashboard` | Redirect `/login` | | |
| AP-021 | Admin cannot access CRM-only data scope | Admin | View CRM assignments | Admin sees full investor list not CRM-scoped | | |
| AP-022 | Role change mid-session | Change role in Firestore | Refresh/navigate | Routing updates per new role | | |

---

## 4. Admin Dashboard / Overview

**Description:** Ops overview with user/KYC counts and transaction aggregates.  
**Entry Point:** `/dashboard` → `admin_dashboard_screen.dart`  
**Prerequisites:** Admin logged in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-023 | Dashboard loads stats | Admin session | Open dashboard | User count, pending KYC, txn stats visible | | |
| AP-024 | Pending KYC count accurate | Known underReview KYC docs | Compare count | Matches Firestore `kyc` query | | |
| AP-025 | Pending deposits count | Pending deposit txns exist | View card | Count matches `transactions` filter | | |
| AP-026 | Quick nav to KYC | On dashboard | Tap KYC shortcut | Navigates `/kyc` | | |
| AP-027 | Quick nav to deposits | On dashboard | Tap deposits | Navigates `/deposits` | | |
| AP-028 | Quick nav to withdrawals | On dashboard | Tap withdrawals | Navigates `/withdrawals` | | |
| AP-029 | repairUserBalances callable | Admin on dashboard | Run repair tool | Callable completes; success/error shown | | |
| AP-030 | setStorageCors callable | Admin on dashboard | Run CORS tool | Callable result displayed | | |
| AP-031 | Dashboard loading state | Slow Firestore | Open dashboard | Loading indicators | | |
| AP-032 | Dashboard error state | Firestore error | Open | Error message | | |

---

## 5. KYC Review — List

**Description:** Queue of KYC submissions with status `underReview`.  
**Entry Point:** `/kyc` → `admin_kyc_list_screen.dart`  
**Prerequisites:** Admin logged in; pending KYC exists.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-033 | KYC list loads queue | underReview docs | Open `/kyc` | List shows pending items with name/phone | | |
| AP-034 | Empty queue message | No underReview | Open list | Empty state | | |
| AP-035 | Tap item opens detail | Items in list | Tap row | Navigates `/kyc/:userId` | | |
| AP-036 | List refreshes on return | After approve/reject | Return to list | Approved item removed from queue | | |
| AP-037 | List loading state | Slow query | Open | Spinner | | |
| AP-038 | List error state | Permission error | Open | Error displayed | | |
| AP-039 | Search/filter if present | Large queue | Use search | Results filter correctly | | |
| AP-040 | Real-time update new submission | New KYC submitted | Watch list | New item appears | | |

---

## 6. KYC Review — Detail

**Description:** Review KYC fields, images; approve or reject.  
**Entry Point:** `/kyc/:userId` → `admin_kyc_detail_screen.dart`  
**Prerequisites:** KYC doc underReview for userId.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-041 | Detail loads all KYC fields | Valid userId | Open detail | CNIC, bank, nominee, docs shown | | |
| AP-042 | Document images render | Storage URLs valid | View images | CNIC front/back/selfie load | | |
| AP-043 | Approve KYC happy path | underReview | Tap approve; confirm | `kyc` + `users.kycStatus` = approved | | |
| AP-044 | Reject requires reason | underReview | Tap reject; empty reason | Reject disabled or validation | | |
| AP-045 | Reject with reason | underReview | Enter reason; reject | status=rejected; reason saved; users synced | | |
| AP-046 | Investor notified on approve | Approve flow | Check investor inbox | Notification created (if trigger configured) | | |
| AP-047 | Broken image URL handling | Invalid URL | View detail | Placeholder/error per UI | | |
| AP-048 | Invalid userId route | Bad userId | Open `/kyc/badid` | Error/not found state | | |
| AP-049 | Back to list | On detail | Back | Returns to KYC list | | |
| AP-050 | Concurrent approve race | Two admins | Both approve same | One succeeds; no corrupt state | | |

---

## 7. Deposits Queue

**Description:** Review and approve/reject investor deposit requests from `transactions`.  
**Entry Point:** `/deposits` → `admin_deposits_queue_screen.dart`  
**Prerequisites:** Admin logged in; pending deposits exist.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-051 | Deposits queue loads | Pending deposits | Open `/deposits` | Transactions listed | | |
| AP-052 | Tab filter All | Mixed statuses | Select All tab | All deposit types shown | | |
| AP-053 | Tab filter Pending | Pending exist | Pending tab | Only pending | | |
| AP-054 | Tab filter Approved | Approved exist | Approved tab | Only approved | | |
| AP-055 | Tab filter Rejected | Rejected exist | Rejected tab | Only rejected | | |
| AP-056 | View proof image | Deposit with proofUrl | Open tile | Image displays | | |
| AP-057 | Fee estimate shown | Pending deposit | View tile | `estimateDepositFee` preview | | |
| AP-058 | Approve deposit happy path | Pending deposit | Confirm approve | `adminApproveTransaction` success; wallet credited server-side | | |
| AP-059 | Reject deposit with note | Pending deposit | Reject with optional note | `adminRejectTransaction`; status rejected | | |
| AP-060 | Approve confirmation dialog | Pending | Tap approve | Confirmation before callable | | |
| AP-061 | Queue real-time update | New deposit submitted | Watch queue | New item appears | | |
| AP-062 | CRM user blocked | CRM role | Open `/deposits` | Access denied | | |

---

## 8. Deposit Settings

**Description:** Configure company bank details shown to investors.  
**Entry Point:** `/deposit-settings` → `admin_deposit_settings_screen.dart`  
**Prerequisites:** Admin logged in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-063 | Load existing settings | Doc exists | Open screen | Fields populated from `settings/deposit_instructions` | | |
| AP-064 | Save valid settings | On form | Fill bank name, holder, IBAN ≥10; save | Firestore updated | | |
| AP-065 | Bank name required | Empty bank name | Save | Validation error | | |
| AP-066 | Account holder required | Empty holder | Save | Validation error | | |
| AP-067 | IBAN min 10 chars | Short IBAN | Save | Validation error | | |
| AP-068 | Live preview card updates | Editing form | Type fields | Preview reflects input | | |
| AP-069 | Investor app sees updated instructions | After save | Investor deposit screen | New bank details shown | | |
| AP-070 | Save error handling | Offline | Save | Error message | | |

---

## 9. Withdrawals Queue

**Description:** Approve/reject withdrawal requests.  
**Entry Point:** `/withdrawals` → `admin_withdrawals_queue_screen.dart`  
**Prerequisites:** Admin logged in; pending withdrawals.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-071 | Withdrawals queue loads | Pending withdrawals | Open `/withdrawals` | List displayed | | |
| AP-072 | Status tabs filter | Mixed statuses | Switch tabs | Correct filtering | | |
| AP-073 | Approve withdrawal happy path | Pending withdrawal | Approve | `adminApproveTransaction`; MM balance adjusted server-side | | |
| AP-074 | Reject withdrawal | Pending | Reject with note | Status rejected; funds remain | | |
| AP-075 | Confirmation before approve | Pending | Tap approve | Dialog confirmation | | |
| AP-076 | Real-time queue update | New withdrawal | Watch list | Appears live | | |
| AP-077 | Insufficient balance server reject | Edge case data | Approve invalid | Callable error surfaced | | |
| AP-078 | Loading state | Slow stream | Open | Spinner | | |
| AP-079 | CRM blocked from withdrawals | CRM role | Open route | Denied | | |
| AP-080 | Back navigation | On queue | Back | Shell intact | | |

---

## 10. Change Requests (Service Requests)

**Description:** Approve/reject investor profile/bank/nominee change tickets.  
**Entry Point:** `/change-requests` → `admin_change_requests_screen.dart`  
**Prerequisites:** Pending changeRequests exist.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-081 | Change request list loads | Pending tickets | Open screen | Collection-group list shown | | |
| AP-082 | Pending tab filter | Mixed statuses | Pending tab | Only pending | | |
| AP-083 | Approve merges fields to user | Pending profile change | Approve | `users/{uid}` updated with requestedFields | | |
| AP-084 | Approve creates notification | Approve | Check inbox | Investor notification written | | |
| AP-085 | Reject requires note | Pending | Reject empty note | Validation/block | | |
| AP-086 | Reject with note | Pending | Reject with reason | Ticket rejected; investor notified | | |
| AP-087 | Pending profile lock cleared | After approve/reject | Investor profile | `pendingProfileChanges` cleared | | |
| AP-088 | All tab shows history | Closed tickets | All tab | Historical tickets visible | | |
| AP-089 | CRM blocked | CRM role | Open route | Denied | | |
| AP-090 | Real-time new request | Investor submits | Watch list | New ticket appears | | |

---

## 11. Investor Management — List

**Description:** Searchable list of all investors with five-market ledger toggle.  
**Entry Point:** `/investors` → `admin_investor_list_screen.dart`  
**Prerequisites:** Admin logged in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-091 | Investor list loads | Investors exist | Open `/investors` | Non-staff users listed | | |
| AP-092 | Search by name | Known investor | Search name | Filtered results | | |
| AP-093 | Search by email | Known email | Search | Match found | | |
| AP-094 | Search by phone | Known phone | Search | Match found | | |
| AP-095 | Tap opens detail | List loaded | Tap investor | `/investors/:userId` | | |
| AP-096 | Toggle five-market daily ledger | On list tile | Toggle ledger flag | `setFiveMarketDailyLedger` callable invoked | | |
| AP-097 | Staff users excluded | admin/crm users | View list | Staff not in investor list | | |
| AP-098 | Empty search results | No match | Search nonsense | Empty state | | |
| AP-099 | List loading | Slow fetch | Open | Spinner | | |
| AP-100 | CRM blocked from full list | CRM role | Open `/investors` | Denied | | |

---

## 12. Investor Management — Detail

**Description:** Full investor profile, wallet, transactions, fee version, referral, delete.  
**Entry Point:** `/investors/:userId` → `admin_investor_detail_screen.dart`  
**Prerequisites:** Valid investor userId.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-101 | Detail loads profile | Valid uid | Open detail | Name, email, phone, KYC status | | |
| AP-102 | Wallet summary shown | Wallet exists | View detail | Balances from `wallets/{uid}` | | |
| AP-103 | Transaction history section | Txns exist | Scroll history | User transactions listed | | |
| AP-104 | Portfolio metrics | Portfolio doc | View NAV section | Data from `portfolios/{uid}` | | |
| AP-105 | Toggle fee version | On detail | Switch v1/v2 | `setInvestorFeeVersion` callable | | |
| AP-106 | Referral v2 save | Referral section | Edit/save referral | `saveReferralV2` updates `referrals/{uid}` | | |
| AP-107 | CRM assignment section | Admin on detail | Assign CRM | `crm_assignments` updated | | |
| AP-108 | View consent agreement PDF | Consent exists | Generate/view PDF | PDF builder runs | | |
| AP-109 | Change requests on detail | Tickets exist | View section | Linked requests shown | | |
| AP-110 | Toggle five-market ledger | On detail | Toggle | Callable updates portfolio flag | | |
| AP-111 | Delete investor account | Test investor | Delete; confirm | `deleteInvestorAccount` removes/archives per server logic | | |
| AP-112 | Delete confirmation required | On delete | Cancel dialog | No deletion | | |
| AP-113 | Invalid userId | Bad id | Open route | Not found error | | |
| AP-114 | CRM scoped access only assigned | CRM user | Open unassigned investor | Denied or not visible in CRM list | | |

---

## 13. Returns / Profit Rates / NAV

**Description:** Apply monthly returns, projection config, maintenance callables.  
**Entry Point:** `/returns` → `admin_returns_screen.dart`  
**Prerequisites:** Admin logged in; portfolios exist.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-115 | Returns screen loads config | Admin session | Open `/returns` | Projection config displayed | | |
| AP-116 | Apply monthly returns 0–100% | Valid pct | Enter return %; apply | `applyMonthlyReturns` updates portfolios | | |
| AP-117 | Reject return % > 100 | On form | Enter 101 | Validation error | | |
| AP-118 | Reject negative return % | On form | Enter -1 | Validation error | | |
| AP-119 | Save projection config | Valid rate 0–100 | Save | `saveReturnsProjectionConfig` success | | |
| AP-120 | repairUserBalances maintenance | On screen | Run repair | Callable completes | | |
| AP-121 | repairApprovedWithdrawals | On screen | Run repair | Callable completes | | |
| AP-122 | Confirmation before apply returns | Before apply | Tap apply | Confirm dialog | | |
| AP-123 | returnHistory written | After apply | Check `portfolios/{uid}/returnHistory` | New entries server-side | | |
| AP-124 | CRM blocked | CRM role | Open `/returns` | Denied | | |

---

## 14. Five Market Admin

**Description:** Config allocations/rates, day overrides, PK holidays, EOD diagnostics.  
**Entry Point:** `/five-market` → `admin_five_market_screen.dart`  
**Prerequisites:** Admin logged in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-125 | Five market screen loads tabs | Admin session | Open `/five-market` | Config, Overrides, Holidays, EOD tabs | | |
| AP-126 | Load current config | Doc exists | Config tab | Values from `settings/five_market_calc` | | |
| AP-127 | Save config allocations sum 100% | Config tab | Set stock+tech+debt+money+gold=100; save | `saveFiveMarketConfig` success | | |
| AP-128 | Reject allocations not 100% | Config tab | Sum 99% | Validation error (±0.01) | | |
| AP-129 | Save rates and tech benchmark | Config tab | Edit rates; save | Firestore updated | | |
| AP-130 | Day override force closed | Overrides tab | Pick date; force closed + reason; save | Doc in `five_market_day_overrides` | | |
| AP-131 | Day override force open | Overrides tab | Pick date; force open; save | Override saved | | |
| AP-132 | Add PK holiday | Holidays tab | Add date+name; save | `pakistan_holidays.holidays[]` updated | | |
| AP-133 | Edit existing holiday | Holiday exists | Edit; save | Array updated | | |
| AP-134 | Delete holiday | Holiday exists | Delete; save | Removed from array | | |
| AP-135 | EOD diagnostics read-only | EOD docs exist | EOD tab | Latest `investment_daily_market_close` shown | | |
| AP-136 | Investor app reflects holiday | Holiday added | Investor trading day | `resolveTradingDay` closed on holiday | | |
| AP-137 | Investor app reflects override | Force closed today | Investor live profit | Non-trading day behavior | | |
| AP-138 | CRM blocked | CRM role | Open route | Denied | | |

---

## 15. Fee Configuration

**Description:** Global fee settings and monthly statement send.  
**Entry Point:** `/fees` → `admin_fees_screen.dart`  
**Prerequisites:** Admin logged in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-139 | Fees screen loads config | Admin session | Open `/fees` | `getFeeConfig` values shown | | |
| AP-140 | Save management fee % | On form | Edit management %; save | `saveFeeConfig` success | | |
| AP-141 | Save performance fee % | On form | Edit performance %; save | Saved | | |
| AP-142 | Save front-end load % | On form | Edit FEL %; save | Saved; investor deposit preview updates | | |
| AP-143 | Save referral settings | On form | Toggle referral enabled; save | Saved | | |
| AP-144 | Default fee version toggle | On form | Set v1/v2 default; save | Saved | | |
| AP-145 | Send monthly fee statements | Investors exist | Tap send monthly | `sendMonthlyFeeStatements` invoked | | |
| AP-146 | Fee preview section | Transactions exist | View preview area | Fee aggregates from transactions | | |
| AP-147 | Invalid numeric input | On form | Enter non-numeric | Validation error | | |
| AP-148 | Save offline error | Offline | Save | Error message | | |
| AP-149 | CRM blocked | CRM role | Open `/fees` | Denied | | |

---

## 16. Earnings Dashboard

**Description:** Charts aggregating company fee earnings.  
**Entry Point:** `/earnings` → `admin_earnings_screen.dart`  
**Prerequisites:** Fee transactions exist.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-150 | Earnings screen loads | Admin session | Open `/earnings` | Charts/cards render | | |
| AP-151 | Front-end load fees aggregated | FEL txns exist | View section | Correct sum | | |
| AP-152 | Management fees aggregated | Mgmt fee txns | View | Correct sum | | |
| AP-153 | Performance fees aggregated | Perf fee txns | View | Correct sum | | |
| AP-154 | Referral fees aggregated | Referral txns | View | Correct sum | | |
| AP-155 | Empty data state | No fee txns | Open | Zero/empty charts | | |

---

## 17. Company Fee Ledger

**Description:** Read-only stream of company fee ledger entries with filters.  
**Entry Point:** `/fee-ledger` → `admin_company_fee_ledger_screen.dart`  
**Prerequisites:** Admin logged in; ledger entries exist.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-156 | Fee ledger loads | Entries exist | Open `/fee-ledger` | Entries listed | | |
| AP-157 | Filter by fee type | Mixed types | Select filter | List filtered | | |
| AP-158 | Filter by date range | Date range | Set dates | Entries in range only | | |
| AP-159 | Read-only no edit actions | On list | Attempt edit | No client write UI | | |
| AP-160 | Empty ledger | No entries | Open | Empty state | | |
| AP-161 | Loading state | Slow stream | Open | Spinner | | |
| AP-162 | CRM blocked | CRM role | Open | Denied | | |

---

## 18. Market Data Admin (PSX Companies)

**Description:** Manage `market_companies` and daily OHLC bars.  
**Entry Point:** `/market` → `admin_market_screen.dart` (not in shell nav; direct URL)  
**Prerequisites:** Admin logged in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-163 | Market admin loads companies | Companies exist | Navigate to `/market` | Company list shown | | |
| AP-164 | Create company happy path | On form | Enter name+ticker; save | New `market_companies` doc | | |
| AP-165 | Company name required | Empty name | Save | Validation error | | |
| AP-166 | Ticker required | Empty ticker | Save | Validation error | | |
| AP-167 | Edit company | Existing company | Edit fields; save | Doc updated | | |
| AP-168 | Add daily bar | Company selected | Add OHLC bar | `daily_bars` subdoc created | | |
| AP-169 | Sync via Cloud Function | Sync action available | Run sync | Function completes | | |
| AP-170 | Investor chart reflects bars | Bars added | Investor company chart | Historical data visible | | |
| AP-171 | CRM blocked | CRM role | Open `/market` | Denied | | |

---

## 19. Upload Investor Reports (PDF)

**Description:** Upload PDF reports for all investors or specific user.  
**Entry Point:** `/upload-reports` → `admin_upload_reports_screen.dart`  
**Prerequisites:** Admin logged in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-172 | Upload screen loads | Admin session | Open screen | Upload form visible | | |
| AP-173 | Pick PDF file | PDF ≤25MB | Select file | File name shown | | |
| AP-174 | Reject file >25MB | Large file | Select | Error/rejection | | |
| AP-175 | Upload happy path all investors | Valid PDF | Upload with uid=all | `uploadInvestorReportHttp` success; `reports` doc created | | |
| AP-176 | Investor sees uploaded report | After upload | Investor reports screen | Report appears | | |
| AP-177 | Upload progress/busy state | Uploading | Submit | UI blocked during upload | | |
| AP-178 | Upload failure handling | Network error | Upload | Error message | | |
| AP-179 | CRM blocked | CRM role | Open | Denied | | |

---

## 20. App Update Management

**Description:** Upload investor Android APK and configure force-update metadata.  
**Entry Point:** `/app-updates` → `admin_app_updates_screen.dart`  
**Prerequisites:** Admin logged in; Android APK file.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-180 | App updates screen loads | Admin session | Open `/app-updates` | Current release info shown | | |
| AP-181 | Pick APK ≤200MB | Valid APK | Select file | File accepted | | |
| AP-182 | Reject APK >200MB | Oversized | Select | Error | | |
| AP-183 | Parse APK metadata | Valid investor APK | Upload flow | `parseInvestorApkMetadata` extracts version | | |
| AP-184 | Reject wrong package ID | Wrong package APK | Upload | Validation against `INVESTOR_ANDROID_PACKAGE` | | |
| AP-185 | Publish release happy path | Valid APK | Set grace days 0–365; publish | `app_releases/current_android` updated + history item | | |
| AP-186 | Grace days validation | On form | Enter 366 | Validation error | | |
| AP-187 | Investor force update triggers | Min version bumped | Old APK investor | Redirected to force update | | |
| AP-188 | Release history listed | Past releases | View history | `android_releases/items` shown | | |
| AP-189 | CRM blocked | CRM role | Open | Denied | | |

---

## 21. Admin Notifications Inbox

**Description:** Staff notification inbox (shared NotificationsScreen).  
**Entry Point:** `/notifications` with `NotificationShellKind.admin`  
**Prerequisites:** Admin or CRM logged in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-190 | Admin notifications load | Notifications exist | Open `/notifications` | Inbox listed | | |
| AP-191 | Mark read on tap | Unread item | Tap | Marked read | | |
| AP-192 | Mark all read | Multiple unread | Mark all | All read | | |
| AP-193 | Empty inbox | No notifications | Open | Empty state | | |
| AP-194 | CRM can access notifications | CRM role | Open | Inbox loads | | |
| AP-195 | Loading/error states | Slow/error stream | Open | Appropriate UI | | |

---

## 22. Broadcast Announcements

**Description:** Send announcement to all users via callable (inbox + FCM).  
**Entry Point:** `/broadcast` → `admin_broadcast_screen.dart`  
**Prerequisites:** Admin logged in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-196 | Broadcast screen loads | Admin session | Open `/broadcast` | Title/body form | | |
| AP-197 | Title min 2 chars | On form | Enter 1 char title | Validation error | | |
| AP-198 | Body min 2 chars | On form | Enter 1 char body | Validation error | | |
| AP-199 | Send happy path | Valid title/body | Confirm send | `broadcastAnnouncement` success | | |
| AP-200 | Investor receives notification | After broadcast | Check investor inbox | Notification doc created | | |
| AP-201 | FCM push sent | FCM configured | After broadcast | Push received on device | | |
| AP-202 | Confirmation dialog before send | On form | Tap send | Confirm required | | |
| AP-203 | CRM blocked from broadcast | CRM role | Open `/broadcast` | Denied | | |

---

## 23. CRM Dashboard

**Description:** CRM staff landing with assigned investor summary.  
**Entry Point:** `/crm` → `crm_dashboard_screen.dart`  
**Prerequisites:** CRM user logged in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-204 | CRM dashboard loads | CRM session | Open `/crm` | Dashboard metrics/links | | |
| AP-205 | Shows assigned investor count | Assignments exist | View count | Matches `crm_assignments` | | |
| AP-206 | Nav to investor list | On dashboard | Tap investors | `/crm/investors` | | |
| AP-207 | Nav to team (admin only) | Admin impersonation N/A | CRM user | Team link hidden or denied | | |
| AP-208 | Admin blocked from CRM home default | Admin | Open `/crm` | May redirect to dashboard per rules | | |
| AP-209 | Loading state | Slow data | Open | Spinner | | |

---

## 24. CRM Investor List

**Description:** CRM-scoped investor list (assigned only).  
**Entry Point:** `/crm/investors` → `crm_investor_list_screen.dart`  
**Prerequisites:** CRM logged in; assignments exist.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-210 | CRM list shows assigned only | CRM with 3 assignments | Open list | Exactly assigned investors | | |
| AP-211 | Unassigned investor not listed | Unassigned uid | Search | Not found | | |
| AP-212 | Tap opens CRM detail | Assigned investor | Tap row | `/crm/investors/:userId` | | |
| AP-213 | Search within assigned | Assigned investors | Search name | Filters correctly | | |
| AP-214 | Empty assignments | CRM with none | Open list | Empty state | | |
| AP-215 | Admin full list separate | Admin | Uses `/investors` not CRM list | CRM list not used for admin | | |
| AP-216 | Loading state | Slow fetch | Open | Spinner | | |

---

## 25. CRM Investor Detail

**Description:** CRM view of assigned investor with notes, follow-ups, communications.  
**Entry Point:** `/crm/investors/:userId` → `crm_investor_detail_screen.dart`  
**Prerequisites:** CRM assigned to userId.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-217 | Detail loads for assigned investor | CRM assigned | Open detail | Profile summary shown | | |
| AP-218 | Block unassigned investor | CRM not assigned | Open other uid | Access denied/error | | |
| AP-219 | Add CRM note | On detail | Add note; save | `crm_notes` doc created | | |
| AP-220 | Add follow-up | On detail | Schedule follow-up | `crm_followups` doc created | | |
| AP-221 | Log communication | On detail | Log call/email | `crm_communications` doc created | | |
| AP-222 | Notes list displays history | Notes exist | View notes section | Chronological list | | |
| AP-223 | Read-only wallet/KYC per rules | On detail | View financial data | Per Firestore CRM read rules | | |
| AP-224 | Back to CRM list | On detail | Back | Returns to list | | |

---

## 26. CRM Team Management

**Description:** Admin creates/lists CRM staff users.  
**Entry Point:** `/crm/team` → `crm_team_screen.dart`  
**Prerequisites:** Admin logged in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-225 | Team screen loads CRM users | CRM users exist | Open `/crm/team` | Lists `role==crm` users | | |
| AP-226 | Create CRM user happy path | Admin | Enter email, password ≥6, name; create | `createCrmUser` success | | |
| AP-227 | Password min 6 on create | On form | Password 5 chars | Validation error | | |
| AP-228 | Duplicate email create | Existing email | Create | Error from callable | | |
| AP-229 | CRM user cannot access team | CRM role | Open `/crm/team` | Denied | | |
| AP-230 | New CRM can login | After create | Login as new CRM | Redirect `/crm` | | |
| AP-231 | Display name shown in list | CRM users | View list | Names/emails correct | | |
| AP-232 | Create form validation empty email | On form | Empty email | Validation error | | |

---

## 27. Admin Shell Navigation

**Description:** Drawer/rail navigation and layout consistency.  
**Entry Point:** `lib/src/admin/widgets/admin_shell.dart`  
**Prerequisites:** Admin logged in.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-233 | Shell drawer lists all admin modules | Admin desktop/web | Open drawer | KYC, deposits, investors, fees, etc. visible | | |
| AP-234 | Active route highlighted | On `/deposits` | View nav | Deposits item selected | | |
| AP-235 | Navigate between modules | Admin | Click each nav item | Correct route loads | | |
| AP-236 | Sign out from shell | Logged in | Sign out | `/login` | | |
| AP-237 | Responsive layout mobile | Narrow viewport | Open admin | Drawer/rail adapts | | |
| AP-238 | `/market` not in nav but reachable | Admin | URL `/market` | Screen loads (hidden from nav) | | |

---

## 28. Legacy Embedded Admin Dashboard

**Description:** Stub admin dashboard inside investor app binary.  
**Entry Point:** `/admin` → `features/admin/presentation/admin_dashboard_screen.dart`  
**Prerequisites:** User with admin role in investor app.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-239 | Admin role opens legacy dashboard | role=admin in investor app | Navigate `/admin` | Legacy dashboard loads | | |
| AP-240 | Investor role blocked | role=investor | Navigate `/admin` | Access denied | | |
| AP-241 | Link to finance console | On dashboard | Tap finance | `/admin/finance` | | |
| AP-242 | Dead link apply-return | On dashboard | Tap apply return | Route not registered — error or no-op | | |
| AP-243 | Links to upload-reports/app-updates | On dashboard | Tap links | May route to investor paths | | |

---

## 29. Legacy Finance Console

**Description:** Mobile finance console with deposits/withdrawals/ledger/audit/manual tabs using legacy collections.  
**Entry Point:** `/admin/finance` → `admin_finance_console_screen.dart`  
**Prerequisites:** Admin role in investor app.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-244 | Finance console loads tabs | Admin in investor app | Open `/admin/finance` | Deposits, Withdrawals, Ledger, Audit, Manual tabs | | |
| AP-245 | Legacy deposits tab | `deposit_requests` pending | Approve via `approveDeposit` | Request approved | | |
| AP-246 | Legacy reject deposit | Pending request | Reject | `rejectDeposit` success | | |
| AP-247 | Legacy withdrawals tab | Pending withdrawal_requests | Complete withdrawal | `completeWithdrawal` callable | | |
| AP-248 | Ledger tab read-only view | Transactions exist | View ledger tab | Transactions listed | | |
| AP-249 | Audit tab loads logs | audit_logs exist | Open Audit tab | Last 100 `audit_logs` shown | | |
| AP-250 | Manual add profit entry | Manual tab | Add profit via callable | `addProfitEntry` success | | |
| AP-251 | Manual add adjustment | Manual tab | Add adjustment | Callable success | | |
| AP-252 | Wallet repair from manual | Manual tab | Run repair | Repair callable completes | | |
| AP-253 | CRM blocked from finance console | CRM role | Open `/admin/finance` | Denied | | |

---

## 30. Firestore Rules & Access Control

**Description:** Verify security rules enforce role-based access (manual/API testing against `firebase/firestore.rules`).  
**Entry Point:** `D:\portfolio_app\firebase\firestore.rules`  
**Prerequisites:** Firebase emulator or test project; tokens for investor/admin/crm.

| TC# | Test Case Title | Preconditions | Steps | Expected Result | Pass/Fail | Notes |
|-----|----------------|---------------|-------|-----------------|-----------|-------|
| AP-254 | Investor cannot write transactions | Investor token | Client write to `transactions/{id}` | Permission denied | | |
| AP-255 | Investor cannot write wallets | Investor token | Client write to `wallets/{uid}` | Permission denied | | |
| AP-256 | Investor reads own wallet | Investor token | Read `wallets/{ownUid}` | Allowed | | |
| AP-257 | Investor cannot read other wallet | Investor A token | Read `wallets/{B}` | Permission denied | | |
| AP-258 | Admin reads all users | Admin token | Read any `users/{id}` | Allowed | | |
| AP-259 | Admin updates KYC status | Admin token | Update `kyc/{uid}` approve fields | Allowed | | |
| AP-260 | Investor cannot approve KYC | Investor token | Update `kyc/{other}` | Permission denied | | |
| AP-261 | Admin writes settings | Admin token | Write `settings/deposit_instructions` | Allowed | | |
| AP-262 | Investor read-only settings | Investor token | Read `settings/five_market_calc` | Allowed; write denied | | |
| AP-263 | CRM reads assigned investor only | CRM token | Read assigned vs unassigned user | Allowed/denied per `crmManagesInvestor` | | |
| AP-264 | audit_logs read admin only | Investor token | Read `audit_logs` | Denied | | |
| AP-265 | audit_logs read admin | Admin token | Read `audit_logs` | Allowed | | |

---

*End of QA_AdminPanel.md — 257 test cases (AP-001 through AP-265)*
