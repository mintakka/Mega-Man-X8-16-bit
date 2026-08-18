extends Node

# See README.md. Boots a stage as a chosen character and drives real input.
# Overridable from the environment so a whole sweep of stages can be run.
export var character := "zero"
export var level := "res://src/Levels/BoosterForest/Stage_BoosterForest.tscn"

var frames := 0
var player
var saber
var seen := {}
var _last_anim := ""
var buster_walk_start := 0.0
var moving_buster_layer_seen := false
var moving_buster_walk_seen := false
var near_enemy
var far_enemy
var near_mask_touched := false
var far_mask_touched := false
var walk_probe : AnimatedSprite
var walk_probe_frames := {}

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
	#Simulate a save that has armour, which is what put X's armour overlay on
	#top of Zero in Dynasty.
	for part in ["icarus_head", "icarus_body", "hermes_arms", "hermes_legs"]:
		if not part in GameManager.collectibles:
			GameManager.collectibles.append(part)
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
			if character == "zero":
				assert(not player.get_node("Charge").active)
		return

	if frames == 60:
		player.active = true
		player.visible = true
		Event.emit_signal("intro_x")
	if frames >= 61 and frames <= 200:
		var a = player.get_animation()
		if a != _last_anim:
			print("HARNESS f%d intro_anim=%s" % [frames, a])
			_last_anim = a

	# mash fire every 12 frames - this is what a player does
	if frames >= 90 and frames < 180 and (frames - 90) % 12 == 0:
		Input.action_press("fire")
	elif frames >= 91 and frames < 181 and (frames - 91) % 12 == 0:
		Input.action_release("fire")
	# Stage intros have different lengths. End any remaining intro state before the
	# isolated movement/fire checks so `has_control()` means the same thing in
	# every level under test.
	if frames == 200 and player.is_executing("Intro"):
		player.get_node("Intro").EndAbility()

	# Then fire while walking. Zero's MMX-Next firing layer must keep the walk
	# cycle and movement active rather than forcing the stationary X5 recoil pose.
	if frames == 205: Input.action_press("move_right")
	if frames == 219: buster_walk_start = player.global_position.x
	if frames == 220: Input.action_press("alt_fire")
	if frames == 222: Input.action_release("alt_fire")
	if frames >= 220 and frames <= 240 and character == "zero":
		var moving_frames = player.get_node("animatedSprite").frames
		if moving_frames.resource_path.get_file() == "zero_shoot.tres":
			moving_buster_layer_seen = true
			moving_buster_walk_seen = moving_buster_walk_seen or player.get_animation().begins_with("walk")

	if player.get_animation().begins_with("atk_"):
		seen[player.get_animation()] = true

	if frames == 228:
		var f = player.get_node("animatedSprite").frames
		print("HARNESS sprites_after_buster=%s" % f.resource_path.get_file())
		print("HARNESS moving_buster anim=%s distance=%.2f" % [
			player.get_animation(), player.global_position.x - buster_walk_start])
	if frames == 240 and character == "zero":
		print("HARNESS moving_buster layer_seen=%s walk_seen=%s distance=%.2f" % [
			moving_buster_layer_seen, moving_buster_walk_seen,
			player.global_position.x - buster_walk_start])
		assert(moving_buster_layer_seen)
		assert(moving_buster_walk_seen)
		assert(player.global_position.x > buster_walk_start)
	if frames in [65, 130, 250]:
		var spr = player.get_node("animatedSprite")
		var shown = []
		for c in spr.get_children():
			if "armor" in c.name and c.visible:
				shown.append(c.name)
		print("HARNESS f%d armor_parts_visible=%s intro_anim=%s" % [frames, shown, player.get_animation()])
	if frames == 250: Input.action_release("move_right")
	# Once Walk has ended, standing fire selects the dedicated X1 shoot pose (the
	# `recover` animation in the pointing layer), not the X5 hand recoil.
	if frames == 260 and character == "zero": Input.action_press("alt_fire")
	if frames == 262 and character == "zero": Input.action_release("alt_fire")
	if frames == 265 and character == "zero":
		var standing_frames = player.animatedSprite.frames
		print("HARNESS standing_buster anim=%s sprites=%s" % [
			player.get_animation(), standing_frames.resource_path.get_file()])
		assert(player.get_animation() == "recover")
		assert(standing_frames.resource_path.get_file() == "zero_shoot.tres")

	# Put two real enemy damage areas on the same line: one touched by the source
	# saber silhouette and one well beyond it. This catches both no-contact and
	# oversized-hitbox regressions.
	if frames == 270 and character == "zero":
		near_enemy = make_saber_target(Vector2(44, 0))
		far_enemy = make_saber_target(Vector2(100, 0))
	if frames == 280 and character == "zero": Input.action_press("fire")
	if frames == 281 and character == "zero": Input.action_release("fire")
	if frames >= 282 and frames <= 290 and character == "zero" and saber.attack != "":
		var rects = preload("res://src/Actors/Player/zero_sprites/saber_masks.gd").rects_for(
			saber.attack, saber.steps)
		var polygons = saber.make_mask_polygons(rects)
		near_mask_touched = near_mask_touched or saber.masks_hit_receiver(
			polygons, saber.damage_receiver(near_enemy))
		far_mask_touched = far_mask_touched or saber.masks_hit_receiver(
			polygons, saber.damage_receiver(far_enemy))
	if frames == 320 and character == "zero":
		print("HARNESS saber near_hit=%s far_hit=%s near_health=%s" % [
			near_mask_touched, far_mask_touched, near_enemy.current_health])
		assert(near_mask_touched)
		assert(not far_mask_touched)
		assert(near_enemy.current_health <= near_enemy.max_health - 5.0)

	if frames == 340:
		print("HARNESS slashes seen: ", seen.keys())
		if character != "zero":
			print("HARNESS SURVIVED")
			get_tree().quit()

	# Run the generated steady walk long past its old one-shot duration. The
	# frame must continue changing after it reaches the ranged loop tail.
	if frames == 360 and character == "zero":
		walk_probe = AnimatedSprite.new()
		walk_probe.frames = load("res://src/Actors/Player/zero_sprites/zero.tres")
		walk_probe.animation = "walk"
		walk_probe.play()
		add_child(walk_probe)
	if walk_probe != null:
		walk_probe_frames[walk_probe.frame] = true
	if frames == 480 and character == "zero":
		print("HARNESS long walk frames=%s looping=%s playing=%s" % [
			walk_probe_frames.keys(), walk_probe.frames.get_animation_loop("walk"),
			walk_probe.playing])
		assert(walk_probe.frames.get_animation_loop("walk"))
		assert(walk_probe_frames.size() > 1)
		assert(walk_probe.playing)
		print("HARNESS SURVIVED")
		get_tree().quit()

func make_saber_target(offset : Vector2):
	var enemy := Node2D.new()
	enemy.set_script(preload("res://tools/harness/DummySaberTarget.gd"))
	var area := Area2D.new()
	area.name = "area2D"
	var collision := CollisionShape2D.new()
	collision.name = "collisionShape2D"
	var shape := RectangleShape2D.new()
	shape.extents = Vector2(18, 20)
	collision.shape = shape
	area.add_child(collision)
	enemy.add_child(area)
	enemy.global_position = player.global_position + offset
	get_tree().current_scene.add_child(enemy)
	return enemy
