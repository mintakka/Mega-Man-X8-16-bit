extends Node

# The code-entry menu must actually be drawn on top of the screen that opened
# it. It is its own CanvasLayer, so occlusion is decided by the absolute `layer`
# number: CheatCode is authored at layer 5 inside Options, which is layer 2 on
# the title screen but layer 6 once Options is instanced into Pause. In-game the
# menu therefore rendered *under* the options screen while still consuming
# input - it looked like it loaded in the background and never appeared.

var failures := []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func wait_for_transition(menu: CanvasLayer) -> void:
	if menu.fader.transitioning:
		yield(menu.fader, "finished")
	yield(get_tree(), "idle_frame")

func exercise(options: CanvasLayer, label: String) -> void:
	options.start()
	yield(wait_for_transition(options), "completed")
	check(options.active and not options.locked, label + ": options did not open")

	var button = options.get_node("Menu/scrollContainer/OptionHolder/cheatcode")
	var cheat = button.get_node("CheatCode")
	button.on_press()
	yield(wait_for_transition(cheat), "completed")

	check(cheat.active and not cheat.locked, label + ": cheat code did not open")
	check(cheat.layer > options.layer,
		label + ": cheat code renders under its host menu (cheat layer " +
		str(cheat.layer) + " vs options layer " + str(options.layer) + ")")
	check(cheat.menu.visible, label + ": cheat code menu never became visible")

	var event := InputEventAction.new()
	event.action = cheat.exit_action
	event.pressed = true
	cheat._input(event)
	yield(wait_for_transition(cheat), "completed")
	check(not cheat.active, label + ": cheat code did not close")
	options.end()
	yield(wait_for_transition(options), "completed")

func _ready() -> void:
	# Title screen: Options is the whole screen, at its authored layer.
	var title_options = load("res://src/Options/Options.tscn").instance()
	add_child(title_options)
	yield(exercise(title_options, "title"), "completed")
	var title_layer: int = title_options.layer
	title_options.queue_free()
	yield(get_tree(), "idle_frame")

	# In-game: Pause re-parents the same Options scene at a much higher layer.
	var pause = load("res://src/Options/Pause.tscn").instance()
	add_child(pause)
	yield(get_tree().create_timer(0.75, true), "timeout")
	check(pause.options_menu.layer > title_layer,
		"Pause no longer raises the options layer; this test would be vacuous")
	yield(exercise(pause.options_menu, "pause"), "completed")
	pause.queue_free()
	yield(get_tree(), "idle_frame")
	GameManager.force_unpause()

	if failures.empty():
		print("PASS CheatMenuLayerTest")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
