#!/usr/bin/env bash
# flutter_chrome_cast SPM paketi iOS 15.0 diyor; GoogleCast ise 16.0 istiyor.
# flutter pub get sonrası bu scripti çalıştır.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG=$(find "$HOME/.pub-cache/hosted" -path "*flutter_chrome_cast-*/ios/flutter_chrome_cast/Package.swift" 2>/dev/null | head -1)

if [[ -z "${PKG:-}" ]]; then
  echo "flutter_chrome_cast Package.swift bulunamadı (önce: flutter pub get)"
  exit 1
fi

perl -i -pe 's/\.iOS\("15\.0"\)/.iOS("16.0")/g' "$PKG"
PODSPEC="$(dirname "$(dirname "$PKG")")/flutter_chrome_cast.podspec"
if [[ -f "$PODSPEC" ]]; then
  perl -i -pe "s/platform = :ios, '15\.0'/platform = :ios, '16.0'/g; s/deployment_target  = '15\.0'/deployment_target  = '16.0'/g" "$PODSPEC"
fi

# Ephemeral kopya (varsa)
EPHEM="$ROOT/ios/Flutter/ephemeral/Packages/.packages"
if [[ -d "$EPHEM" ]]; then
  find "$EPHEM" -path "*flutter_chrome_cast*/Package.swift" -print0 2>/dev/null \
    | xargs -0 -I{} perl -i -pe 's/\.iOS\("15\.0"\)/.iOS("16.0")/g' {}
fi

echo "Patched: $PKG"
rg -n 'iOS\("' "$PKG" || true
