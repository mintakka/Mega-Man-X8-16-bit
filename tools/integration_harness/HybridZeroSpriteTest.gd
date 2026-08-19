extends Node

const NATIVE_PATH := "res://Zero_mod/X8/Sprites/zerox8.tres"
const CLEAN_NATIVE_PATH := "res://Zero_mod/X8/Sprites/kknuckle/zerox8knuckle.tres"
const HYBRID_PATH := "res://Zero_mod/X8/Sprites/Custom/zerox8_hybrid.tres"
const USER_TEXTURE_PATH := "res://Zero_mod/X8/Sprites/Custom/zero_mmxnext.png"
const DASH_SPEED := 30.0
const CLEAN_NATIVE_ANIMATIONS := ["double_jump", "slide", "talk"]

const USER_ANIMATIONS := [
	"idle", "walk", "walk_start", "jump", "fall", "dash",
	"walljump", "damage", "damage_resist", "recover", "weak", "saber_1",
	"saber_2", "saber_3", "saber_dash", "saber_jump", "saber_land",
	"saber_slide"
]

var failures := []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var native: SpriteFrames = load(NATIVE_PATH)
	var clean_native: SpriteFrames = load(CLEAN_NATIVE_PATH)
	var hybrid: SpriteFrames = load(HYBRID_PATH)
	check(native != null and clean_native != null and hybrid != null,
		"Native, clean-native or hybrid Zero SpriteFrames failed to load")
	if native == null or clean_native == null or hybrid == null:
		finish()
		return

	for animation in native.get_animation_names():
		check(hybrid.has_animation(animation), "Hybrid is missing animation " + animation)
		check(hybrid.get_frame_count(animation) == native.get_frame_count(animation), animation + " frame count changed")
		var expected_speed := DASH_SPEED if animation == "dash" else native.get_animation_speed(animation)
		check(hybrid.get_animation_speed(animation) == expected_speed, animation + " speed changed unexpectedly")
		check(hybrid.get_animation_loop(animation) == native.get_animation_loop(animation), animation + " loop flag changed")

	for animation in USER_ANIMATIONS:
		for frame in hybrid.get_frame_count(animation):
			check(is_user_frame(hybrid.get_frame(animation, frame)), animation + " contains a non-user frame")

	for animation in CLEAN_NATIVE_ANIMATIONS:
		for frame in hybrid.get_frame_count(animation):
			check(frames_match(hybrid.get_frame(animation, frame), clean_native.get_frame(animation, frame)),
				animation + " does not use Zashiko's aligned no-blade frame " + str(frame))

	for animation in ["beam", "enkoujin", "ride", "victory", "youdantotsu"]:
		for frame in hybrid.get_frame_count(animation):
			var texture = hybrid.get_frame(animation, frame)
			if texture != null:
				check(not is_user_frame(texture), animation + " incorrectly replaced Zashiko art")

	var old_black := CharacterManager.black_zero_armor
	var old_nightshade := CharacterManager.nightshade_zero_armor
	var old_custom := CharacterManager.custom_zero_armor
	CharacterManager.black_zero_armor = false
	CharacterManager.nightshade_zero_armor = false
	CharacterManager.custom_zero_armor = false
	var zero = load("res://Zero_mod/X8/Player/PlayerZeroX8.tscn").instance()
	add_child(zero)
	yield(get_tree(), "idle_frame")
	check(zero.uses_user_zero_art(), "Base Zero did not select the hybrid art")
	check(is_user_frame(zero.get_node("animatedSprite").frames.get_frame("idle", 0)), "Base Zero idle is not user art at runtime")
	check(not is_user_frame(zero.get_node("animatedSprite").frames.get_frame("ride", 0)), "Ride art no longer comes from Zashiko")
	zero.queue_free()
	yield(get_tree(), "idle_frame")
	GameManager.player = null

	CharacterManager.black_zero_armor = true
	var black_zero = load("res://Zero_mod/X8/Player/PlayerZeroX8.tscn").instance()
	add_child(black_zero)
	yield(get_tree(), "idle_frame")
	check(not black_zero.uses_user_zero_art(), "Black Zero did not retain its palette-compatible native sheet")
	check(not is_user_frame(black_zero.get_node("animatedSprite").frames.get_frame("idle", 0)), "Black Zero incorrectly uses base user art")
	black_zero.queue_free()
	yield(get_tree(), "idle_frame")
	GameManager.player = null

	CharacterManager.black_zero_armor = old_black
	CharacterManager.nightshade_zero_armor = old_nightshade
	CharacterManager.custom_zero_armor = old_custom
	finish()

func is_user_frame(texture) -> bool:
	return texture is AtlasTexture and texture.atlas != null and texture.atlas.resource_path == USER_TEXTURE_PATH

func frames_match(first, second) -> bool:
	return first is AtlasTexture and second is AtlasTexture \
		and first.atlas.resource_path == second.atlas.resource_path \
		and first.region == second.region and first.margin == second.margin

func finish() -> void:
	if failures.empty():
		print("PASS HybridZeroSpriteTest")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
