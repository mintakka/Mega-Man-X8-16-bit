extends Node

var failures := []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	for character in ["X", "Zero", "Axl"]:
		CharacterManager.player_character = character
		var packed: PackedScene = CharacterManager.get_player_character_object()
		var player = packed.instance()
		add_child(player)
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		check(GameManager.player == player, character + " did not register as the active player")
		check(player.has_control() == false, character + " did not honor the shared inactive spawn contract")
		if character == "X":
			check(player.has_node("Charge"), "X's native charge ability is missing")
			player.equip_icarus_legs_parts()
			var x_airdash = player.get_node("AirDash")
			var x_airjump = player.get_node("AirJump")
			x_airdash.airdash_count = 2
			x_airjump.current_air_jumps = 1
			x_airdash.reduce_airdash_count(1)
			check(x_airjump.current_air_jumps == 1,
				"X's air dash consumed his Icarus double jump")
			x_airjump.reduce_air_jumps(1)
			check(x_airdash.airdash_count == 1,
				"X's Icarus double jump consumed his second air dash")

			# Drive the real double jump instead of poking the counters, once
			# with dash held and once without. Holding dash is the normal way
			# to travel, and that path used to still spend an air dash through
			# dashjump_signal() -> "dashjump" -> AirDash.reduce_airdash_count.
			# The player must be listening to inputs first: Character.
			# get_action_pressed returns false while inactive, so the dash
			# branch under test would never execute on a freshly spawned X.
			player.activate()
			yield(get_tree(), "idle_frame")
			check(player.get_action_pressed("dash") == false,
				"dash reported pressed before the test pressed it")
			for dash_held in [false, true]:
				x_airdash.airdash_count = 2
				x_airjump.current_air_jumps = 1
				if dash_held:
					Input.action_press("dash")
				else:
					Input.action_release("dash")
				yield(get_tree(), "idle_frame")
				x_airjump._Setup()
				yield(get_tree(), "idle_frame")
				var label := "dash held" if dash_held else "dash released"
				check(x_airdash.airdash_count == 2,
					"X's double jump (" + label + ") consumed an air dash")
				check(x_airjump.current_air_jumps == 0,
					"X's double jump (" + label + ") did not spend the air jump")
			Input.action_release("dash")
			player.listening_to_inputs = false
			check(not player.get_node("Charge")._StartCondition(),
				"X can start charging while cutscene input is disabled")
		elif character == "Zero":
			check(not player.has_node("Charge"), "Zero inherited an X charge-buster mechanic")
			check(player.get_node("AirDash").max_airdashes == 2, "Zero runtime air-dash count is not two")
			check(player.get_node("AirJump").max_air_jumps == 1, "Zero runtime double-jump count is not one")
			check(player.get_node("Damage").prevent_knockbacks, "Zero runtime knockback resistance is off")
			player.get_node("Shot").activate_saber_moves()
			for move in ["SaberCombo", "SaberDash", "SaberJump", "SaberWall"]:
				check(player.get_node(move).damage == 6, move + " runtime damage regressed")
				check(player.get_node(move).hitbox_break_guards, move + " runtime guard break regressed")
		elif character == "Axl":
			for path in ["Hover", "Dodge", "Shot/Transform", "ShotDirection", "Special"]:
				check(player.has_node(path), "Axl native capability is missing: " + path)
		GameManager.apply_cheats_to_player()
		player.queue_free()
		yield(get_tree(), "idle_frame")
		GameManager.player = null
	if failures.empty():
		print("PASS NativeCharacterBootTest")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
