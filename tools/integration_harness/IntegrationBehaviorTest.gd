extends Node

var failures := []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func read_text(path: String) -> String:
	var file := File.new()
	if file.open(path, File.READ) != OK:
		return ""
	var value := file.get_as_text()
	file.close()
	return value

func _ready() -> void:
	check(GameManager.is_collectible_applicable_to_character("icarus_arms", "X"), "X armor rejected for X")
	check(not GameManager.is_collectible_applicable_to_character("icarus_arms", "Zero"), "X armor leaked to Zero")
	check(not GameManager.is_collectible_applicable_to_character("hermes_head", "Axl"), "X armor leaked to Axl")
	check(GameManager.is_collectible_applicable_to_character("black_zero_armor", "Zero"), "Black Zero armor rejected")
	check(not GameManager.is_collectible_applicable_to_character("black_zero_armor", "X"), "Black Zero armor leaked to X")
	check(GameManager.is_collectible_applicable_to_character("white_axl_armor", "Axl"), "White Axl armor rejected")
	check(not GameManager.try_unlock_cheats("0000"), "Wrong cheat code was accepted")
	check(GameManager.try_unlock_cheats("4736"), "Correct cheat code was rejected")

	var options = load("res://src/Options/Options.tscn").instance()
	add_child(options)
	check(options.has_node("Menu/scrollContainer/OptionHolder/Aspect Ratio/Button"), "16:10 option is missing")
	check(options.has_node("Menu/scrollContainer/OptionHolder/cheatcode/CheatCode"), "Cheat-code submenu is missing")
	var hud = load("res://src/HUD/Hud.tscn").instance()
	check(hud.has_node("CheatMenu"), "Runtime cheat menu is missing from HUD")
	var cheat_panel = hud.get_node_or_null("CheatMenu/Panel")
	check(cheat_panel != null and cheat_panel.margin_top == -82.0, "Cheat panel authored Y position regressed")
	hud.free()

	var charge_source := read_text("res://src/Actors/Player/Charge.gd")
	check("Event.emit_signal(\"charged_shot_release\", 2)" in charge_source, "Fast Charge no longer emits normal tier 2")
	check("charged_time >= level_4_charge" in charge_source, "Fast Charge no longer permits held tier 3")
	var zero_source := read_text("res://Zero_mod/X8/Player/PlayerZeroX8.gd")
	check("airdash.max_airdashes = 2" in zero_source, "Base Zero does not have two air dashes")
	check("dmg.prevent_knockbacks = true" in zero_source, "Base Zero knockback resistance is missing")
	var air_dash_source := read_text("res://Zero_mod/Player/AirDashZero.gd")
	var double_jump_source := read_text("res://Zero_mod/Player/DoubleJumpZero.gd")
	check(not "\treduce_air_jumps()\n\tairdash_count -= 1" in air_dash_source, "Air dash still consumes Zero's double jump")
	check(not "\treduce_airdash_count(1)\n\tif character" in double_jump_source, "Double jump still consumes Zero's next air dash")
	var saber_source := read_text("res://Zero_mod/X8/Player/Saber/SaberZeroX8.gd")
	for move in ["saber_combo", "saber_dash", "saber_jump", "saber_wall"]:
		check("character." + move + ".damage = 6" in saber_source, move + " does not one-hit ordinary low-tier enemies")
		check("character." + move + ".hitbox_break_guards = true" in saber_source, move + " does not open breakable guards")

	finish()

func finish() -> void:
	if failures.empty():
		print("PASS IntegrationBehaviorTest")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
