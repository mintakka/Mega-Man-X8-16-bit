extends Node

var failures := []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func wait_for_transition(menu: CanvasLayer) -> void:
	if menu.fader.transitioning:
		yield(menu.fader, "finished")
	# CoverScreen clears transitioning immediately after emitting finished.
	# Resume on the next frame to model a real subsequent input event.
	yield(get_tree(), "idle_frame")

func press_action(target: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	target._input(event)

func exercise_options(options: CanvasLayer, label: String) -> void:
	options.start()
	yield(wait_for_transition(options), "completed")
	check(options.active and not options.locked, label + ": options did not open")

	var button = options.get_node("Menu/scrollContainer/OptionHolder/cheatcode")
	var cheat = button.get_node("CheatCode")
	button.on_press()
	yield(wait_for_transition(cheat), "completed")
	check(cheat.active and not cheat.locked, label + ": cheat code did not open")
	if label == "title":
		cheat.digits = [4, 7, 3, 6]
		cheat.submit()
	press_action(cheat, "select")
	yield(wait_for_transition(cheat), "completed")
	check(not cheat.active and not options.locked, label + ": cheat code did not return to options")

	# Re-enter the same embedded submenu before leaving Options. This is the
	# lifecycle that used to fail from Pause and after revisiting the title.
	button.on_press()
	yield(wait_for_transition(cheat), "completed")
	if label == "title":
		yield(get_tree().create_timer(1.3, true), "timeout")
	check(cheat.active and not cheat.locked, label + ": cheat code failed to re-enter")
	press_action(cheat, "select")
	yield(wait_for_transition(cheat), "completed")
	options.end()
	yield(wait_for_transition(options), "completed")

func _ready() -> void:
	var title_options = load("res://src/Options/Options.tscn").instance()
	add_child(title_options)
	yield(exercise_options(title_options, "title"), "completed")
	title_options.queue_free()
	yield(get_tree(), "idle_frame")

	var pause = load("res://src/Options/Pause.tscn").instance()
	add_child(pause)
	yield(get_tree().create_timer(0.75, true), "timeout")
	yield(exercise_options(pause.options_menu, "pause"), "completed")
	pause.queue_free()
	yield(get_tree(), "idle_frame")
	GameManager.force_unpause()

	var returned_options = load("res://src/Options/Options.tscn").instance()
	add_child(returned_options)
	yield(exercise_options(returned_options, "returned title"), "completed")
	returned_options.queue_free()
	yield(get_tree(), "idle_frame")

	if failures.empty():
		print("PASS CheatMenuReentryTest")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
