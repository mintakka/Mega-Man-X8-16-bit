#!/usr/bin/env python3
"""Build Zero's ride-armour pilot with X's per-frame cockpit motion.

The ride armour renders its pilot as a separate AnimatedSprite whose animation
and frame are mirrored from the mech. Zero supplies one seated cockpit pose in
MMX-Next; the local ``ra_x`` Aseprite export supplies the position of the pilot
on every mech frame. This tool places Zero at X's per-frame bounding box and
recreates the same duration expansion used by AsepriteWizard, so he rises,
bobs, jumps and dashes with the cockpit instead of appearing immediately at the
final seated position.
"""

import json
import math
import os
import re
import sys

from PIL import Image

MMX_DEFAULT = "../MMX-Next"
SPRITE = "spr_zero_ride_armor"
OUT_DIR = "src/Actors/Props/RideArmor/pilot_sprites"
REFERENCE_JSON = os.path.join(OUT_DIR, "ra_x.json")
REFERENCE_PNG = os.path.join(OUT_DIR, "ra_x.png")
FRAME_W, FRAME_H = 160, 80


def load_yy(path):
    text = open(path, encoding="utf-8-sig").read()
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", text))


def zero_art(mmx):
    folder = os.path.join(mmx, "sprites", SPRITE)
    meta = load_yy(os.path.join(folder, SPRITE + ".yy"))
    track = meta["sequence"]["tracks"][0]["keyframes"]["Keyframes"]
    guid = sorted(track, key=lambda k: k.get("Key", 0))[0]["Channels"]["0"]["Id"]["name"]
    source = Image.open(os.path.join(folder, guid + ".png")).convert("RGBA")
    box = source.getbbox()
    if box is None:
        raise ValueError("Zero cockpit sprite is empty")
    return source.crop(box)


def frame_tile(reference, frame, art):
    region = frame["frame"]
    source = reference.crop((region["x"], region["y"],
                             region["x"] + region["w"],
                             region["y"] + region["h"]))
    box = source.getbbox()
    canvas = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    if box is not None:
        centre_x = (box[0] + box[2]) // 2
        canvas.paste(art, (centre_x - art.width // 2, box[1]))
    return canvas


def expanded_animation(frames, tag, region_ids):
    selected = frames[tag["from"]:tag["to"] + 1]
    if tag.get("direction", "forward") != "forward":
        raise ValueError("unsupported Aseprite direction for %s" % tag["name"])
    minimum = min(frame["duration"] for frame in selected)
    # AsepriteWizard's GDScript operands are integers, so Godot 3 performs
    # integer division before ceil here (1000 / 42 becomes 23, not 23.81).
    fps = int(math.ceil(1000 // minimum))
    ids = []
    for raw_index in range(tag["from"], tag["to"] + 1):
        repeat = int(math.ceil(frames[raw_index]["duration"] / float(minimum)))
        ids.extend([region_ids[raw_index]] * repeat)
    return ids, fps


def main():
    mmx = os.environ.get("MMX_NEXT", MMX_DEFAULT)
    art = zero_art(mmx)
    data = json.load(open(REFERENCE_JSON, encoding="utf-8"))
    reference = Image.open(REFERENCE_PNG).convert("RGBA")
    atlas = Image.new("RGBA", reference.size, (0, 0, 0, 0))

    # Aseprite reuses atlas coordinates for identical raw frames. Preserve that
    # layout so the generated sheet remains compact and Android-safe.
    regions = {}
    raw_region_ids = []
    placed_tiles = {}
    for frame in data["frames"]:
        region = frame["frame"]
        key = (region["x"], region["y"], region["w"], region["h"])
        tile = frame_tile(reference, frame, art)
        if key in placed_tiles and placed_tiles[key].tobytes() != tile.tobytes():
            raise ValueError("shared reference region produced inconsistent pilot placement")
        if key not in regions:
            regions[key] = len(regions) + 1
            placed_tiles[key] = tile
            atlas.paste(tile, (region["x"], region["y"]))
        raw_region_ids.append(regions[key])

    os.makedirs(OUT_DIR, exist_ok=True)
    png_path = os.path.join(OUT_DIR, "ra_zero.png")
    tres_path = os.path.join(OUT_DIR, "ra_zero.tres")
    atlas.save(png_path)

    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=2]'
             % (len(regions) + 2), ""]
    lines.append('[ext_resource path="res://%s" type="Texture" id=1]'
                 % png_path.replace(os.sep, "/"))
    lines.append("")
    for (x, y, width, height), resource_id in regions.items():
        lines.append('[sub_resource type="AtlasTexture" id=%d]' % resource_id)
        lines.append("flags = 4")
        lines.append("atlas = ExtResource( 1 )")
        lines.append("region = Rect2( %d, %d, %d, %d )" % (x, y, width, height))
        lines.append("")

    entries = []
    counts = {}
    for tag in data["meta"]["frameTags"]:
        ids, fps = expanded_animation(data["frames"], tag, raw_region_ids)
        counts[tag["name"]] = len(ids)
        frame_text = ", ".join("SubResource( %d )" % resource_id for resource_id in ids)
        entries.append('{\n"frames": [ %s ],\n"loop": false,\n"name": "%s",\n"speed": %.1f\n}'
                       % (frame_text, tag["name"], float(fps)))

    lines.append("[resource]")
    lines.append("animations = [ " + ", ".join(entries) + " ]")
    open(tres_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")

    activate = data["meta"]["frameTags"][2]
    activate_regions = raw_region_ids[activate["from"]:activate["to"] + 1]
    print("wrote %s and %s (%d atlas regions, %d animations)"
          % (png_path, tres_path, len(regions), len(entries)))
    print("  activate: %d expanded frames across %d moving placements"
          % (counts["activate"], len(set(activate_regions))))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError) as error:
        print("make_zero_pilot: %s" % error, file=sys.stderr)
        sys.exit(1)
