extends Control

# Opened with a hardcoded key that is NOT in the InputMap, so it cannot collide
# with gameplay actions or the key rebinding menu. Once open it navigates with
# the game's own UI actions, so it works on a controller d-pad without needing
# any extra bindings.
const TOGGLE_KEY := KEY_K
const PAUSE_SOURCE := "CheatMenu"

const color_title := Color(1.0, 0.913725, 0.0, 1.0)
const color_idle := Color(0.85098, 0.898039, 1.0, 1.0)
const color_on := Color(0.4, 1.0, 0.45, 1.0)
const color_off := Color(0.42, 0.47, 0.58, 1.0)
const color_icarus := Color(0.45, 0.82, 1.0, 1.0)
const color_hermes := Color(1.0, 0.66, 0.27, 1.0)

const row_nodes := ["god_mode", "infinite_ammo", "infinite_health", "infinite_lives",
	"armor_head", "armor_body", "armor_arms", "armor_legs"]
const row_labels := ["GOD MODE", "WEAPON ENERGY", "LIFE ENERGY", "LIVES",
	"HEAD", "BODY", "ARMS", "LEGS"]
const first_armor_row := 4

onready var panel: Control = $Panel
onready var rows: Control = $Panel/Border/VBox

var open := false
var selected := 0

func _ready() -> void:
	panel.visible = false
	Event.connect("pause_menu_opened",self,"on_pause_menu_opened") # warning-ignore:return_value_discarded
	Event.connect("pause_menu_closed",self,"on_pause_menu_closed") # warning-ignore:return_value_discarded
	refresh()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.scancode == TOGGLE_KEY:
		toggle_menu()
		return
	if not open:
		return
	if event.is_action_pressed("ui_down"):
		move_selection(1)
	elif event.is_action_pressed("ui_up"):
		move_selection(-1)
	#ui_accept is the game's menu confirm (face button left); also accept jump so
	#the bottom face button - what most players reach for - works too.
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept") \
		or event.is_action_pressed("jump"):
		activate(selected)
	elif event.is_action_pressed("ui_left"):
		activate(selected, -1)
	elif event.is_action_pressed("ui_cancel"):
		close_menu()

func toggle_menu() -> void:
	if open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	open = true
	panel.visible = true
	GameManager.pause(PAUSE_SOURCE)
	refresh()

func close_menu() -> void:
	open = false
	panel.visible = false
	GameManager.unpause(PAUSE_SOURCE)

#Never leave the game paused by this menu if the scene changes while it is open.
func _exit_tree() -> void:
	if open:
		open = false
		GameManager.unpause(PAUSE_SOURCE)

func on_pause_menu_opened() -> void:
	close_menu()
	visible = false

func on_pause_menu_closed() -> void:
	visible = true

func move_selection(step : int) -> void:
	selected = wrapi(selected + step, 0, row_nodes.size())
	refresh()

func activate(index : int, direction := 1) -> void:
	if index < first_armor_row:
		match index:
			0: GameManager.set_cheat_god_mode(not GameManager.cheat_god_mode)
			1: GameManager.set_cheat_infinite_ammo(not GameManager.cheat_infinite_ammo)
			2: GameManager.set_cheat_infinite_health(not GameManager.cheat_infinite_health)
			3: GameManager.set_cheat_infinite_lives(not GameManager.cheat_infinite_lives)
	else:
		var slot : String = GameManager.armor_slots[index - first_armor_row]
		GameManager.cycle_cheat_armor(slot, direction)
	refresh()

func refresh() -> void:
	for i in row_nodes.size():
		var row := rows.get_node(row_nodes[i])
		var name_label : Label = row.get_node("name")
		var value_label : Label = row.get_node("value")
		var is_selected : bool = (i == selected)
		name_label.text = ("> " if is_selected else "  ") + row_labels[i]
		name_label.add_color_override("font_color", color_title if is_selected else color_idle)
		if i < first_armor_row:
			display_toggle(value_label, get_toggle_value(i))
		else:
			display_armor(value_label, GameManager.cheat_armor[GameManager.armor_slots[i - first_armor_row]])

func get_toggle_value(index : int) -> bool:
	match index:
		0: return GameManager.cheat_god_mode
		1: return GameManager.cheat_infinite_ammo
		2: return GameManager.cheat_infinite_health
		3: return GameManager.cheat_infinite_lives
	return false

func display_toggle(label : Label, value : bool) -> void:
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
