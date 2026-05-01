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

# Vercel sets CI=1; Flutter only skips the root-user warning when CI is the string "true".
export CI=true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Keep SDK under the project so Vercel's deployment build cache can reuse it.
# Do not `rm -rf` each run — that forces a full Dart download + flutter_tools bootstrap every deploy.
FLUTTER_DIR="$ROOT/flutter_sdk"
if [[ ! -x "$FLUTTER_DIR/bin/flutter" ]]; then
  echo "[vercel_build] cloning Flutter into $FLUTTER_DIR (stable, shallow)..."
  rm -rf "$FLUTTER_DIR"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

echo "[vercel_build] flutter --version:"
flutter --version

echo "[vercel_build] flutter config..."
flutter config --no-analytics
echo "[vercel_build] flutter pub get..."
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

echo "[vercel_build] dart defines count: ${#DART_DEFINES[@]}"
if [ "${#DART_DEFINES[@]}" -eq 0 ]; then
  echo "[vercel_build] flutter build web (no dart-defines)..."
  flutter build web --release -t lib/admin_main.dart "${EXTRA_WEB_FLAGS[@]}"
else
  echo "[vercel_build] flutter build web (with dart-defines)..."
  flutter build web --release -t lib/admin_main.dart "${EXTRA_WEB_FLAGS[@]}" "${DART_DEFINES[@]}"
fi
echo "[vercel_build] ok"
