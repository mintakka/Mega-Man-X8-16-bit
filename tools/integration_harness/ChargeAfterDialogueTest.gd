extends Node

# X's buster must still charge after a cutscene conversation.
#
# Cutscenes call deactivate(), which sets block_charging, but they end through
# GameManager.resume_character_inputs -> start_listening_to_inputs, which never
# went through activate() - the only place that used to clear the flag. That
# left X permanently unable to charge for the rest of the stage.

var failures := []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	CharacterManager.player_character = "X"
	var player = CharacterManager.get_player_character_object().instance()
	player.skip_intro = true
	add_child(player)
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")

	var charge = player.get_node("Charge")
	Input.action_press("fire")
	yield(get_tree(), "idle_frame")

	player.activate()
	yield(get_tree(), "idle_frame")
	check(charge._StartCondition(), "X could not charge during ordinary gameplay")

	# A cutscene starts: input off, charge blocked, no charging allowed.
	player.deactivate()
	yield(get_tree(), "idle_frame")
	check(not charge._StartCondition(), "X can charge while cutscene input is disabled")

	# The dialogue ends the way AnimatedText actually ends it.
	GameManager.player = player
	GameManager.resume_character_inputs()
	yield(get_tree(), "idle_frame")
	check(player.listening_to_inputs, "resume_character_inputs did not restore input")
	check(not player.block_charging,
		"block_charging survived the end of the conversation")
	check(charge._StartCondition(),
		"X cannot charge after a cutscene conversation")

	# A cutscene-state refusal must still keep charging blocked.
	player.deactivate()
	GameManager.change_state("Cutscene")
	GameManager.resume_character_inputs()
	yield(get_tree(), "idle_frame")
	check(not charge._StartCondition(),
		"X can charge while GameManager is still in the Cutscene state")
	GameManager.change_state("Normal")

	Input.action_release("fire")
	if failures.empty():
		print("PASS ChargeAfterDialogueTest")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
