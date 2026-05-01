#!/usr/bin/env bash
# Admin web: flutter build web -t lib/admin_main.dart
#
# Post-deploy (manual checklist):
# 1) Vercel: connect repo; Git push deploys the branch set as Production / Preview.
# 2) Firebase Auth: Authentication > Settings > Authorized domains — add:
#    your-project.vercel.app, any custom domain used in production, and localhost for dev.
# 3) Firebase App Check (web under enforcement): prefer reCAPTCHA — in Vercel project
#    Settings > Environment Variables set (Production):
#      FIREBASE_APP_CHECK_WEB_RECAPTCHA_SITE_KEY (optional; see below)
#      FIREBASE_APP_CHECK_WEB_PROVIDER            (optional: enterprise | v3)
#      FIREBASE_APP_CHECK_WEB_DEBUG_TOKEN          (optional CI/staging only; not for public prod)
#    ReCAPTCHA Enterprise: allow your *.vercel.app (and custom domain) in the key's domain settings.
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FLUTTER_DIR="$ROOT/flutter_sdk"
rm -rf "$FLUTTER_DIR"
git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --no-analytics
flutter pub get

DART_DEFINES=()
if [ -n "${FIREBASE_APP_CHECK_WEB_RECAPTCHA_SITE_KEY:-}" ]; then
  DART_DEFINES+=(--dart-define=FIREBASE_APP_CHECK_WEB_RECAPTCHA_SITE_KEY="${FIREBASE_APP_CHECK_WEB_RECAPTCHA_SITE_KEY}")
fi
if [ -n "${FIREBASE_APP_CHECK_WEB_PROVIDER:-}" ]; then
  DART_DEFINES+=(--dart-define=FIREBASE_APP_CHECK_WEB_PROVIDER="${FIREBASE_APP_CHECK_WEB_PROVIDER}")
fi
if [ -n "${FIREBASE_APP_CHECK_WEB_DEBUG_TOKEN:-}" ]; then
  DART_DEFINES+=(--dart-define=FIREBASE_APP_CHECK_WEB_DEBUG_TOKEN="${FIREBASE_APP_CHECK_WEB_DEBUG_TOKEN}")
fi

# Headless CI (e.g. Vercel) can fail on the default wasm dry run; match stable local JS builds.
EXTRA_WEB_FLAGS=(--no-wasm-dry-run)

if [ "${#DART_DEFINES[@]}" -eq 0 ]; then
  flutter build web --release -t lib/admin_main.dart "${EXTRA_WEB_FLAGS[@]}"
else
  flutter build web --release -t lib/admin_main.dart "${EXTRA_WEB_FLAGS[@]}" "${DART_DEFINES[@]}"
fi
