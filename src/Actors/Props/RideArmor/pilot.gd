extends "res://src/Actors/Props/RideArmor/RepeatAnimation.gd"


func _ready() -> void:
	material = GameManager.player.animatedSprite.material
	#This sprite is X unless the rider has their own cockpit art. It mirrors the
	#mech's animation name and frame index, so a replacement has to carry the
	#same animation names and frame counts.
	var pilot_path := CharacterRoster.get_pilot_frames(GameManager.active_character)
	if pilot_path != "" and ResourceLoader.exists(pilot_path):
		frames = load(pilot_path)
		custom_pilot = true

#X's cockpit art is blank while the mech sits empty, so his pilot could simply
#be drawn at all times. A replacement built from a single pose has no blank
#frame, which left the rider painted above an unoccupied mech, so an empty
#cockpit has to hide the sprite outright.
var custom_pilot := false
var hidden_by_death := false

const EMPTY_COCKPIT := ["deactivated", "deactivate"]

#The mech hides its pilot on death through this, so that has to outrank the
#cockpit check or the rider would reappear on a wreck.
func hide() -> void:
	hidden_by_death = true
	.hide()

func _process(delta : float) -> void:
	._process(delta)
	if custom_pilot and not hidden_by_death:
		visible = not (main.animation in EMPTY_COCKPIT)
