#!/usr/bin/env python3
"""Build a Godot SpriteFrames .tres from a ripped atlas plus GML animation tables.

The atlas index supplies one region per (sprite, image_index); the animation
tables supply, for each animation, the image_index to show on every 60fps game
step. Emitting the expanded per-step list at speed 60 reproduces GameMaker's
variable frame durations exactly, which a single Godot `speed` value could not.

GML loops over a sub-range (loop_start..loop_end) but Godot only loops whole
animations, so a ranged loop is split: the named animation plays once and holds,
and a `<name>_loop` animation carries just the looping tail.
"""

import argparse
import json
import os
import sys


def godot_path(path):
    path = os.path.relpath(os.path.abspath(path), os.getcwd()).replace(os.sep, "/")
    return "res://" + path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--index", required=True, help="atlas index json from gml_rip.py")
    parser.add_argument("--anims", required=True, help="animation json from gml_anims.py")
    parser.add_argument("--atlas", required=True, help="atlas png path inside the project")
    parser.add_argument("--prefix", required=True, help="sprite folder prefix, e.g. spr_zero_")
    parser.add_argument("--only", help="comma-separated animation names to emit")
    parser.add_argument("--alias", default="",
                        help="godot=gml pairs, so Zero answers to the same animation "
                             "names X's ability nodes already drive (damage=dolor2)")
    parser.add_argument("--sprite-map", default="",
                        help="gml_sprite=replacement_sprite pairs for alternate layers")
    parser.add_argument("--resource-name", default="",
                        help="optional Godot resource_name (used to identify layers)")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    index = json.load(open(args.index))
    anims = json.load(open(args.anims))
    canvas_w, canvas_h = index["canvas"]

    # Godot-facing name -> GML animation name.
    alias = {}
    for pair in filter(None, (p.strip() for p in args.alias.split(","))):
        godot_name, _, gml_name = pair.partition("=")
        alias[godot_name] = gml_name

    sprite_map = {}
    for pair in filter(None, (p.strip() for p in args.sprite_map.split(","))):
        source_name, separator, replacement = pair.partition("=")
        if not separator:
            parser.error("--sprite-map entries must be source=replacement")
        sprite_map[source_name] = replacement

    wanted = [n.strip() for n in args.only.split(",")] if args.only else sorted(anims)

    # One AtlasTexture per distinct region, shared by every frame that uses it.
    regions = {}
    def region_id(sprite, image):
        entry = index["sprites"].get(args.prefix + sprite)
        if entry is None or image >= len(entry["frames"]):
            return None
        key = (sprite, image)
        if key not in regions:
            regions[key] = len(regions) + 1
        return regions[key]

    built, skipped = [], []
    for name in wanted:
        entry = anims.get(alias.get(name, name))
        if entry is None:
            skipped.append((name, "no animation table"))
            continue
        sprite = sprite_map.get(entry["sprite"], entry["sprite"])
        steps, loop = entry["frames"], entry["loop"]
        sprite_entry = index["sprites"].get(args.prefix + sprite)
        if sprite_entry is None:
            skipped.append((name, "sprite %s not in atlas" % (args.prefix + sprite)))
            continue
        if not steps and entry.get("native_fps"):
            # Bare animation_add: play the whole sprite at its own fps, looping.
            hold = max(1, int(round(60.0 / max(1.0, sprite_entry["fps"]))))
            steps = []
            for i in range(len(sprite_entry["frames"])):
                steps.extend([i] * hold)
            loop = [0, len(steps)]
        if not steps:
            skipped.append((name, "empty keyframe table"))
            continue

        ids = [region_id(sprite, i) for i in steps]
        if any(i is None for i in ids):
            skipped.append((name, "image_index out of range for %s" % sprite))
            continue

        ranged = len(loop) == 2 and loop[0] > 0
        built.append((name, ids, len(loop) == 2 and loop[0] == 0))
        if ranged:
            start, end = loop[0], min(loop[1], len(ids) - 1)
            # MMX-Next's animation loop endpoints are inclusive.
            tail = ids[start:end + 1]
            if tail:
                built.append((name + "_loop", tail, True))

    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=2]' % (len(regions) + 2), ""]
    lines.append('[ext_resource path="%s" type="Texture" id=1]' % godot_path(args.atlas))
    lines.append("")
    for (sprite, image), rid in sorted(regions.items(), key=lambda kv: kv[1]):
        frame = index["sprites"][args.prefix + sprite]["frames"][image]
        x, y, w, h = frame["region"]
        mx, my, mw, mh = frame["margin"]
        lines.append('[sub_resource type="AtlasTexture" id=%d]' % rid)
        lines.append("flags = 4")           # filter off, pixel art stays crisp
        lines.append("atlas = ExtResource( 1 )")
        lines.append("region = Rect2( %d, %d, %d, %d )" % (x, y, w, h))
        # Re-inflates the trimmed frame back to the shared canvas, so every
        # frame reports the same size and the sprite never shifts between them.
        lines.append("margin = Rect2( %d, %d, %d, %d )" % (mx, my, mw, mh))
        lines.append("")

    lines.append("[resource]")
    if args.resource_name:
        lines.append('resource_name = "%s"' % args.resource_name.replace('"', '\\"'))
    entries = []
    for name, ids, loop in built:
        frames = ", ".join("SubResource( %d )" % i for i in ids)
        entries.append('{\n"frames": [ %s ],\n"loop": %s,\n"name": "%s",\n"speed": 60.0\n}'
                       % (frames, "true" if loop else "false", name))
    lines.append("animations = [ " + ", ".join(entries) + " ]")

    open(args.out, "w").write("\n".join(lines) + "\n")

    print("wrote %s" % args.out)
    print("  animations: %d   atlas regions: %d   canvas: %dx%d"
          % (len(built), len(regions), canvas_w, canvas_h))
    print("  origin on canvas: %s" % (index["origin"],))
    for name, _ in skipped:
        pass
    if skipped:
        print("  skipped:")
        for name, why in skipped:
            print("    %-20s %s" % (name, why))
    return 0


if __name__ == "__main__":
    sys.exit(main())
