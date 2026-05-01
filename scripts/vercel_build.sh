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

# Release web defaults use dart2js -O4, which often exhausts RAM on standard CI runners (e.g. 8GB).
export DART_VM_OPTIONS="--old_gen_heap_size=6144 ${DART_VM_OPTIONS:-}"

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

# Headless CI can fail wasm dry-run; omit it. Prefer -O3 over default -O4 to reduce dart2js memory.
EXTRA_WEB_FLAGS=(--no-wasm-dry-run --optimization-level=3)

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
  echo "[vercel_build] flutter build web failed (exit $web_status). Look for Target dart2js failed above; tail:"
  tail -n 200 "$BUILD_LOG" || true
  exit "$web_status"
fi
echo "[vercel_build] ok"
