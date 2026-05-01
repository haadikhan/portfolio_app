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

# Headless CI: no wasm dry-run. On 8GB / 2 vCPU builders, default release (-O4) + icon shaking
# often fails or gets OOM-killed; these flags trim peak RAM and compiler work.
EXTRA_WEB_FLAGS=(
  --no-wasm-dry-run
  --optimization-level=2
  --no-tree-shake-icons
  --no-frequency-based-minification
)

BUILD_LOG=/tmp/portfolio_web_build.log
rm -f "$BUILD_LOG"

echo "[vercel_build] dart defines count: ${#DART_DEFINES[@]}"
set +e
if [ "${#DART_DEFINES[@]}" -eq 0 ]; then
  echo "[vercel_build] flutter build web (no dart-defines)..."
  flutter build web --release -t lib/admin_main.dart "${EXTRA_WEB_FLAGS[@]}" 2>&1 | tee "$BUILD_LOG"
else
  echo "[vercel_build] flutter build web (with dart-defines)..."
  flutter build web --release -t lib/admin_main.dart "${EXTRA_WEB_FLAGS[@]}" "${DART_DEFINES[@]}" 2>&1 | tee "$BUILD_LOG"
fi
web_status="${PIPESTATUS[0]}"
set -euo pipefail
if [ "$web_status" -ne 0 ]; then
  echo "[vercel_build] flutter build web failed (exit $web_status)."
  echo "[vercel_build] grep (dart2js / Target failed / errors):"
  grep -a -E \
    'Target .+ failed:|dart2js:|Error:|error: |Unhandled exception|Out of Memory|Killed process' \
    "$BUILD_LOG" | tail -n 60 || true
  echo "[vercel_build] tail log:"
  tail -n 250 "$BUILD_LOG" || true
  exit "$web_status"
fi
echo "[vercel_build] ok"
