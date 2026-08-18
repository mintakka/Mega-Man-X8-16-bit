extends Node

# Headless integration harness: boots a stage as Zero, drives real input through
# the InputMap, and logs what the saber ability actually does frame by frame.
# The renderer is a dummy build, but all game logic runs, which is what matters.

var frames := 0
var player
var saber
var log_until := 0
var script_steps := []

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	GameManager.active_character = "zero"
	GameManager.cheats_unlocked = true
	add_child(load("res://src/Levels/TestLevel.tscn").instance())
	# press fire at these frame numbers, to test the ground combo chain
	script_steps = [90, 94, 98]  # mash quickly - the old window would drop these

func _physics_process(_d) -> void:
	frames += 1

	if player == null:
		player = GameManager.player
		if player != null:
			saber = player.get_node_or_null("Saber")
			print("T%d PLAYER=%s zero_frames=%s saber=%s" % [frames, player.name,
				player.get_node("animatedSprite").frames.has_animation("atk_1"), saber != null])
			print("T%d shot_normal_is_zero=%s" % [frames,
				player.get_node("Shot").normal_sprites.has_animation("atk_1")])
		return

	if frames == 60:
		player.active = true
		player.visible = true
		player.activate()
		print("T%d activated. on_floor=%s anim=%s" % [frames, player.is_on_floor(), player.get_animation()])

	if frames in script_steps:
		Input.action_press("fire")
	elif frames - 1 in script_steps:
		Input.action_release("fire")

	# fire the buster, then slash again, to prove the buster no longer hands
	# Zero X's SpriteFrames and break every saber animation after it
	if frames == 130:
		Input.action_press("alt_fire")
	if frames == 132:
		Input.action_release("alt_fire")
	if frames == 145:
		Input.action_press("fire")
	if frames == 147:
		Input.action_release("fire")

	if frames >= 128 and frames <= 158:
		var fr = player.get_node("animatedSprite").frames
		print("C%d anim=%-12s zero_frames=%s floor=%s" % [frames, player.get_animation(), fr.has_animation("atk_1"), player.is_on_floor()])

	if frames >= 88 and frames <= 118:
		print("T%d anim=%-16s atk=%-8s steps=%-3s exec=%s floor=%s queued=%s" % [frames,
			player.get_animation(), saber.attack, saber.steps, saber.executing,
			player.is_on_floor(), saber.queued_next])

	if frames == 160:
		print("DONE")
		get_tree().quit()
