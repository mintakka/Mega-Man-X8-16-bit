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
