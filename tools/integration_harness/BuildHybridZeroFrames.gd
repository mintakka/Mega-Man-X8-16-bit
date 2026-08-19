extends Node

# Builds a native-Zashiko SpriteFrames resource whose everyday Zero animations
# use the user's MMX-Next art. Native animation names, frame counts, speeds and
# loop flags are retained so Zashiko's frame-driven combat logic is unchanged.
# Everything not listed here remains byte-for-byte sourced from Zashiko.

const NATIVE_PATH := "res://Zero_mod/X8/Sprites/zerox8.tres"
const USER_PATH := "res://tools/integration_harness/zero_mmxnext_source.tres"
const OUTPUT_PATH := "res://Zero_mod/X8/Sprites/Custom/zerox8_hybrid.tres"

const USER_ANIMATIONS := {
	"idle": "idle",
	"walk": "walk",
	"walk_start": "walk_start",
	"jump": "jump",
	"fall": "fall",
	"dash": "dash",
	"slide": "slide",
	"walljump": "walljump",
	"damage": "damage",
	"damage_resist": "damage_resist",
	"recover": "recover",
	"weak": "weak",
	"saber_1": "atk_1",
	"saber_2": "atk_2",
	"saber_3": "atk_3",
	"saber_dash": "atk_shippuuga",
	"saber_jump": "atk_jump",
	"saber_land": "atk_land",
	"saber_slide": "atk_wall",
}

func _ready() -> void:
	call_deferred("build")

func build() -> void:
	var native: SpriteFrames = load(NATIVE_PATH)
	var user: SpriteFrames = load(USER_PATH)
	if native == null or user == null:
		printerr("Unable to load native or user Zero SpriteFrames")
		get_tree().quit(1)
		return

	var hybrid := SpriteFrames.new()
	if hybrid.has_animation("default"):
		hybrid.remove_animation("default")

	for animation in native.get_animation_names():
		hybrid.add_animation(animation)
		hybrid.set_animation_loop(animation, native.get_animation_loop(animation))
		hybrid.set_animation_speed(animation, native.get_animation_speed(animation))

		var native_count := native.get_frame_count(animation)
		if USER_ANIMATIONS.has(animation):
			var user_animation: String = USER_ANIMATIONS[animation]
			if not user.has_animation(user_animation):
				printerr("Missing user animation: ", user_animation)
				get_tree().quit(1)
				return
			copy_resampled_frames(user, user_animation, hybrid, animation, native_count)
		else:
			for frame in native_count:
				hybrid.add_frame(animation, native.get_frame(animation, frame))

	var error := ResourceSaver.save(OUTPUT_PATH, hybrid)
	if error != OK:
		printerr("Unable to save hybrid Zero SpriteFrames: ", error)
		get_tree().quit(1)
		return
	print("Built ", OUTPUT_PATH, " with ", USER_ANIMATIONS.size(), " user-art animations")
	get_tree().quit(0)

func copy_resampled_frames(source: SpriteFrames, source_animation: String,
		destination: SpriteFrames, destination_animation: String,
		destination_count: int) -> void:
	var source_count := source.get_frame_count(source_animation)
	for frame in destination_count:
		var source_frame := 0
		if destination_count > 1 and source_count > 1:
			source_frame = int(round(float(frame) * float(source_count - 1) / float(destination_count - 1)))
		destination.add_frame(destination_animation, source.get_frame(source_animation, source_frame))
