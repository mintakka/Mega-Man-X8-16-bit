extends "res://src/Actors/Props/RideArmor/RepeatAnimation.gd"


func _ready() -> void:
	material = GameManager.player.animatedSprite.material
	#This sprite is X unless the rider has their own cockpit art. It mirrors the
	#mech's animation name and frame index, so a replacement has to carry the
	#same animation names and frame counts.
	var pilot_path := CharacterRoster.get_pilot_frames(GameManager.active_character)
	if pilot_path != "" and ResourceLoader.exists(pilot_path):
		frames = load(pilot_path)
