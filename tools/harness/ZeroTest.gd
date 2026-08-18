extends Node

# See README.md. Boots a stage as a chosen character and drives real input.
# Overridable from the environment so a whole sweep of stages can be run.
export var character := "zero"
export var level := "res://src/Levels/BoosterForest/Stage_BoosterForest.tscn"

var frames := 0
var player
var saber
var seen := {}

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	var env_char = OS.get_environment("HARNESS_CHAR")
	if env_char != "":
		character = env_char
	var env_level = OS.get_environment("HARNESS_LEVEL")
	if env_level != "":
		level = env_level
	GameManager.active_character = character
	GameManager.cheats_unlocked = true
	add_child(load(level).instance())
	print("HARNESS instanced %s as %s" % [level.get_file(), character])

func _physics_process(_d) -> void:
	frames += 1
	if player == null:
		player = GameManager.player
		if player != null:
			saber = player.get_node_or_null("Saber")
			var shot = player.get_node("Shot")
			print("HARNESS f%d player=%s zero_frames=%s saber_active=%s" % [frames, player.name,
				player.get_node("animatedSprite").frames.has_animation("atk_1"),
				saber != null and saber.active])
			print("HARNESS shot normal=%s armpoint=%s actions=%s" % [
				shot.normal_sprites.has_animation("atk_1"),
				shot.arm_pointing_sprites.has_animation("atk_1"), shot.actions])
		return

	if frames == 60:
		player.active = true
		player.visible = true
		player.activate()

	# mash fire every 12 frames - this is what a player does
	if frames >= 90 and frames < 200 and (frames - 90) % 12 == 0:
		Input.action_press("fire")
	elif frames >= 91 and frames < 201 and (frames - 91) % 12 == 0:
		Input.action_release("fire")

	# then the buster
	if frames == 220: Input.action_press("alt_fire")
	if frames == 222: Input.action_release("alt_fire")

	if player.get_animation().begins_with("atk_"):
		seen[player.get_animation()] = true

	if frames == 228:
		var f = player.get_node("animatedSprite").frames
		print("HARNESS sprites_after_buster=%s" % f.resource_path.get_file())

	if frames == 260:
		print("HARNESS slashes seen: ", seen.keys())
		print("HARNESS SURVIVED")
		get_tree().quit()
