extends Node

var failures := []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var picker_scene: PackedScene = load("res://System/Screens/CharacterSelection/Character_Selection.tscn")
	check(picker_scene != null, "Zashiko character picker failed to load")
	for character in ["X", "Zero", "Axl"]:
		CharacterManager.player_character = character
		var picker = picker_scene.instance()
		add_child(picker)
		yield(get_tree(), "idle_frame")
		var carousel = picker.get_node("Menu/characters/panel/char_container")
		check(carousel.get_child(1).name == character, "Picker did not center the current character: " + character)
		picker.queue_free()
		yield(get_tree(), "idle_frame")

	var marker := Resource.new()
	GameManager.pending_character_select_stage = marker
	check(GameManager.has_pending_character_select_stage(), "Queued mission was not retained for the picker")
	GameManager.pending_character_select_stage = null
	check(not GameManager.has_pending_character_select_stage(), "Queued mission did not clear")
	finish()

func finish() -> void:
	if failures.empty():
		print("PASS MissionCharacterPickerTest")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
