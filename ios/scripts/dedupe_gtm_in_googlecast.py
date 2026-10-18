#!/usr/bin/env python3
"""Rename the GTMSessionFetcher classes baked into GoogleCast.framework.

The dynamic Google Cast binary statically links its own copy of
GTMSessionFetcher. Firebase links a second copy into the app, so the
Objective-C runtime reports each class as implemented in both images
and may dispatch to the wrong one.

Cast calls its copy through local class symbols, not through the app's
classes. Renaming only the strings inside the Cast binary (same length,
so every pointer stays valid) makes those classes register under a
different name. Firebase keeps the real GTMSessionFetcher.
"""

import sys
from pathlib import Path

# Longer names that do not contain "GTMSessionFetcher" as a substring
# must be listed on their own. Names that do contain it are covered by
# the first replacement.
REPLACEMENTS = (
    (b"GTMSessionFetcher", b"XTMSessionFetcher"),
    (b"GTMSessionUploadFetcher", b"XTMSessionUploadFetcher"),
    (b"GTMSessionCookieStorage", b"XTMSessionCookieStorage"),
    (b"GTMUserAgentStringProvider", b"XTMUserAgentStringProvider"),
    (b"GTMStandardUserAgentProvider", b"XTMStandardUserAgentProvider"),
)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: dedupe_gtm_in_googlecast.py <GoogleCast binary>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"note: {path} yok, atlanıyor")
        return 0

    data = path.read_bytes()
    if data[:4] not in (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xfe\xed\xfa\xcf"):
        print(f"error: {path} bir Mach-O değil", file=sys.stderr)
        return 1

    for old, new in REPLACEMENTS:
        if len(old) != len(new):
            print(f"error: uzunluk farkı {old!r}", file=sys.stderr)
            return 1

    total = 0
    for old, new in REPLACEMENTS:
        count = data.count(old)
        if count:
            data = data.replace(old, new)
            total += count
            print(f"renamed {old.decode()} x{count}")

    if total == 0:
        print("GTM sınıfları zaten ayrılmış")
        return 0

    path.chmod(path.stat().st_mode | 0o200)
    path.write_bytes(data)
    print(f"patched {path} ({total} yer)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
