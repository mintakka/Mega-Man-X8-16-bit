extends Control

# Deliberately self-contained:
# - Toggled by hardcoded keys that are NOT in the InputMap, so it cannot collide
#   with gameplay actions (pause/select/debug) or the key rebinding menu.
# - Never pauses the game and never grabs UI focus, so it cannot interfere with
#   the pause menu (Pause.gd gates Start on player.has_control()).
const TOGGLE_KEY := KEY_K

onready var panel: Control = $Panel
onready var god_mode_label: Label = $Panel/VBoxContainer/god_mode
onready var infinite_ammo_label: Label = $Panel/VBoxContainer/infinite_ammo
onready var infinite_health_label: Label = $Panel/VBoxContainer/infinite_health
onready var infinite_lives_label: Label = $Panel/VBoxContainer/infinite_lives

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
		_:
			return
	refresh()

func refresh() -> void:
	god_mode_label.text = "1 God Mode: " + on_off(GameManager.cheat_god_mode)
	infinite_ammo_label.text = "2 Inf. Ammo: " + on_off(GameManager.cheat_infinite_ammo)
	infinite_health_label.text = "3 Inf. Health: " + on_off(GameManager.cheat_infinite_health)
	infinite_lives_label.text = "4 Inf. Lives: " + on_off(GameManager.cheat_infinite_lives)

func on_off(value : bool) -> String:
	return "ON" if value else "OFF"
