#!/usr/bin/env python3
"""Parse GameMaker `animation_add` tables into JSON.

A call looks like:

    animation_add("fall|jump", [0, 3,  3, 4,  7, 5,  10, 6,  12, 6], 7, 12);

The name is "animation|sprite" (sprite defaults to the animation name), the
array is flat (time, image_index) pairs measured in 60fps game steps, and the
trailing two optional arguments are the loop start/end times. The final pair is
a sentinel marking the end of the last frame's duration rather than a frame to
display, which is why durations are derived from the gaps between times.
"""

import argparse
import json
import re
import sys

CALL = re.compile(r"animation_add\s*\(\s*\"([^\"]+)\"\s*,\s*\[([^\]]*)\]\s*((?:,\s*-?\d+\s*)*)\)")


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def parse(path):
    text = strip_comments(open(path, encoding="utf-8-sig").read())
    out = {}
    for match in CALL.finditer(text):
        raw_name, body, trailing = match.group(1), match.group(2), match.group(3)

        name, _, sprite = raw_name.partition("|")
        sprite = sprite or name

        numbers = [int(n) for n in re.findall(r"-?\d+", body)]
        if len(numbers) % 2:
            print("odd keyframe count in %s, skipping" % name, file=sys.stderr)
            continue
        pairs = list(zip(numbers[0::2], numbers[1::2]))

        loop = [int(n) for n in re.findall(r"-?\d+", trailing)]

        # Later definitions win: the character script is parsed after the shared
        # one and is meant to override it (player_zero_animations redefines
        # "jump", "dash" and friends on top of player_animations).
        out[name] = {"sprite": sprite, "keyframes": pairs, "loop": loop}
    return out


def expand(entry):
    """Turn a keyframe table into one image_index per 60fps step."""
    pairs = entry["keyframes"]
    if not pairs:
        return []
    frames = []
    for i, (time, image) in enumerate(pairs[:-1]):
        duration = pairs[i + 1][0] - time
        frames.extend([image] * max(1, duration))
    return frames


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="+", help="GML files, later ones override earlier")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    merged = {}
    for path in args.files:
        merged.update(parse(path))

    for name, entry in merged.items():
        entry["frames"] = expand(entry)

    json.dump(merged, open(args.out, "w"), indent=1)
    print("parsed %d animations -> %s" % (len(merged), args.out))
    for name in sorted(merged):
        e = merged[name]
        print("  %-22s sprite=%-16s steps=%-4d loop=%s"
              % (name, e["sprite"], len(e["frames"]), e["loop"] or "-"))


if __name__ == "__main__":
    main()
