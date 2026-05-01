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
#   FLUTTER_REF        — stable Flutter semver (default 3.41.9). Used for official Linux SDK tarball.
#   FLUTTER_REVISION   — legacy alias for FLUTTER_REF (kept for compatibility).

set -euo pipefail

# Vercel sets CI=1; Flutter only skips the root-user warning when CI is the string "true".
export CI=true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Pin a stable Flutter version so `flutter --version` is a real semver (not 0.0.0-unknown).
# Shallow git clones often produce 0.0.0-unknown (no tag history for `git describe`), which
# breaks pub for packages that require a minimum Flutter SDK (e.g. firebase_app_check).
FLUTTER_REF="${FLUTTER_REF:-${FLUTTER_REVISION:-3.41.9}}"

FLUTTER_DIR="$ROOT/flutter_sdk"
FLUTTER_RELEASES_BASE="https://storage.googleapis.com/flutter_infra_release/releases"

_flutter_sdk_ok() {
  if [[ ! -x "$FLUTTER_DIR/bin/flutter" ]]; then
    return 1
  fi
  local want
  want="$(cat "$FLUTTER_DIR/.pinned_requested" 2>/dev/null || echo "")"
  if [[ "$want" != "$FLUTTER_REF" ]]; then
    return 1
  fi
  local vl
  vl="$("$FLUTTER_DIR/bin/flutter" --version 2>/dev/null | head -n 1 || echo "")"
  if [[ -z "$vl" ]] || [[ "$vl" == *"0.0.0-unknown"* ]]; then
    return 1
  fi
  return 0
}

_install_flutter_from_linux_tarball() {
  local ver="$1"
  local url="${FLUTTER_RELEASES_BASE}/stable/linux/flutter_linux_${ver}-stable.tar.xz"
  local tmpdir
  tmpdir="$(mktemp -d)"
  rm -rf "$FLUTTER_DIR" "$(dirname "$FLUTTER_DIR")/flutter"
  echo "[vercel_build] downloading Flutter $ver Linux SDK (official tarball)..."
  if ! curl -fsSL "$url" -o "$tmpdir/flutter_sdk.tar.xz"; then
    rm -rf "$tmpdir"
    return 1
  fi
  mkdir -p "$(dirname "$FLUTTER_DIR")"
  if ! tar -xf "$tmpdir/flutter_sdk.tar.xz" -C "$(dirname "$FLUTTER_DIR")"; then
    rm -rf "$tmpdir"
    return 1
  fi
  rm -rf "$tmpdir"
  if [[ ! -x "$(dirname "$FLUTTER_DIR")/flutter/bin/flutter" ]]; then
    echo "[vercel_build] tarball extraction did not yield flutter/bin/flutter"
    rm -rf "$(dirname "$FLUTTER_DIR")/flutter"
    return 1
  fi
  mv "$(dirname "$FLUTTER_DIR")/flutter" "$FLUTTER_DIR"
  printf "%s\n" "${FLUTTER_REF}" > "$FLUTTER_DIR/.pinned_requested"
  return 0
}

_install_flutter_from_git_tag() {
  local ref="$1"
  echo "[vercel_build] git clone Flutter ref $ref (fallback, depth 500) ..."
  rm -rf "$FLUTTER_DIR"
  if ! git clone https://github.com/flutter/flutter.git "$FLUTTER_DIR" \
    --single-branch \
    --branch "$ref" \
    --depth 500; then
    return 1
  fi
  printf "%s\n" "${FLUTTER_REF}" > "$FLUTTER_DIR/.pinned_requested"
  return 0
}

if ! _flutter_sdk_ok; then
  echo "[vercel_build] installing Flutter $FLUTTER_REF → $FLUTTER_DIR ..."
  # Prefer official stable Linux tarball (includes correct version metadata for pub).
  if [[ "$FLUTTER_REF" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    if ! _install_flutter_from_linux_tarball "$FLUTTER_REF"; then
      echo "[vercel_build] tarball install failed; trying git clone of tag $FLUTTER_REF."
      if ! _install_flutter_from_git_tag "$FLUTTER_REF"; then
        echo "[vercel_build] git tag clone failed; trying stable branch."
        if ! _install_flutter_from_git_tag "stable"; then
          echo "[vercel_build] could not install Flutter SDK."
          exit 1
        fi
      fi
    fi
  else
    echo "[vercel_build] FLUTTER_REF is not X.Y.Z; using git stable branch."
    if ! _install_flutter_from_git_tag "stable"; then
      echo "[vercel_build] could not install Flutter SDK."
      exit 1
    fi
  fi
fi

if ! _flutter_sdk_ok; then
  echo "[vercel_build] Flutter SDK still invalid after install."
  "$FLUTTER_DIR/bin/flutter" --version 2>&1 || true
  exit 1
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
