#!/usr/bin/env python3
"""Build the Zero ride-armour pilot from his MMX-Next cockpit sprite.

The ride armour draws its pilot as a separate AnimatedSprite inside the cockpit
(`ra_x.res`), which is X, so any other character visibly turned back into X the
moment they mounted one. MMX-Next has a matching cockpit sprite for Zero, so the
pilot is rebuilt from that instead of recolouring X.

The pilot node mirrors the mech's own animation name and frame index every
frame, so this has to expose exactly the same animation names with at least the
same frame counts, or the mirror would index past the end. Every frame shows the
same pose, so the atlas holds a single region that all of them share.
"""

import json
import os
import re
import sys

from PIL import Image

MMX_DEFAULT = "../MMX-Next"
SPRITE = "spr_zero_ride_armor"
OUT_DIR = "src/Actors/Props/RideArmor/pilot_sprites"
FRAME_W, FRAME_H = 160, 80

# Where X's pilot art sits inside the 160x80 pilot frame. Zero is aligned to the
# same box so he sits in the cockpit exactly where X did.
X_BOX = (68, 4, 90, 22)

# Animation names and frame counts read off ra_x.res.
ANIMATIONS = {
    "activate": 29, "dash": 8, "dash_loop": 2, "deactivate": 15,
    "deactivated": 1, "fall": 10, "idle": 1, "jump": 8, "jump_loop": 2,
    "punch_1": 20, "punch_2": 10, "punch_3": 12, "punch_end": 2,
    "recover": 3, "walk": 10,
}


def load_yy(path):
    text = open(path, encoding="utf-8-sig").read()
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", text))


def first_frame(mmx):
    folder = os.path.join(mmx, "sprites", SPRITE)
    meta = load_yy(os.path.join(folder, SPRITE + ".yy"))
    track = meta["sequence"]["tracks"][0]["keyframes"]["Keyframes"]
    guid = sorted(track, key=lambda k: k.get("Key", 0))[0]["Channels"]["0"]["Id"]["name"]
    return Image.open(os.path.join(folder, guid + ".png")).convert("RGBA")


def main():
    mmx = os.environ.get("MMX_NEXT", MMX_DEFAULT)
    source = first_frame(mmx)
    box = source.getbbox()
    if box is None:
        print("cockpit sprite is empty", file=sys.stderr)
        return 1
    art = source.crop(box)

    # Match X's pilot placement: same horizontal centre, same top edge, so Zero
    # clears the cockpit rim by the same amount.
    canvas = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    x_centre = (X_BOX[0] + X_BOX[2]) // 2
    canvas.paste(art, (x_centre - art.width // 2, X_BOX[1]))

    os.makedirs(OUT_DIR, exist_ok=True)
    png_path = os.path.join(OUT_DIR, "ra_zero.png")
    canvas.save(png_path)

    lines = ['[gd_resource type="SpriteFrames" load_steps=3 format=2]', ""]
    lines.append('[ext_resource path="res://%s" type="Texture" id=1]' % png_path.replace(os.sep, "/"))
    lines.append("")
    lines.append('[sub_resource type="AtlasTexture" id=1]')
    lines.append("flags = 4")
    lines.append("atlas = ExtResource( 1 )")
    lines.append("region = Rect2( 0, 0, %d, %d )" % (FRAME_W, FRAME_H))
    lines.append("")
    lines.append("[resource]")

    entries = []
    for name in sorted(ANIMATIONS):
        frames = ", ".join(["SubResource( 1 )"] * ANIMATIONS[name])
        entries.append('{\n"frames": [ %s ],\n"loop": true,\n"name": "%s",\n"speed": 10.0\n}'
                       % (frames, name))
    lines.append("animations = [ " + ", ".join(entries) + " ]")

    open(os.path.join(OUT_DIR, "ra_zero.tres"), "w").write("\n".join(lines) + "\n")
    print("wrote ra_zero.png (%dx%d, art %dx%d) and ra_zero.tres (%d animations)"
          % (FRAME_W, FRAME_H, art.width, art.height, len(ANIMATIONS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
