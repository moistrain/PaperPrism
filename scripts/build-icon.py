#!/usr/bin/env python3

"""Build a modern ICNS container from the PaperPrism PNG iconset."""

from pathlib import Path
import struct


PROJECT_DIR = Path(__file__).resolve().parent.parent
ICONSET_DIR = PROJECT_DIR / "Resources" / "AppIcon.iconset"
OUTPUT_PATH = PROJECT_DIR / "Resources" / "AppIcon.icns"

CHUNKS = [
    ("icp4", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
]


def chunk(kind: str, data: bytes) -> bytes:
    return kind.encode("ascii") + struct.pack(">I", len(data) + 8) + data


payload = b"".join(
    chunk(kind, (ICONSET_DIR / filename).read_bytes())
    for kind, filename in CHUNKS
)
container = b"icns" + struct.pack(">I", len(payload) + 8) + payload
OUTPUT_PATH.write_bytes(container)
print(OUTPUT_PATH)
