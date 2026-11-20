#!/usr/bin/env python3
"""Sign a patched Cherri shortcut through RoutineHub's HubSign service."""

from __future__ import annotations

import json
import plistlib
import sys
import urllib.request
from pathlib import Path

from patch_shortcut_numbers import normalize


SIGNING_URL = "https://hubsign.routinehub.services/sign"
SUPPORTED_CONTENT_TYPES = {
    "application/octet-stream",
    "application/x-plist",
    "application/x-apple-shortcut",
}


def main() -> int:
    if len(sys.argv) != 4:
        print(f"usage: {sys.argv[0]} UNSIGNED OUTPUT_DIR SHORTCUT_NAME", file=sys.stderr)
        return 2

    source = Path(sys.argv[1])
    if not source.exists():
        matches = list(source.parent.glob("*_unsigned.shortcut"))
        if len(matches) != 1:
            raise SystemExit(f"cannot resolve unsigned Shortcut: {source}")
        source = matches[0]
    destination = Path(sys.argv[2]) / source.name.replace("_unsigned.shortcut", ".shortcut")
    shortcut_name = sys.argv[3]

    with source.open("rb") as shortcut_file:
        document = plistlib.load(shortcut_file)
    normalize(document)
    payload = json.dumps({
        "shortcutName": shortcut_name,
        "shortcut": plistlib.dumps(document, fmt=plistlib.FMT_XML).decode(),
    }).encode()
    request = urllib.request.Request(
        SIGNING_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "cherri/v2.4.0",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        content_type = response.headers.get_content_type()
        signed = response.read()
        if response.status != 200:
            raise SystemExit(f"signing failed with HTTP {response.status}")
        if content_type not in SUPPORTED_CONTENT_TYPES:
            raise SystemExit(f"unsupported response type: {content_type}")
        if signed[:4] != b"AEA1":
            raise SystemExit("signing response is not an AEA1 Shortcut")

    temporary = destination.with_suffix(destination.suffix + ".tmp")
    temporary.write_bytes(signed)
    temporary.chmod(0o600)
    temporary.replace(destination)
    print(f"PASS: signed {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
