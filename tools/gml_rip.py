#!/usr/bin/env python3
"""Rip GameMaker sprites out of the MMX-Next project into Godot SpriteFrames.

GameMaker stores each sprite as a folder of GUID-named PNGs plus a .yy manifest
holding the frame order, the canvas size and the origin. Godot wants a single
atlas texture and a SpriteFrames resource of AtlasTexture regions, so this walks
the .yy files, aligns every frame by its GML origin onto one shared canvas,
crops that canvas to the union of all non-transparent pixels, packs the result
into a grid and writes out the atlas plus a .tres.

Aligning by origin before cropping is what keeps the character from jittering:
every frame ends up on the same canvas with the origin at the same spot, so a
single AnimatedSprite offset positions the whole animation set correctly.
"""

import argparse
import json
import os
import re
import sys

from PIL import Image


def load_yy(path):
    #.yy files are JSON with trailing commas and a UTF-8 BOM, which json refuses.
    text = open(path, encoding="utf-8-sig").read()
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", text))


def frame_order(meta):
    """Return frame GUIDs in playback order.

    The sequence track is authoritative - it maps each image_index (Key) to a
    frame GUID. The top-level `frames` array is usually the same order but is
    not guaranteed to be, so only fall back to it when there is no track.
    """
    tracks = meta.get("sequence", {}).get("tracks", [])
    if tracks:
        keyframes = tracks[0].get("keyframes", {}).get("Keyframes", [])
        ordered = sorted(keyframes, key=lambda k: k.get("Key", 0))
        guids = [kf["Channels"]["0"]["Id"]["name"] for kf in ordered]
        if guids:
            return guids
    return [f["name"] for f in meta.get("frames", [])]


def find_sprite_folder(sprites_dirs, name):
    for d in sprites_dirs.split(":"):
        folder = os.path.join(d, name)
        if os.path.isdir(folder):
            return folder
    return None


class Sprite:
    def __init__(self, sprites_dir, name):
        self.name = name
        folder = find_sprite_folder(sprites_dir, name)
        meta = load_yy(os.path.join(folder, name + ".yy"))
        seq = meta["sequence"]
        self.width = meta["width"]
        self.height = meta["height"]
        self.origin = (seq["xorigin"], seq["yorigin"])
        self.fps = seq.get("playbackSpeed", 15.0)
        self.images = []
        for guid in frame_order(meta):
            self.images.append(Image.open(os.path.join(folder, guid + ".png")).convert("RGBA"))


def align_frames(sprites, pad, symmetric_x=True):
    """Place every frame on one shared canvas with all origins coincident.

    Returns (frames, origin) where frames is a flat list of (sprite, index,
    image) and origin is the common origin position on the shared canvas.
    """
    left = max(s.origin[0] for s in sprites) + pad
    top = max(s.origin[1] for s in sprites) + pad
    right = max(s.width - s.origin[0] for s in sprites) + pad
    bottom = max(s.height - s.origin[1] for s in sprites) + pad

    # The canvas is made symmetric about the origin horizontally because the
    # game flips a facing direction by negating the sprite's scale.x, which
    # mirrors about the node position. If the origin were off-centre the
    # character would visibly jump sideways every time they turned around.
    if symmetric_x:
        left = right = max(left, right)

    size = (left + right, top + bottom)

    frames = []
    for sprite in sprites:
        for index, image in enumerate(sprite.images):
            canvas = Image.new("RGBA", size, (0, 0, 0, 0))
            canvas.paste(image, (left - sprite.origin[0], top - sprite.origin[1]))
            frames.append((sprite, index, canvas))
    return frames, (left, top)


def trim(image):
    """Tight bounds of the visible pixels, or None when the frame is empty."""
    return image.getbbox()


