#!/usr/bin/env python3
"""Parse GameMaker `animation_add` tables into JSON.

A call looks like:

    animation_add("fall|jump", [0, 3,  3, 4,  7, 5,  10, 6,  12, 6], 7, 12);

The name is "animation|sprite" (sprite defaults to the animation name), the
array is flat (time, image_index) pairs measured in 60fps game steps, and the
trailing one or two optional arguments are the inclusive loop start/end times.
MMX-Next displays the final pair for one update before reporting animation_end;
it is not merely a sentinel.
"""

import argparse
import json
import re
import sys

CALL = re.compile(r"animation_add\s*\(\s*\"([^\"]+)\"\s*,\s*\[([^\]]*)\]\s*((?:,\s*-?\d+\s*)*)\)")

# A bare animation_add("name") has no timing table at all: GameMaker just plays
# the sprite at its own fps. Emitted with empty keyframes and picked up by the
# builder, which expands it to every frame of the sprite.
BARE = re.compile(r"animation_add\s*\(\s*\"([^\"]+)\"\s*\)")

# Some animations borrow another animation's timing wholesale instead of
# repeating the table, e.g. the airborne Raikousen:
#   animation_add("atk_raikousen_air", animations_frames[? "atk_raikousen"]);
# The sprite still defaults to the animation's own name, so this reuses the
# timing against a different sprite.
REF = re.compile(r"animation_add\s*\(\s*\"([^\"]+)\"\s*,\s*"
                 r"animations_frames\[\?\s*\"([^\"]+)\"\s*\]\s*((?:,\s*-?\d+\s*)*)\)")


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
        # animation_add(name, frames, 4) means a one-step hold at t=4.  The GML
        # helper expands the missing fourth argument to the same value.
        if len(loop) == 1:
            loop.append(loop[0])

        # Later definitions win: the character script is parsed after the shared
        # one and is meant to override it (player_zero_animations redefines
        # "jump", "dash" and friends on top of player_animations).
        out[name] = {"sprite": sprite, "keyframes": pairs, "loop": loop}

    for match in BARE.finditer(text):
        raw_name = match.group(1)
        name, _, sprite = raw_name.partition("|")
        out[name] = {"sprite": sprite or name, "keyframes": [], "loop": [], "native_fps": True}

    for match in REF.finditer(text):
        raw_name, source, trailing = match.group(1), match.group(2), match.group(3)
        name, _, sprite = raw_name.partition("|")
        sprite = sprite or name
        out[name] = {
            "sprite": sprite,
            "borrows": source,
            "loop": [int(n) for n in re.findall(r"-?\d+", trailing)],
        }
        if len(out[name]["loop"]) == 1:
            out[name]["loop"].append(out[name]["loop"][0])
    return out


def expand(entry):
    """Turn a keyframe table into one image_index per 60fps step."""
    pairs = entry["keyframes"]
    if not pairs:
        return []
    frames = []
    for i, (time, image) in enumerate(pairs):
        # animation_update() exposes the final key at its exact timestamp and
        # only raises animation_end on the following update.
        if i + 1 < len(pairs):
            duration = pairs[i + 1][0] - time
        elif len(entry.get("loop", [])) == 2:
            # A loop may deliberately hold the last key beyond its timestamp,
            # e.g. idle's final image starts at 168 and loops at 171.
            duration = entry["loop"][1] - time + 1
        else:
            duration = 1
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

    # Resolve borrowed timing tables. Looping until nothing changes handles a
    # borrow whose source is itself a borrow, in any file order.
    for _ in range(len(merged) + 1):
        progressed = False
        for entry in merged.values():
            source = entry.get("borrows")
            if source is None:
                continue
            donor = merged.get(source)
            if donor is None or "keyframes" not in donor:
                continue
            entry["keyframes"] = donor["keyframes"]
            entry.pop("borrows")
            progressed = True
        if not progressed:
            break

    for name, entry in list(merged.items()):
        if "keyframes" not in entry:
            print("unresolved borrow in %s, dropping" % name, file=sys.stderr)
            del merged[name]

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
