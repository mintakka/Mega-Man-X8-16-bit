extends Node

# Confirms the generated Zero pilot can be mirrored frame-for-frame from the
# ride armour and that activation actually moves him into the cockpit.

func _ready() -> void:
	var reference : SpriteFrames = load("res://src/Actors/Props/RideArmor/pilot_sprites/ra_x.res")
	var zero : SpriteFrames = load("res://src/Actors/Props/RideArmor/pilot_sprites/ra_zero.tres")
	for animation in reference.get_animation_names():
		assert(zero.has_animation(animation))
		assert(zero.get_frame_count(animation) == reference.get_frame_count(animation))
		assert(zero.get_animation_speed(animation) == reference.get_animation_speed(animation))
		assert(zero.get_animation_loop(animation) == reference.get_animation_loop(animation))

	var placements := {}
	var first_position
	var final_position
	var atlas_image := Image.new()
	assert(atlas_image.load(ProjectSettings.globalize_path(
		"res://src/Actors/Props/RideArmor/pilot_sprites/ra_zero.png")) == OK)
	for frame_index in zero.get_frame_count("activate"):
		var texture : AtlasTexture = zero.get_frame("activate", frame_index)
		# Read the source PNG so the harness also works before Godot's generated
		# .stex import cache has been refreshed by an export.
		var image := atlas_image.get_rect(texture.region)
		var used := image.get_used_rect()
		if used.has_no_area():
			continue
		placements[str(used.position)] = true
		if first_position == null:
			first_position = used.position
		final_position = used.position
	print("PILOT activate_frames=%d placements=%s first=%s final=%s" % [
		zero.get_frame_count("activate"), placements.keys(), first_position, final_position])
	assert(placements.size() > 1)
	assert(first_position != final_position)
	print("ZERO PILOT PASS")
	get_tree().quit()