def shelf_pack(sizes, max_width):
    """Place rectangles into rows, tallest first, and return positions + extent.

    Sorting by height keeps each row's wasted vertical space small. This is not
    an optimal packer, but sprite frames are all roughly character-sized so the
    simple version leaves little slack and stays deterministic.
    """
    order = sorted(range(len(sizes)), key=lambda i: (-sizes[i][1], -sizes[i][0], i))
    positions = [None] * len(sizes)
    x = y = row_height = width = 0
    for i in order:
        w, h = sizes[i]
        if x + w > max_width and x > 0:
            x = 0
            y += row_height
            row_height = 0
        positions[i] = (x, y)
        x += w
        row_height = max(row_height, h)
        width = max(width, x)
    return positions, width, y + row_height


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sprites-dir", required=True,
                        help="colon-separated list of sprite dirs, searched in order")
    parser.add_argument("--names", required=True, help="comma-separated sprite folder names")
    parser.add_argument("--out-png", required=True)
    parser.add_argument("--out-index", required=True, help="JSON frame index for the .tres builder")
    parser.add_argument("--max-width", type=int, default=2048)
    parser.add_argument("--pad", type=int, default=1)
    args = parser.parse_args()

    names = [n.strip() for n in args.names.split(",") if n.strip()]
    sprites = []
    for name in names:
        if find_sprite_folder(args.sprites_dir, name) is None:
            print("missing sprite: " + name, file=sys.stderr)
            return 1
        sprites.append(Sprite(args.sprites_dir, name))

    # Every frame is first placed on one shared canvas with all origins on the
    # same spot. Sprites disagree on both canvas size and origin - Raikousen is
    # 200x80 at (95,40) while the rest are 128x128 at (61,64) - so this common
    # canvas is what lets a single AnimatedSprite offset serve all of them.
    frames, origin = align_frames(sprites, 0)
    canvas_w, canvas_h = frames[0][2].size

    # Only the visible pixels are stored; AtlasTexture.margin re-inflates each
    # frame back to the common canvas at draw time, so trimming costs no
    # alignment accuracy but saves a great deal of atlas space.
    trimmed, boxes = [], []
    for sprite, index, image in frames:
        box = trim(image)
        if box is None:
            box = (0, 0, 1, 1)  # keep a degenerate region so frame indices stay dense
        trimmed.append(image.crop(box))
        boxes.append(box)

    pad = args.pad
    sizes = [(im.width + pad, im.height + pad) for im in trimmed]
    positions, atlas_w, atlas_h = shelf_pack(sizes, args.max_width)

    atlas = Image.new("RGBA", (max(atlas_w, 1), max(atlas_h, 1)), (0, 0, 0, 0))
    index = {
        "canvas": [canvas_w, canvas_h],
        "origin": list(origin),
        "sprites": {},
    }
    for i, (sprite, frame_index, _) in enumerate(frames):
        image = trimmed[i]
        x, y = positions[i]
        atlas.paste(image, (x, y))
        box = boxes[i]
        entry = index["sprites"].setdefault(sprite.name, {"fps": sprite.fps, "frames": []})
        assert len(entry["frames"]) == frame_index
        entry["frames"].append({
            "region": [x, y, image.width, image.height],
            # margin.position is where the trimmed pixels sit on the common
            # canvas; margin.size is the padding needed to restore its full size.
            "margin": [box[0], box[1],
                       canvas_w - image.width, canvas_h - image.height],
        })

    os.makedirs(os.path.dirname(args.out_png) or ".", exist_ok=True)
    atlas.save(args.out_png)
    json.dump(index, open(args.out_index, "w"), indent=1)

    used = sum(im.width * im.height for im in trimmed)
    print("frames: %d  canvas: %dx%d  atlas: %dx%d (%.0f%% used)  origin: %s"
          % (len(frames), canvas_w, canvas_h, atlas.width, atlas.height,
             100.0 * used / max(1, atlas.width * atlas.height), origin))
    return 0


if __name__ == "__main__":
    sys.exit(main())
