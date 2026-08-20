extends Node

# Confirming a character must survive a cancel press arriving during the fade.
#
# GameStart.on_press() locks the menu and then yields ~0.5s on the fader before
# the stage loads. Character_Selection._input used to check `active` without
# `locked`, so a cancel inside that window ran end() ->
# cancel_character_select_stage(), dropping the player back at stage select
# right after they had picked - the picker appearing to bounce every time.
#
# This is not an exotic input: ui_cancel and dash share both bindings in
# project.godot (key 65 / joypad button 1), so a reflexive dash tap during the
# fade is enough to trigger it.

var failures := []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func send(picker, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	picker._input(event)

func scene_name() -> String:
	var s = get_tree().current_scene
	return s.filename if s else "<none>"

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var stage: Resource = load("res://src/StageSelect/stage_infos/Inferno.tres")
	GameManager.choose_character_for_stage(stage)
	yield(get_tree().create_timer(0.6, true), "timeout")

	check(scene_name().find("Character_Selection") != -1,
		"picker did not open, got " + scene_name())
	if scene_name().find("Character_Selection") == -1:
		finish()
		return
	var picker = get_tree().current_scene
	check(picker.active, "picker is not active")

	# What GameStart.on_press() does before it yields on the fade.
	picker.lock_buttons()
	send(picker, "ui_cancel")
	# end() only clears the mission once its own fade finishes, so wait past it
	# in real time; a few idle frames would pass regardless of the guard.
	yield(get_tree().create_timer(1.5, true), "timeout")

	check(GameManager.has_pending_character_select_stage(),
		"a cancel during the confirm fade discarded the queued mission")
	check(scene_name().find("Character_Selection") != -1,
		"a cancel during the confirm fade left the picker for " + scene_name() +
		"; the player is bounced back after already choosing a character")
	finish()

func finish() -> void:
	GameManager.pending_character_select_stage = null
	if failures.empty():
		print("PASS PickerCancelRaceTest")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error(f)
		get_tree().quit(1)
