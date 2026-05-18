#!/usr/bin/env bash
# Build release com strip de dev_occurrences.json.
#
# Uso:
#   tool/build_release.sh apk        # Android APK release
#   tool/build_release.sh appbundle  # Android AAB (Play Store)
#   tool/build_release.sh ios        # iOS (sem codesign)
#
# O asset dev_occurrences.json (~328KB) é movido pra fora do bundle
# antes do build e restaurado depois. Não-destrutivo: se o script falhar
# no meio, basta rerodar — o restore acontece em qualquer caída.

set -euo pipefail

cd "$(dirname "$0")/.."

DEV_ASSET="assets/dev_occurrences.json"
STASH_PATH=".dev_occurrences.json.stash"

mode="${1:-apk}"

cleanup() {
  if [ -f "$STASH_PATH" ]; then
    mv "$STASH_PATH" "$DEV_ASSET"
    echo "→ restored $DEV_ASSET"
  fi
}
trap cleanup EXIT

if [ -f "$DEV_ASSET" ]; then
  mv "$DEV_ASSET" "$STASH_PATH"
  echo "→ stashed $DEV_ASSET to $STASH_PATH"
fi

case "$mode" in
  apk)
    flutter build apk --release --dart-define=USE_DEV_DATA=false
    ;;
  appbundle)
    flutter build appbundle --release --dart-define=USE_DEV_DATA=false
    ;;
  ios)
    flutter build ios --release --no-codesign --dart-define=USE_DEV_DATA=false
    ;;
  *)
    echo "Uso: tool/build_release.sh {apk|appbundle|ios}"
    exit 1
    ;;
esac
