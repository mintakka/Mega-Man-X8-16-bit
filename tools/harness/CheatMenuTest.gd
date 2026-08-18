extends Node

# Exercises the real Options button and fade transition into CheatCode. This is
# deliberately signal-driven (the same `pressed` path a controller uses), so it
# catches missing button connections, bad menu paths and a submenu that never
# becomes active.

var frames := 0
var options
var button
var submenu
var pressed_at := -1

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	var cheat_overlay = preload("res://src/HUD/CheatMenu.tscn").instance()
	add_child(cheat_overlay)
	var overlay_panel : Control = cheat_overlay.get_node("Panel")
	assert(overlay_panel.margin_top == -82)
	assert(overlay_panel.margin_bottom == 66)
	print("CHEAT overlay vertical margins=%s/%s" % [
		overlay_panel.margin_top, overlay_panel.margin_bottom])
	options = preload("res://src/Options/Options.tscn").instance()
	add_child(options)
	button = options.get_node("Menu/scrollContainer/OptionHolder/cheatcode")
	submenu = button.get_node("CheatCode")
	options.start()

func _physics_process(_delta : float) -> void:
	frames += 1
	# The options screen deliberately ignores presses during its opening fade.
	# Wait for the real menu unlock instead of guessing how many rendered frames
	# that fade took on this machine.
	if pressed_at < 0 and options.active and not options.locked:
		print("CHEAT before options=%s locked=%s focus_mode=%s submenu=%s" % [
			options.active, options.locked, button.focus_mode, submenu.active])
		button.emit_signal("pressed")
		pressed_at = frames
	if pressed_at >= 0 and frames == pressed_at + 45:
		print("CHEAT after options_locked=%s submenu=%s visible=%s menu_visible=%s" % [
			options.locked, submenu.active, submenu.visible, submenu.menu.visible])
		assert(options.locked)
		assert(submenu.active)
		assert(submenu.visible)
		assert(submenu.menu.visible)
		print("CHEAT TRANSITION PASS")
		get_tree().quit()
