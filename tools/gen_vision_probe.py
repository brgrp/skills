#!/usr/bin/env python3
"""One-time generator for powerpoint-to-md/assets/vision-probe.png +
powerpoint-to-md/assets/vision-probe.sha256.

Lives OUTSIDE the skill directory on purpose. If this script lived inside
`powerpoint-to-md/`, a curious calling agent could read it and pull the
plaintext answer from context — defeating the vision gate. Keep the answer
here and here only.

Re-run it if you ever want to regenerate the probe. Commit both output files.

The PNG contains a short phrase rendered large and centered on a white
background. The SHA-256 of that phrase (case-normalized, whitespace-trimmed)
is written to a sidecar file. The calling agent reads the PNG with its
vision tool, hashes what it read, and compares against the sidecar — so the
plaintext answer NEVER appears in any text file the agent reads.

Keep the phrase memorable but not so trivially guessable that a text-only
model could brute-force it. Two words works well.
"""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# NOTE: this string is the ground truth. It must NEVER appear in SKILL.md,
# in references/, in shell scripts read by the agent, or anywhere else the
# calling agent might read as context. It lives only here (an authoring-time
# script the runtime agent has no reason to read) and inside the PNG bitmap.
TEXT = "orange piano"

WIDTH, HEIGHT = 320, 90
FONT_SIZE = 44
# tools/ lives at the repo root, alongside the powerpoint-to-md/ skill dir.
ASSETS = Path(__file__).resolve().parent.parent / "powerpoint-to-md" / "assets"
OUT_PNG = ASSETS / "vision-probe.png"
OUT_HASH = ASSETS / "vision-probe.sha256"


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def _normalize(s: str) -> str:
    return " ".join(s.strip().lower().split())


def main() -> int:
    img = Image.new("1", (WIDTH, HEIGHT), color=1)  # 1-bit, white bg
    draw = ImageDraw.Draw(img)
    font = _font(FONT_SIZE)
    bbox = draw.textbbox((0, 0), TEXT, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (WIDTH - tw) // 2 - bbox[0]
    y = (HEIGHT - th) // 2 - bbox[1]
    draw.text((x, y), TEXT, fill=0, font=font)
    ASSETS.mkdir(parents=True, exist_ok=True)
    img.save(OUT_PNG, format="PNG", optimize=True, bits=1)

    digest = hashlib.sha256(_normalize(TEXT).encode("utf-8")).hexdigest()
    OUT_HASH.write_text(digest + "\n", encoding="utf-8")

    print(f"wrote {OUT_PNG} ({OUT_PNG.stat().st_size} bytes)")
    print(f"wrote {OUT_HASH} (sha256 of normalized phrase)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
