extends TextureRect
onready var pause: CanvasLayer = $"../../.."

const ZERO_PORTRAIT := preload("res://src/Options/base_Zero.png")
const ZERO_LIFE_ICON := preload("res://src/Options/lives_zero.png")

onready var x_portrait : Texture = texture
onready var lives_icon : TextureRect = $"../lives_icon"
onready var x_life_icon : Texture = lives_icon.texture

onready var hermes_head: TextureRect = $hermes_head
onready var hermes_body: TextureRect = $hermes_body
onready var hermes_arms: TextureRect = $hermes_arms
onready var hermes_legs: TextureRect = $hermes_legs
onready var icarus_head: TextureRect = $icarus_head
onready var icarus_body: TextureRect = $icarus_body
onready var icarus_arms: TextureRect = $icarus_arms
onready var icarus_legs: TextureRect = $icarus_legs

onready var armor_parts = [
	hermes_head,
	hermes_body,
	hermes_arms,
	hermes_legs,
	icarus_head,
	icarus_body,
	icarus_arms,
	icarus_legs
]
func _ready() -> void:
	pause.connect("pause_starting",self,"show_parts")# warning-ignore:return_value_discarded
	Event.listen("changed_weapon",self,"update_colors")

func show_parts() -> void:
	var is_zero := GameManager.active_character == CharacterRoster.ZERO
	texture = ZERO_PORTRAIT if is_zero else x_portrait
	lives_icon.texture = ZERO_LIFE_ICON if is_zero else x_life_icon
	for part in armor_parts:
		if GameManager.is_player_in_scene():
			part.visible = not is_zero and part.name in GameManager.player.current_armor
	
	update_colors()

func update_colors(_n = null) -> void:
	if GameManager.is_player_in_scene():
		if GameManager.active_character == CharacterRoster.ZERO:
			#Zero's derived icons already carry his palette; X's palette shader would
			#recolour them as armor pieces.
			material = null
			lives_icon.material = null
			return
		material = GameManager.player.animatedSprite.material.duplicate()
		material.set_shader_param("Flash",0)
		material.set_shader_param("Charge",0)
		material.set_shader_param("Alpha",1)
		lives_icon.material = material
	
