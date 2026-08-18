extends Node

# Confirms the active Zero identity reaches the pause portrait/life icon and the
# picker exposes only the two characters currently in scope.

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	GameManager.active_character = CharacterRoster.ZERO
	var player = preload("res://src/Actors/Player.tscn").instance()
	add_child(player)

	var hud := Node.new()
	hud.name = "Hud"
	add_child(hud)
	var pause = preload("res://src/Options/Pause.tscn").instance()
	hud.add_child(pause)
	var portrait : TextureRect = pause.get_node("pause/Lives/X_icon")
	portrait.show_parts()
	var life_icon : TextureRect = pause.get_node("pause/Lives/lives_icon")
	print("CHARACTER UI portrait=%s life=%s" % [
		portrait.texture.resource_path.get_file(), life_icon.texture.resource_path.get_file()])
	assert(portrait.texture.resource_path.get_file() == "base_Zero.png")
	assert(life_icon.texture.resource_path.get_file() == "lives_zero.png")

	var picker = preload("res://src/CharacterSelect/CharacterSelectScreen.tscn").instance()
	add_child(picker)
	assert(CharacterRoster.get_ids() == [CharacterRoster.ZERO, CharacterRoster.X])
	assert(picker.entries.size() == 2)
	assert(not picker.get_node("Slots").has_node("axl"))
	print("CHARACTER UI roster=%s" % [CharacterRoster.get_ids()])
	print("CHARACTER UI PASS")
	get_tree().quit()
