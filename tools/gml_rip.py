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


class Sprite:
    def __init__(self, sprites_dir, name):
        self.name = name
        folder = os.path.join(sprites_dir, name)
        meta = load_yy(os.path.join(folder, name + ".yy"))
        seq = meta["sequence"]
        self.width = meta["width"]
        self.height = meta["height"]
        self.origin = (seq["xorigin"], seq["yorigin"])
        self.fps = seq.get("playbackSpeed", 15.0)
        self.images = []
        for guid in frame_order(meta):
            self.images.append(Image.open(os.path.join(folder, guid + ".png")).convert("RGBA"))


def align_frames(sprites, pad):
    """Place every frame on one shared canvas with all origins coincident.

    Returns (frames, origin) where frames is a flat list of (sprite, index,
    image) and origin is the common origin position on the shared canvas.
    """
    left = max(s.origin[0] for s in sprites) + pad
    top = max(s.origin[1] for s in sprites) + pad
    right = max(s.width - s.origin[0] for s in sprites) + pad
    bottom = max(s.height - s.origin[1] for s in sprites) + pad
    size = (left + right, top + bottom)

    frames = []
    for sprite in sprites:
        for index, image in enumerate(sprite.images):
            canvas = Image.new("RGBA", size, (0, 0, 0, 0))
            canvas.paste(image, (left - sprite.origin[0], top - sprite.origin[1]))
            frames.append((sprite, index, canvas))
    return frames, (left, top)


def crop_box(frames):
    """Union of every frame's non-transparent bounds, so no art is ever clipped."""
    box = None
    for _, _, image in frames:
        bbox = image.getbbox()
        if bbox is None:
            continue
        box = bbox if box is None else (
            min(box[0], bbox[0]), min(box[1], bbox[1]),
            max(box[2], bbox[2]), max(box[3], bbox[3]),
        )
    return box


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sprites-dir", required=True)
    parser.add_argument("--names", required=True, help="comma-separated sprite folder names")
    parser.add_argument("--out-png", required=True)
    parser.add_argument("--out-index", required=True, help="JSON frame index for the .tres builder")
    parser.add_argument("--columns", type=int, default=12)
    parser.add_argument("--pad", type=int, default=0)
    args = parser.parse_args()

    names = [n.strip() for n in args.names.split(",") if n.strip()]
    sprites = []
    for name in names:
        folder = os.path.join(args.sprites_dir, name)
        if not os.path.isdir(folder):
            print("missing sprite: " + name, file=sys.stderr)
            return 1
        sprites.append(Sprite(args.sprites_dir, name))

    frames, origin = align_frames(sprites, args.pad)
    box = crop_box(frames)
    if box is None:
        print("all frames are empty", file=sys.stderr)
        return 1

    cell_w, cell_h = box[2] - box[0], box[3] - box[1]
    # Origin relative to the cropped cell - the AnimatedSprite offset is derived
    # from this, so it has to travel with the atlas.
    origin_in_cell = (origin[0] - box[0], origin[1] - box[1])

    columns = args.columns
    rows = (len(frames) + columns - 1) // columns
    atlas = Image.new("RGBA", (columns * cell_w, rows * cell_h), (0, 0, 0, 0))

    index = {"cell": [cell_w, cell_h], "origin": list(origin_in_cell), "sprites": {}}
    for i, (sprite, frame_index, image) in enumerate(frames):
        col, row = i % columns, i // columns
        x, y = col * cell_w, row * cell_h
        atlas.paste(image.crop(box), (x, y))
        entry = index["sprites"].setdefault(sprite.name, {"fps": sprite.fps, "regions": []})
        assert len(entry["regions"]) == frame_index
        entry["regions"].append([x, y, cell_w, cell_h])

    os.makedirs(os.path.dirname(args.out_png) or ".", exist_ok=True)
    atlas.save(args.out_png)
    json.dump(index, open(args.out_index, "w"), indent=1)

    print("frames: %d  cell: %dx%d  atlas: %dx%d  origin_in_cell: %s"
          % (len(frames), cell_w, cell_h, atlas.width, atlas.height, origin_in_cell))
    return 0


if __name__ == "__main__":
    sys.exit(main())
