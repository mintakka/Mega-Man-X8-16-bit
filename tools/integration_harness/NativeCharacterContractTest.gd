extends Node

var failures := []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var scenes := {
		"X": "res://src/Actors/Player/X/PlayerX.tscn",
		"Zero": "res://Zero_mod/X8/Player/PlayerZeroX8.tscn",
		"Axl": "res://Axl_mod/Player/PlayerAxl.tscn"
	}
	var methods := ["has_health", "recover_health", "set_direction", "deactivate", "has_control", "equip_parts", "finished_equipping", "stop_listening_to_inputs", "start_listening_to_inputs", "add_invulnerability", "remove_invulnerability"]
	var nodes := ["animatedSprite", "Damage", "Shot", "Ride"]
	for character in scenes:
		var packed = load(scenes[character])
		check(packed is PackedScene, character + " native scene did not load")
		if not packed is PackedScene:
			continue
		var player = packed.instance()
		for method in methods:
			check(player.has_method(method), character + " is missing shared method " + method)
		for path in nodes:
			check(player.has_node(path), character + " is missing shared node " + path)
		if character == "Zero":
			check(not player.has_node("Charge"), "Zero must not inherit X's Charge ability")
		player.free()

	for character in scenes:
		CharacterManager.player_character = character
		check(CharacterManager.get_player_character_object() is PackedScene, "CharacterManager cannot resolve " + character)

	var pause = load("res://src/Options/Pause.tscn").instance()
	for path in ["pause/Weapons", "pause/WeaponsZero", "pause/WeaponsAxl", "pause/Armor Group", "pause/AbilitiesZero"]:
		check(pause.has_node(path), "Pause HUD is missing " + path)
	pause.free()

	for path in [
		"res://src/DialogSystem/Dialogs/Stages/Antonion_Dialogue.tres",
		"res://Zero_mod/DialogSystem/Dialogs/Stages/Antonion_Dialogue.tres",
		"res://Axl_mod/DialogSystem/Dialogs/Stages/Antonion_Dialogue.tres",
		"res://src/Actors/Props/RideArmor/RideArmor.tscn",
		"res://src/Actors/Props/RideChaser/RideChaser.tscn"
	]:
		check(ResourceLoader.exists(path), "Required dynamic resource is missing: " + path)

	finish()

func finish() -> void:
	if failures.empty():
		print("PASS NativeCharacterContractTest")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
