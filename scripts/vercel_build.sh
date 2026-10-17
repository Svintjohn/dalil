#!/usr/bin/env bash
# Builds the Flutter web app into app/build/web. Vercel serves that folder; /api/* goes to the Python function.
set -euo pipefail
if [ -f app/build/web/index.html ]; then
  echo "Using the prebuilt app in app/build/web"
  exit 0
fi
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
cd app
[ -d web ] || flutter create . --platforms=web --project-name dalil_app
flutter pub get
flutter build web --release
