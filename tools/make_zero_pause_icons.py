#!/usr/bin/env python3
"""Derive the pause-menu Zero portrait and life icon from MMX-Next art."""

import json
import os
import re
import sys

from PIL import Image

MMX_DEFAULT = "../MMX-Next"
OUT_DIR = "src/Options"


def load_yy(path):
    text = open(path, encoding="utf-8-sig").read()
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", text))


def first_frame(mmx, sprite):
    folder = os.path.join(mmx, "sprites", sprite)
    meta = load_yy(os.path.join(folder, sprite + ".yy"))
    keyframes = meta["sequence"]["tracks"][0]["keyframes"]["Keyframes"]
    first = sorted(keyframes, key=lambda item: item.get("Key", 0))[0]
    frame_name = first["Channels"]["0"]["Id"]["name"]
    return Image.open(os.path.join(folder, frame_name + ".png")).convert("RGBA")


def main():
    mmx = os.environ.get("MMX_NEXT", MMX_DEFAULT)
    os.makedirs(OUT_DIR, exist_ok=True)

    idle = first_frame(mmx, "spr_zero_idle")
    box = idle.getbbox()
    if box is None:
        raise ValueError("Zero idle sprite is empty")
    art = idle.crop(box)
    scale = min(34.0 / art.width, 38.0 / art.height)
    size = (max(1, int(round(art.width * scale))),
            max(1, int(round(art.height * scale))))
    art = art.resize(size, Image.Resampling.NEAREST)
    portrait = Image.new("RGBA", (38, 38), (0, 0, 0, 0))
    portrait.paste(art, ((38 - art.width) // 2, 38 - art.height), art)
    portrait.save(os.path.join(OUT_DIR, "base_Zero.png"))

    life = first_frame(mmx, "spr_zero_pickup_lifeup")
    if life.size != (16, 16):
        raise ValueError("Zero life icon must be 16x16, got %s" % (life.size,))
    life.save(os.path.join(OUT_DIR, "lives_zero.png"))
    print("wrote Zero pause portrait %s and life icon 16x16" % (size,))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError) as error:
        print("make_zero_pause_icons: %s" % error, file=sys.stderr)
        sys.exit(1)
