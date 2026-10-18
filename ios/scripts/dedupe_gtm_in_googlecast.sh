#!/bin/sh
# GoogleCast.framework içine gömülü GTMSessionFetcher sınıflarını yeniden adlandırır.
# Embed Frameworks aşamasından sonra çalışmalı.
set -eu

BIN="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/GoogleCast.framework/GoogleCast"
FW="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/GoogleCast.framework"

if [ ! -f "$BIN" ]; then
  echo "note: GoogleCast gömülü değil, GTM ayrıştırma atlandı"
  exit 0
fi

python3 "${SRCROOT}/scripts/dedupe_gtm_in_googlecast.py" "$BIN"

SIGN_ID="${EXPANDED_CODE_SIGN_IDENTITY:--}"
if [ -z "$SIGN_ID" ]; then
  SIGN_ID="-"
fi
codesign --force --sign "$SIGN_ID" --timestamp=none "$FW"
echo "GoogleCast yeniden imzalandı ($SIGN_ID)"
