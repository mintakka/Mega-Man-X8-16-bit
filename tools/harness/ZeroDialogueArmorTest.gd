extends Node

#The shared X dialogue data should be presented as Zero without changing its
#speaker key, and Zero should receive both armor sets' gameplay effects without
#ever enabling X's overlay art.

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	test_dialogue_reskin()
	test_armor_abilities()
	print("ZERO DIALOGUE/ARMOR PASS")
	get_tree().quit()

func test_dialogue_reskin() -> void:
	var dialog = preload("res://src/DialogSystem/DialogBox.tscn").instance()
	add_child(dialog)
	var x_profile = preload("res://src/DialogSystem/Profiles/X.tres")

	GameManager.active_character = CharacterRoster.ZERO
	dialog.setup_character(x_profile)
	assert(dialog.portrait_1.frames.resource_path.get_file() == "zero_dialogue.tres")
	assert(dialog.portrait_1.scale == Vector2(2, 2))
	assert(dialog.displayed_text_palette.resource_path.get_file() == "Red.png")
	assert(dialog.character == "MegaMan X")
	assert(dialog.portrait_1.position.x == dialog.portrait_position_1)
	print("ZERO DIALOGUE portrait=%s palette=%s speaker=%s" % [
		dialog.portrait_1.frames.resource_path.get_file(),
		dialog.displayed_text_palette.resource_path.get_file(),
		dialog.character])

	GameManager.active_character = CharacterRoster.X
	dialog.setup_character(x_profile)
	assert(dialog.portrait_1.frames.resource_path.get_file() == "x_dialogue.res")
	assert(dialog.portrait_1.scale == Vector2.ONE)
	assert(dialog.displayed_text_palette.resource_path.get_file() == "X.png")
	dialog.queue_free()

func test_armor_abilities() -> void:
	GameManager.active_character = CharacterRoster.ZERO
	var player = preload("res://src/Actors/Player.tscn").instance()
	add_child(player)
	assert(player.armor_capable)
	assert(not player.armor_art_enabled)

	for slot in ["head", "body", "arms", "legs"]:
		player.equip_parts("icarus_" + slot)
	assert(player.get_node("JumpDamage").active)
	assert(player.get_node("Damage").damage_reduction == 50)
	assert(player.get_node("Damage").prevent_knockbacks)
	assert(player.get_node("Shot").current_weapon.name == "Icarus Buster")
	assert(player.get_node("Shot").upgraded)
	assert(player.get_node("AirJump").max_air_jumps == 2)
	assert(player.is_full_armor() == "icarus")
	assert(not player.get_node("Charge").active)
	assert(not player.get_node("Armor").is_processing())
	for part in player.get_armor_sprites():
		assert(not part.visible)
	print("ZERO ARMOR icarus=%s weapon=%s art=%s" % [
		player.current_armor, player.get_node("Shot").current_weapon.name,
		player.armor_art_enabled])

	for slot in ["head", "body", "arms", "legs"]:
		player.equip_parts("hermes_" + slot)
	assert(player.get_node("Charge").charge_time_reduction == 0.45)
	assert(player.get_node("LifeSteal").active)
	assert(player.get_node("Damage").damage_reduction == 33)
	assert(player.get_node("Dash").upgraded)
	assert(player.get_node("Shot").current_weapon.name == "Hermes Buster")
	assert(player.is_full_armor() == "hermes")
	for part in player.get_armor_sprites():
		assert(not part.visible)
	print("ZERO ARMOR hermes=%s weapon=%s" % [
		player.current_armor, player.get_node("Shot").current_weapon.name])
