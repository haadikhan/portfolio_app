#!/usr/bin/env bash
# Admin web: flutter build web -t lib/admin_main.dart
#
# Post-deploy (manual):
# - Vercel: import repo, set production branch (e.g. old_state), deploy.
# - Firebase Console: Authentication > Settings > Authorized domains — add your *.vercel.app host.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FLUTTER_DIR="$ROOT/flutter_sdk"
rm -rf "$FLUTTER_DIR"
git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --no-analytics
flutter pub get
flutter build web --release -t lib/admin_main.dart
