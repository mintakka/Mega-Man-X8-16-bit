extends Reference
class_name CharacterRoster

# The playable roster. Missions ask the player which of these to take in, so the
# ids are what gets stored in the save and what the level swap keys off of.
#
# X is deliberately first and is the fallback for anything unrecognised: he is
# the only character with the armor and boss-weapon systems wired up, so a bad
# id degrading to X keeps a stage playable instead of loading nothing.
const X := "x"
const ZERO := "zero"
const AXL := "axl"

const DEFAULT := X

const scenes := {
	X: "res://src/Actors/Player.tscn",
	ZERO: "res://src/Actors/Player_Zero.tscn",
	AXL: "res://src/Actors/Player_Axl.tscn",
}

# Idle animations for the select screen. These are the same SpriteFrames the
# character plays in-game, so the preview is always the real sprite rather than
# a portrait that could drift out of date.
const select_frames := {
	X: "res://src/Actors/Player/x_sprites/x.res",
	ZERO: "res://src/Actors/Player/zero_sprites/zero.tres",
	AXL: "",
}

const display_names := {
	X: "X",
	ZERO: "ZERO",
	AXL: "AXL",
}

# Stages that ignore the player's pick. Noah's Park is the intro mission and is
# built around X - its cutscenes, dialogue and the armor tutorial all assume him.
const forced_character := {
	"NoahsPark": X,
}

static func exists(id : String) -> bool:
	return scenes.has(id)

static func get_scene_path(id : String) -> String:
	return scenes.get(id, scenes[DEFAULT])

static func get_display_name(id : String) -> String:
	return display_names.get(id, display_names[DEFAULT])

static func get_select_frames(id : String) -> String:
	return select_frames.get(id, "")

#Left-to-right order on the select screen. X sits in the middle because he is
#the default and the only character with the armor and weapon systems. The
#select screen walks this array with left/right, so it has to match the layout
#or the cursor would appear to move the wrong way.
static func get_ids() -> Array:
	return [ZERO, X, AXL]

# Returns the character a stage will actually be played with, which is the
# player's pick unless the stage forces one.
static func resolve_for_stage(stage_name : String, picked : String) -> String:
	if forced_character.has(stage_name):
		return forced_character[stage_name]
	if not exists(picked):
		return DEFAULT
	return picked

# A character scene is only usable once it has actually been created; Zero and
# Axl are added incrementally, so this keeps the select screen honest about
# which entries are real rather than offering a stage that cannot load.
static func is_implemented(id : String) -> bool:
	return exists(id) and ResourceLoader.exists(get_scene_path(id))
