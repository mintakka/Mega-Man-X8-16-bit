extends Node

var failures := []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func wait_physics(frames: int) -> void:
	for _i in frames:
		yield(get_tree(), "physics_frame")

func area_names(camera: Node) -> Array:
	var names := []
	for area in camera.areas:
		names.append(area.name)
	return names

func _ready() -> void:
	CharacterManager.player_character = "X"
	# HUD debug helpers resolve the production player from current_scene. Give
	# the harness root the expected name until the stage spawner registers X.
	var debug_player_placeholder := Node.new()
	debug_player_placeholder.name = "X"
	add_child(debug_player_placeholder)
	var stage = load("res://Axl_mod/Levels/NoahsPark/Stage_NoahsPark.tscn").instance()
	add_child(stage)
	yield(wait_physics(5), "completed")
	var player = GameManager.player
	var camera = stage.get_node("StateCamera")

	GameManager.force_unpause()
	player.set_process(false)
	player.set_physics_process(false)
	player.global_position = Vector2(2838, 400)
	camera.adjust_collisor_position()
	GameManager.force_unpause()
	yield(wait_physics(8), "completed")
	check(camera.area_detector.global_position.distance_to(player.global_position) < 1.0,
		"camera detector drifted away from the player in the lower area")
	check(not area_names(camera).empty(), "lower Noah's Park camera area was not detected")

	player.global_position = Vector2(3080, 190)
	camera.adjust_collisor_position()
	GameManager.force_unpause()
	yield(wait_physics(20), "completed")
	check(camera.area_detector.global_position.distance_to(player.global_position) < 1.0,
		"camera detector drifted away from the player during vertical translation")
	check("16" in area_names(camera), "K-Knuckle camera area was not detected")
	check(camera.custom_limits_top <= 0.0, "K-Knuckle camera did not acquire the upper limit")
	check(camera.global_position.y < 260.0, "camera did not translate toward the K-Knuckle area")

	if failures.empty():
		print("PASS NoahsParkCameraTest")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
