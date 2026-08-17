extends Control

# Deliberately self-contained:
# - Toggled by hardcoded keys that are NOT in the InputMap, so it cannot collide
#   with gameplay actions (pause/select/debug) or the key rebinding menu.
# - Never pauses the game and never grabs UI focus, so it cannot interfere with
#   the pause menu (Pause.gd gates Start on player.has_control()).
const TOGGLE_KEY := KEY_K

const color_on := Color(0.4, 1.0, 0.45, 1.0)
const color_off := Color(0.42, 0.47, 0.58, 1.0)
const color_icarus := Color(0.45, 0.82, 1.0, 1.0)
const color_hermes := Color(1.0, 0.66, 0.27, 1.0)

onready var panel: Control = $Panel
onready var god_mode_value: Label = $Panel/Border/VBox/god_mode/value
onready var infinite_ammo_value: Label = $Panel/Border/VBox/infinite_ammo/value
onready var infinite_health_value: Label = $Panel/Border/VBox/infinite_health/value
onready var infinite_lives_value: Label = $Panel/Border/VBox/infinite_lives/value
onready var armor_values := {
	"head": $Panel/Border/VBox/armor_head/value,
	"body": $Panel/Border/VBox/armor_body/value,
	"arms": $Panel/Border/VBox/armor_arms/value,
	"legs": $Panel/Border/VBox/armor_legs/value,
}

func _ready() -> void:
	panel.visible = false
	refresh()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.scancode == TOGGLE_KEY:
		panel.visible = not panel.visible
		refresh()
		return
	if not panel.visible:
		return
	match event.scancode:
		KEY_1:
			GameManager.set_cheat_god_mode(not GameManager.cheat_god_mode)
		KEY_2:
			GameManager.set_cheat_infinite_ammo(not GameManager.cheat_infinite_ammo)
		KEY_3:
			GameManager.set_cheat_infinite_health(not GameManager.cheat_infinite_health)
		KEY_4:
			GameManager.set_cheat_infinite_lives(not GameManager.cheat_infinite_lives)
		KEY_5:
			GameManager.cycle_cheat_armor("head")
		KEY_6:
			GameManager.cycle_cheat_armor("body")
		KEY_7:
			GameManager.cycle_cheat_armor("arms")
		KEY_8:
			GameManager.cycle_cheat_armor("legs")
		_:
			return
	refresh()

func refresh() -> void:
	display(god_mode_value, GameManager.cheat_god_mode)
	display(infinite_ammo_value, GameManager.cheat_infinite_ammo)
	display(infinite_health_value, GameManager.cheat_infinite_health)
	display(infinite_lives_value, GameManager.cheat_infinite_lives)
	for slot in armor_values.keys():
		display_armor(armor_values[slot], GameManager.cheat_armor[slot])

func display(label : Label, value : bool) -> void:
	label.text = "ON" if value else "OFF"
	label.add_color_override("font_color", color_on if value else color_off)

func display_armor(label : Label, set_name : String) -> void:
	label.text = set_name.to_upper()
	match set_name:
		"icarus":
			label.add_color_override("font_color", color_icarus)
		"hermes":
			label.add_color_override("font_color", color_hermes)
		_:
			label.add_color_override("font_color", color_off)
