#!/usr/bin/env bash
# Regenerate Zero's atlas and SpriteFrames from the MMX-Next GameMaker project.
#
# Rerun this after pulling new art into MMX-Next, then let Godot reimport
# (opening the editor is enough) so zero.png.import picks the new atlas up.
set -euo pipefail

MMX_NEXT="${MMX_NEXT:-$(cd "$(dirname "$0")/../../MMX-Next" && pwd)}"
OUT="src/Actors/Player/zero_sprites"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SPRITES="spr_zero_idle,spr_zero_walk,spr_zero_jump,spr_zero_dash,spr_zero_wall,\
spr_zero_crouch,spr_zero_dolor2,spr_zero_atk_1,spr_zero_atk_2,spr_zero_atk_3,\
spr_zero_atk_jump,spr_zero_atk_land,spr_zero_atk_wall,spr_zero_intro,\
spr_zero_teleport,spr_zero_outro"

# Godot-facing name = GML name, so Zero answers to the animation names the
# existing ability nodes already drive.
ALIAS="damage=dolor2,slide=wall_slide,walljump=wall_jump"

ANIMS="idle,walk,jump,fall,land,dash,dash_end,slide,walljump,crouch,crouch_end,\
damage,intro,teleport,outro,atk_1,atk_1_end,atk_2,atk_2_end,atk_3,atk_3_end,\
atk_jump,atk_jump_end,atk_land,atk_land_end,atk_wall,atk_wall_end"

mkdir -p "$OUT"

python3 tools/gml_rip.py \
	--sprites-dir "$MMX_NEXT/sprites" \
	--names "$SPRITES" \
	--out-png "$OUT/zero.png" \
	--out-index "$WORK/index.json" \
	--columns 12

python3 tools/gml_anims.py \
	"$MMX_NEXT/scripts/player_animations/player_animations.gml" \
	"$MMX_NEXT/scripts/player_zero_animations/player_zero_animations.gml" \
	--out "$WORK/anims.json" >/dev/null

python3 tools/build_spriteframes.py \
	--index "$WORK/index.json" \
	--anims "$WORK/anims.json" \
	--atlas "$OUT/zero.png" \
	--prefix "spr_zero_" \
	--alias "$ALIAS" \
	--only "$ANIMS" \
	--out "$OUT/zero.tres"
