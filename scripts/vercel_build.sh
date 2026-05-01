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
# Optional env:
#   FLUTTER_REVISION   — git SHA of flutter/flutter framework (pins CI to your dev SDK).

set -euo pipefail

# Vercel sets CI=1; Flutter only skips the root-user warning when CI is the string "true".
export CI=true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Pin framework revision so CI matches a known-good stable SDK (avoid surprise stable drift vs local dev).
FLUTTER_REVISION="${FLUTTER_REVISION:-cc0734ac716fbb8b90f3f9db8020958b1553afa7}"

FLUTTER_DIR="$ROOT/flutter_sdk"

_needs_flutter_install() {
  if [[ ! -x "$FLUTTER_DIR/bin/flutter" ]]; then
    return 0
  fi
  local got
  got="$(git -C "$FLUTTER_DIR" rev-parse HEAD 2>/dev/null || echo "")"
  [[ "$got" != "$FLUTTER_REVISION" ]]
}

if _needs_flutter_install; then
  echo "[vercel_build] installing Flutter framework $FLUTTER_REVISION → $FLUTTER_DIR ..."
  rm -rf "$FLUTTER_DIR"
  mkdir -p "$FLUTTER_DIR"
  git init "$FLUTTER_DIR"
  git -C "$FLUTTER_DIR" remote add origin https://github.com/flutter/flutter.git
  git -C "$FLUTTER_DIR" fetch --depth 1 origin "$FLUTTER_REVISION"
  git -C "$FLUTTER_DIR" checkout -f FETCH_HEAD
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "[vercel_build] flutter --version:"
flutter --version

echo "[vercel_build] flutter config..."
flutter config --no-analytics

echo "[vercel_build] flutter clean..."
flutter clean

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

# 8 GB / 2 vCPU builders: dart2js release defaults are heavy. Trim RAM + compiler work.
# --no-tree-shake-icons: skip icon subsetting pass (loads full Material Icons).
# --no-source-maps: smaller / faster dart2js, less peak memory.
EXTRA_WEB_FLAGS=(
  --no-wasm-dry-run
  --optimization-level=1
  --no-tree-shake-icons
  --no-frequency-based-minification
  --no-source-maps
)

BUILD_LOG=/tmp/portfolio_web_build.log
rm -f "$BUILD_LOG"

run_web_release() {
  echo "[vercel_build] dart defines count: ${#DART_DEFINES[@]}"
  set +eo pipefail
  if [ "${#DART_DEFINES[@]}" -eq 0 ]; then
    echo "[vercel_build] flutter build web --release (no dart-defines)..."
    flutter build web --release -t lib/admin_main.dart "${EXTRA_WEB_FLAGS[@]}" 2>&1 | tee -a "$BUILD_LOG"
  else
    echo "[vercel_build] flutter build web --release (with dart-defines)..."
    flutter build web --release -t lib/admin_main.dart "${EXTRA_WEB_FLAGS[@]}" "${DART_DEFINES[@]}" 2>&1 | tee -a "$BUILD_LOG"
  fi
  web_status_release="${PIPESTATUS[0]:-1}"
  set -euo pipefail
}

run_web_profile() {
  echo "[vercel_build] release failed → trying flutter build web --profile (lighter compile, larger JS)."
  set +eo pipefail
  if [ "${#DART_DEFINES[@]}" -eq 0 ]; then
    flutter build web --profile -t lib/admin_main.dart "${EXTRA_WEB_FLAGS[@]}" 2>&1 | tee -a "$BUILD_LOG"
  else
    flutter build web --profile -t lib/admin_main.dart "${EXTRA_WEB_FLAGS[@]}" "${DART_DEFINES[@]}" 2>&1 | tee -a "$BUILD_LOG"
  fi
  web_status_profile="${PIPESTATUS[0]:-1}"
  set -euo pipefail
}

web_status_release=1
run_web_release
web_status="$web_status_release"

if [ "$web_status" -ne 0 ]; then
  web_status_profile=1
  run_web_profile
  web_status="$web_status_profile"
fi

if [ "$web_status" -ne 0 ]; then
  echo "[vercel_build] flutter build web failed (exit $web_status)."
  echo "[vercel_build] grep (hints):"
  grep -a -E \
    'Target .+ failed:|dart compile js|dart2js|'\
'Error:|error: |EXCEPTION|Exception|Unhandled|Unhandled exception|Unsupported operation|OOM|Out of Memory|SIGKILL|Killed process|'\
'Broken pipe|E/warning: |fatal error' \
    "$BUILD_LOG" | tail -n 120 || true
  echo "[vercel_build] tail log:"
  tail -n 300 "$BUILD_LOG" || true
  exit "$web_status"
fi
echo "[vercel_build] ok"
