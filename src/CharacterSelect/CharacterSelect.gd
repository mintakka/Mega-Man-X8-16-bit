extends Control

# Shown between picking a stage and entering it. The pick is stored on
# GameManager and the screen then hands off to whatever the stage select was
# going to do anyway - the boss intro, or the level itself.
#
# Noah's Park never reaches here: it launches straight from the start menu, and
# CharacterRoster forces X for it regardless, so the intro mission cannot be
# played as anyone else.

const color_selected := Color(1.0, 0.913725, 0.0, 1.0)
const color_idle := Color(0.545098, 0.686275, 0.909804, 1.0)
const color_locked := Color(0.30, 0.33, 0.42, 1.0)

onready var slots : Control = $Slots
onready var fader : ColorRect = $Fader
onready var hint : Label = $hint

var entries := []
var selected := 0
var locked := true

func _ready() -> void:
	GameManager.force_unpause()
	build_entries()
	select_default()
	fade_in()
	#Input stays locked through the fade so a held button from the stage select
	#does not immediately confirm a character.
	Tools.timer(0.5, "unlock", self)

func unlock() -> void:
	locked = false

func build_entries() -> void:
	for id in CharacterRoster.get_ids():
		var slot := slots.get_node_or_null(id)
		if slot == null:
			continue
		var playable : bool = CharacterRoster.is_implemented(id)
		var frames_path : String = CharacterRoster.get_select_frames(id)
		var sprite : AnimatedSprite = slot.get_node("sprite")
		if playable and frames_path != "" and ResourceLoader.exists(frames_path):
			sprite.frames = load(frames_path)
			if sprite.frames.has_animation("idle"):
				sprite.animation = "idle"
				sprite.playing = true
		else:
			sprite.visible = false
		slot.get_node("name").text = CharacterRoster.get_display_name(id)
		entries.append({"id": id, "slot": slot, "playable": playable})
	refresh()

#Starts on whatever the player used last so repeat missions with the same
#character take no input at all.
func select_default() -> void:
	for i in entries.size():
		if entries[i].id == GameManager.picked_character and entries[i].playable:
			selected = i
			refresh()
			return
	move_to_nearest_playable(1)

func move_to_nearest_playable(step : int) -> void:
	for _i in entries.size():
		if entries[selected].playable:
			refresh()
			return
		selected = wrapi(selected + step, 0, entries.size())
	refresh()

func _input(event : InputEvent) -> void:
	if locked or entries.empty():
		return
	if event.is_action_pressed("ui_right"):
		move(1)
	elif event.is_action_pressed("ui_left"):
		move(-1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		confirm()
	elif event.is_action_pressed("ui_cancel"):
		back_to_stage_select()

#Skips over characters that are not implemented yet rather than letting the
#cursor land on them, so the screen can list the full roster without ever
#offering a stage that cannot load.
func move(step : int) -> void:
	var start := selected
	for _i in entries.size():
		selected = wrapi(selected + step, 0, entries.size())
		if entries[selected].playable:
			break
	if selected != start:
		$choice.play()
	refresh()

func refresh() -> void:
	for i in entries.size():
		var entry = entries[i]
		var label : Label = entry.slot.get_node("name")
		var cursor : Control = entry.slot.get_node("cursor")
		if not entry.playable:
			label.add_color_override("font_color", color_locked)
			entry.slot.modulate = Color(1, 1, 1, 0.45)
		else:
			label.add_color_override("font_color", color_selected if i == selected else color_idle)
			entry.slot.modulate = Color.white
		cursor.visible = entry.playable and i == selected

func confirm() -> void:
	if not entries[selected].playable:
		return
	locked = true
	GameManager.picked_character = entries[selected].id
	$pick.play()
	fade_out()
	Tools.timer(0.9, "enter_stage", self)

func enter_stage() -> void:
	GameManager.continue_after_character_select()

func back_to_stage_select() -> void:
	locked = true
	fade_out()
	Tools.timer(0.9, "go_back", self)

func go_back() -> void:
	GameManager.go_to_stage_select()

func fade_in() -> void:
	fader.color = Color.black
	fader.visible = true
	Tools.tween(fader, "color", Color(0, 0, 0, 0), 0.5)

func fade_out() -> void:
	fader.color = Color(0, 0, 0, 0)
	fader.visible = true
	Tools.tween(fader, "color", Color.black, 0.5)
