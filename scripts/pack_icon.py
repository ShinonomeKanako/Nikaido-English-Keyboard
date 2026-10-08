#!/usr/bin/env python3
"""Package AppKit-rendered PNG representations into a standard ICNS container."""
import struct
from pathlib import Path
representations = {
    "icp4": "icon_16x16.png", "icp5": "icon_32x32.png", "icp6": "icon_32x32@2x.png",
    "ic07": "icon_128x128.png", "ic08": "icon_256x256.png", "ic09": "icon_512x512.png",
    "ic10": "icon_512x512@2x.png", "ic11": "icon_16x16@2x.png", "ic12": "icon_32x32@2x.png",
    "ic13": "icon_128x128@2x.png", "ic14": "icon_256x256@2x.png"
}
chunks = []
for kind, filename in representations.items():
    data = (Path("Resources/EnKeyBoard.iconset") / filename).read_bytes()
    chunks.append(kind.encode() + struct.pack(">I", len(data) + 8) + data)
body = b"".join(chunks)
Path("Resources/EnKeyBoard.icns").write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)
