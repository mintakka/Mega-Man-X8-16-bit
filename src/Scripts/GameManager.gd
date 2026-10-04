extends Node

const codename: String = "X8ZASHIKO"
var version: String = "1.0.0.4-b-integration"
var current_demo: String = "Zashiko Edition"

var player: Character
var camera: Camera2D
var state: String = "Normal"
var bikes: Array = []
var debug_actions: Array = []
var debug_skip: int = 1
var collectibles: Array = []
var equip_exceptions: Array = []
var equip_hearts: bool = true
var equip_subtanks: bool = true
var seen_dialogues: Array = []
var current_level: String
const heal_spawn: PackedScene = preload("res://src/Objects/Heal.tscn")
const small_heal_spawn: PackedScene = preload("res://src/Objects/SmallHeal.tscn")
const ammo_spawn: PackedScene = preload("res://src/Objects/Pickups/Ammo.tscn")
const small_ammo_spawn: PackedScene = preload("res://src/Objects/Pickups/SmallAmmo.tscn")
const life_spawn: PackedScene = preload("res://src/Objects/Pickups/ExtraLife.tscn")
var last_time_debug_reset: float = 0.0
var end_stage_timer: float = 0.0
var stage_start_msec: float = 0.0
#Checkpoint
var checkpoint: CheckpointSettings

var checkpoint_cam_width: Vector2 = Vector2.ZERO
var checkpoint_cam_height: Vector2 = Vector2.ZERO
var BETA: bool = false

# The game is authored at 398x224. The optional 16:10 mode exposes additional
# vertical playfield while keeping menu scenes at their authored height.
const view_width := 398
const view_height_16_9 := 224
const view_height_16_10 := 249
const aspect_config_key := "Widescreen"
var view_height: int = view_height_16_9
var Resolution = Vector2(view_width, view_height_16_9)

var rng
var true_delta: float = 0.0


#Life System
const player_life_count: String = "player_lives"
var current_stage_info
var pending_character_select_stage

var time_attack:= false
var ta_status := "Recording..."

var ghost_file = "user://score.save"

var maximum_distance := Vector2(480,320)
var maximum_bike_distance := Vector2(199,100)
var debug_go_to_next_stage := false
var best_recording := []

var music_player
var music_volume := -6.0
var dialog_box

var player_died := false
var pause_sources: Array

var debug_enabled := true
var last_player_position := Vector2.ZERO

var lumine_boss_order : Array

func _ready() -> void :
	print ("GameManager: Initializing...")
	set_pause_mode(2)
	fix_unmapped_joypads()
	Input.connect("joy_connection_changed", self, "on_joy_connection_changed")
	BossRNG.initialize()
	Savefile.load_latest_save()
	Savefile.load_config_data()
	apply_aspect_ratio()
	on_level_start()

func _physics_process(delta: float) -> void :
	true_delta = delta / Engine.time_scale
	handle_end_of_level(delta)
	if cheat_infinite_health and is_player_in_scene() and player.has_health():
		player.current_health = player.max_health
	set_canvas_height(target_view_height())
	
	if Input.is_action_just_pressed("fullscreen"):
		OS.window_fullscreen = not OS.window_fullscreen
		Configurations.set("Fullscreen", OS.window_fullscreen)
		Savefile.save(Savefile.save_slot)

func get_native_size() -> Vector2:
	return Vector2(view_width, view_height)

func is_widescreen() -> bool:
	return Configurations.get(aspect_config_key) == true

func get_aspect_name() -> String:
	return "16:10" if is_widescreen() else "16:9"

func configured_view_height() -> int:
	return view_height_16_10 if is_widescreen() else view_height_16_9

func target_view_height() -> int:
	if is_widescreen() and is_in_gameplay_scene():
		return view_height_16_10
	return view_height_16_9

func is_in_gameplay_scene() -> bool:
	var scene = get_tree().current_scene
	if not scene:
		return false
	var path: String = scene.filename
	return path.begins_with("res://src/Levels/") or path.begins_with("res://Axl_mod/Levels/") or path.begins_with("res://Zero_mod/Levels/")

func apply_aspect_ratio() -> void:
	set_canvas_height(target_view_height())
	update_window_size()

func set_canvas_height(new_height: int) -> void:
	if view_height == new_height:
		return
	view_height = new_height
	Resolution = get_native_size()
	get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_2D, SceneTree.STRETCH_ASPECT_KEEP, Resolution)
	Event.emit_signal("aspect_ratio_changed")

func get_window_native_size() -> Vector2:
	return Vector2(view_width, configured_view_height())

func update_window_size() -> void:
	if Configurations.get("Fullscreen"):
		return
	var multiplier = Configurations.get("WindowSize")
	if not multiplier:
		multiplier = 3
	OS.set_window_size(get_window_native_size() * multiplier)

# Handheld Daemon's emulated Xbox pad is missing from Godot 3.5's bundled
# database. Register only that GUID family, leaving all known pads untouched.
const unmapped_joypad_guids := ["5e0400008f02"]
const xpad_mapping_body := ",a:b0,b:b1,back:b6,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b8,leftshoulder:b4,leftstick:b9,lefttrigger:a2,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b10,righttrigger:a5,rightx:a3,righty:a4,start:b7,x:b2,y:b3,platform:Linux,"

func on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		fix_unmapped_joypad(device)

func fix_unmapped_joypads() -> void:
	for device in Input.get_connected_joypads():
		fix_unmapped_joypad(device)

func fix_unmapped_joypad(device: int) -> void:
	var guid: String = Input.get_joy_guid(device)
	for fragment in unmapped_joypad_guids:
		if fragment in guid:
			var joy_name: String = Input.get_joy_name(device).replace(",", "")
			Input.add_joy_mapping(guid + "," + joy_name + xpad_mapping_body, true)
			return

func start_dialog(dialog_tree) -> void:
	dialog_box.startup(dialog_tree)

func start_capsule_dialog(dialog_tree) -> void:
	dialog_box.startup(dialog_tree)
	dialog_box.connect("dialog_concluded",self,"play_stage_song")

func stop_character_inputs() -> void:
	player.stop_listening_to_inputs()

func resume_character_inputs() -> void:
	print("Resuming Character Inputs...")
	player.start_listening_to_inputs()

func play_song(song : AudioStream) -> void:
	music_player.play_song(song)
	
func play_stage_song() -> void:
	music_player.play_stage_song()

func is_player_in_scene() -> bool:
	if player and is_instance_valid(player):
		return true
	return false

func half_music_volume() -> void:
	Event.emit_signal("half_music_volume")
	if music_player:
		music_volume = music_player.volume_db
		music_player.volume_db = music_volume - 10
	else:
		push_warning("GameManager: No MusicPlayer found.")
	
func normal_music_volume() -> void:
	Event.emit_signal("normal_music_volume")
	if music_player:
		music_player.volume_db = music_volume
	else:
		push_warning("GameManager: No MusicPlayer found.")


func on_level_start():
	print ("GameManager: On Level Start...")
	last_player_position = Vector2.ZERO
	player = null
	bikes.clear()
	change_state("Normal")
	call_deferred("add_collectibles_to_player")
	call_deferred("emit_stage_start_signal")
	call_deferred("save_stage_start_msec")
	call_deferred("position_player_on_checkpoint")
	call_deferred("start_stage_music")
	end_stage_timer = 0
	BossRNG.reset_seed()
	IGT.set_timer_running(true)

func start_stage_music() -> void:
	if is_instance_valid(music_player):
		music_player.call_deferred("play_stage_song")

func start_level(StageName : String) -> void:
	
	clear_checkpoint()
	set_player_lives_to_at_least_2()
	current_level = StageName
	var path: String
	if StageName == "NoahsPark":
		path = "res://src/Levels/NoahsPark/Intro_NoahsPark.tscn"
	elif StageName == "NoahsPark2":
		path = "res://Axl_mod/Levels/NoahsPark/Stage_NoahsPark.tscn"
	else:
		path = "res://src/Levels/" + StageName + "/Stage_" + StageName + ".tscn"
	var _dv = get_tree().change_scene(path)
	call_deferred("restart_level")
	IGT.reset_stage_timer()

func set_player_lives_to_at_least_2() -> void:
	if not GlobalVariables.exists(player_life_count) or GlobalVariables.get(player_life_count) < 2:
		GlobalVariables.set(player_life_count, 2)

func go_to_intro() -> void:
	print_debug(":::::::: going to intro")
	# Returning from the in-game Options screen must not carry PauseMenu into the
	# new title scene. A paused SceneTree made later submenu visits look frozen.
	force_unpause()
	var _dv = get_tree().change_scene("res://src/Title/IntroCapcom.tscn")

func go_to_disclaimer() -> void:
	print_debug(":::::::: going to disclaimer")
	var _dv = get_tree().change_scene("res://src/Title/DisclaimerScreen.tscn")

func go_to_igt() -> void:
	print_debug(":::::::: going to igt screen")
	var _dv = get_tree().change_scene("res://src/Screens/IGTScreen.tscn")
	GameManager.call_deferred("restart_level")

func end_level():
	Event.emit_signal("fade_out")
	end_stage_timer = 0.01
	GameManager.pause("EndLevel")
	debug_go_to_next_stage = true
	Savefile.save(Savefile.save_slot)
	IGT.save_time()

var won_against_final_boss := false

func end_game():
	Event.emit_signal("final_fade_out")
	end_stage_timer = 0.01
	GameManager.pause("EndGame")
	debug_go_to_next_stage = true
	won_against_final_boss = true
	Savefile.save(Savefile.save_slot)
	CharacterManager._save()
	IGT.save_time()

func on_death():
	Event.emit_signal("fade_out")
	end_stage_timer = 0.01
	GameManager.pause("Death")
	BossRNG.player_died()
	Savefile.save(Savefile.save_slot)
	player_died = true

func finished_fade_out() -> void :
	if player_died:
		player_died = false
		if current_level == "NoahsPark":
			call_deferred("restart_level")
		elif GlobalVariables.get(player_life_count) > 0 or cheat_infinite_lives:
			handle_player_death()
			call_deferred("restart_level")
		else:
			Event.emit_signal("game_over")
			call_deferred("go_to_stage_select")
	else:
		if won_against_final_boss:
			won_against_final_boss = false
			call_deferred("go_to_end_cutscene")
		elif weapon_got and weapon_got != "none":
			call_deferred("go_to_weapon_get")
		else:
			call_deferred("go_to_stage_select")

func go_to_end_cutscene():
	print_debug(":::::::: going to final cutscene")
	var _dv = get_tree().change_scene("res://src/Levels/SigmaPalace/FinalCutscene.tscn")
	call_deferred("force_unpause")
	call_deferred("on_level_start")

func go_to_elevator_cutscene():
	var _dv = get_tree().change_scene("res://Final Cutscene/ElevatorCutscene.tscn")
	call_deferred("force_unpause")
	call_deferred("on_level_start")

func go_to_credits():
	print_debug(":::::::: going to final cutscene")
	var _dv = get_tree().change_scene("res://src/Levels/SigmaPalace/CreditsScene.tscn")
	call_deferred("force_unpause")
	call_deferred("on_level_start")

func handle_player_death() -> void :
	if cheat_infinite_lives:
		return
	var lives = GlobalVariables.get(player_life_count)
	var life_subtract = 1
	GlobalVariables.set(player_life_count, lives - life_subtract)
	if CharacterManager.game_mode < 0:
		fill_subtanks()

func go_to_stage_select() -> void :
	pending_character_select_stage = null
	var _dv = get_tree().change_scene("res://src/StageSelect/StageSelectScreen.tscn")
	IGT.set_timer_running(true)

# Stage Select queues the mission here before opening Zashiko's full character
# carousel. The selected character is committed only when the player confirms;
# cancelling simply returns to the map without changing campaign progress.
func choose_character_for_stage(stage) -> void:
	pending_character_select_stage = stage
	IGT.set_timer_running(false)
	var _dv = get_tree().change_scene("res://System/Screens/CharacterSelection/Character_Selection.tscn")

func has_pending_character_select_stage() -> bool:
	return pending_character_select_stage != null

func cancel_character_select_stage() -> void:
	pending_character_select_stage = null
	go_to_stage_select()

func start_pending_character_select_stage() -> void:
	var stage = pending_character_select_stage
	pending_character_select_stage = null
	if stage == null:
		go_to_stage_select()
		return
	if stage.should_play_stage_intro():
		go_to_stage_intro(stage)
	else:
		start_level(stage.get_load_name())

func go_to_weapon_get() -> void :
	if CharacterManager.player_character == "X":
		var _dv = get_tree().change_scene("res://src/WeaponGet/WeaponGetScene.tscn")
	elif CharacterManager.player_character == "Axl":
		var _dv = get_tree().change_scene("res://Axl_mod/WeaponGet/WeaponGetScene.tscn")
	elif CharacterManager.player_character == "Zero":
		var _dv = get_tree().change_scene("res://src/StageSelect/StageSelectScreen.tscn")
	call_deferred("force_unpause")
	call_deferred("on_level_start")
	IGT.set_timer_running(false)

func go_to_stage_intro(stage) -> void:
	print_debug(":::::::: going to stage and boss intro")
	current_stage_info = stage
	var _dv = get_tree().change_scene("res://src/Actors/Bosses/BossIntro/BossIntro.tscn")

func restart_level():
	print_debug("::::::::  Restarting level")
	get_tree().reload_current_scene()# warning-ignore:return_value_discarded
	GameManager.force_unpause()
	on_level_start()

func reached_checkpoint(new_checkpoint: CheckpointSettings) -> void :
	if GameManager.time_attack:
		return

	if not checkpoint or new_checkpoint.id > checkpoint.id:
		set_checkpoint(new_checkpoint)
	else:
		print_debug("GameManager: Checkpoint not set: " + str(checkpoint.id))

func set_checkpoint(new_checkpoint: CheckpointSettings) -> void :
	checkpoint = new_checkpoint
	Event.emit_signal("reached_checkpoint",new_checkpoint)
	print_debug("GameManager: New checkpoint: " + str(checkpoint.id))

func clear_checkpoint() -> void:
	checkpoint = null

func position_player_on_checkpoint() -> void:
	if not player:
		return
		
	if GameManager.time_attack:
		return
		
	if checkpoint:
		player.global_position = checkpoint.respawn_position
		player.set_direction(checkpoint.character_direction)
		var last_checkpoint_door = get_node_or_null(checkpoint.last_door)
		if last_checkpoint_door and last_checkpoint_door.has_method("reached_checkpoint"):
			last_checkpoint_door.reached_checkpoint()
		if CharacterManager.game_mode == 2:
			if checkpoint.id >= 3:
				var life_up = life_spawn.instance()
				get_tree().current_scene.add_child(life_up)
				life_up.global_position = checkpoint.respawn_position
		Event.emit_signal("moved_player_to_checkpoint", checkpoint)

func set_player(object: Character) -> void :
	player = object
	player.active = false
	player.visible = false
	player.deactivate()
	call_deferred("apply_cheats_to_player")

func add_collectibles_to_player() -> void :
	if player:
		for collectible in collectibles:
			if not has_equip_exception(collectible) and is_collectible_applicable_to_character(collectible):
				player.equip_parts(collectible)
		player.finished_equipping()

# Campaign progress is shared, but character-specific equipment is not. Each
# native player still receives hearts, tanks, and the weapons it understands.
func is_collectible_applicable_to_character(collectible: String, character: String = "") -> bool:
	if character.empty():
		character = CharacterManager.player_character
	var item := collectible.to_lower()
	if "icarus" in item or "hermes" in item or "ultima" in item:
		return character == "X"
	if "black_zero" in item or item.ends_with("_zero") or item.begins_with("zero_") or item == "z_saber_zero":
		return character == "Zero"
	if "white_axl" in item or item.ends_with("_axl") or item.begins_with("axl_"):
		return character == "Axl"
	return true

func has_equip_exception(collectible: String) -> bool:
	if is_armor(collectible):
		for exception in equip_exceptions:
			if exception in collectible:
				return true
				
	elif is_heart(collectible):
		if not equip_hearts:
			return true
			
	elif is_subtank(collectible):
		if not equip_subtanks:
			return true
			
	return false

func add_equip_exception(armor_part: String) -> void :
	if not armor_part in equip_exceptions:
		equip_exceptions.append(armor_part)
	else:
		equip_exceptions.erase(armor_part)
		equip_exceptions.append(armor_part)

func remove_equip_exception(armor_part: String) -> void :
	equip_exceptions.erase(armor_part)

func add_collectible_to_savedata(collectible: String) -> void :
	if not is_collectible_in_savedata(collectible):
		collectibles.append(collectible)
	else:
		reposition_collectible_in_savedata(collectible)

func remove_collectible_from_savedata(collectible: String) -> void :
	if is_collectible_in_savedata(collectible):
		collectibles.erase(collectible)

func is_collectible_in_savedata(collectible: String) -> bool:
	return collectible in collectibles

func reposition_collectible_in_savedata(collectible: String) -> void :
	collectibles.erase(collectible)
	collectibles.append(collectible)

func set_stretch_mode(mode) -> void :
	get_tree().set_screen_stretch(mode, SceneTree.STRETCH_ASPECT_KEEP, get_native_size())

func reset_stretch_mode() -> void :
	if Configurations.get("StretchMode"):
		get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_VIEWPORT, SceneTree.STRETCH_ASPECT_KEEP, get_native_size())
	else:
		get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_2D, SceneTree.STRETCH_ASPECT_KEEP, get_native_size())

func handle_end_of_level(delta: float) -> void :
	if end_stage_timer > 0:
		end_stage_timer += delta
		if end_stage_timer > 1:
			GameManager.force_unpause()

var primrose_paused: bool = false

func primrose_pause() -> void :
	pause("Primrose")

func primrose_unpause() -> void :
	unpause("Primrose")

func pause(source: String) -> void :
	if not source in pause_sources:
		pause_sources.append(source)
	update_pause_state()

func unpause(source: String) -> void :
	pause_sources.erase(source)
	update_pause_state()

func force_unpause() -> void :
	pause_sources.clear()
	update_pause_state()

func update_pause_state() -> void :
	if pause_sources.size() > 0:
		get_tree().paused = true
		Event.emit_signal("pause")
	else:
		get_tree().paused = false
		Event.emit_signal("unpause")

func is_on_screen(target_global_position: Vector2) -> bool:
	return abs(camera.get_camera_screen_center().x - target_global_position.x) < 230 and abs(camera.get_camera_screen_center().y - target_global_position.y) < 150

func precise_is_on_screen(target_global_position: Vector2) -> bool:
	return abs(camera.get_camera_screen_center().x - target_global_position.x) < 200 and abs(camera.get_camera_screen_center().y - target_global_position.y) < 128

func is_on_camera(object : Node) -> bool:
	if camera == null: #avoiding reset level bug
		return false 
	var max_distance_from_camera_center := Vector2(196 + 64, 112 + 64)
	return is_pos_nearby(camera.get_camera_screen_center(), object.global_position, max_distance_from_camera_center)

func is_player_nearby(object : Node) -> bool:
	if player == null: #avoiding reset level bug
		return false 
	
	return is_nearby(player, object, maximum_distance)

func is_bike_nearby(object : Node) -> bool:
	for bike in bikes:
		if object != bike:
			if is_nearby(object,bike,maximum_bike_distance) and bike.has_health():
				Log.msg("Bike detected nearby: " + bike.name)
				return true
	return false

func is_nearby(object1 : Node, object2 : Node, distance : Vector2) -> bool:
	if not is_instance_valid(object1):
		return false
	elif not is_instance_valid(object2):
		return false
	else:
		if not object1.is_inside_tree() and not object2.is_inside_tree():
			return abs(object1.position.x - object2.position.x) < distance.x and \
				   abs(object1.position.y - object2.position.y) < distance.y
		elif not object1.is_inside_tree():
			return abs(object1.position.x - object2.global_position.x) < distance.x and \
				   abs(object1.position.y - object2.global_position.y) < distance.y
		elif not object2.is_inside_tree():
			return abs(object1.global_position.x - object2.global.x) < distance.x and \
				   abs(object1.global_position.y - object2.global.y) < distance.y

		return abs(object1.global_position.x - object2.global_position.x) < distance.x and \
			   abs(object1.global_position.y - object2.global_position.y) < distance.y

func is_pos_nearby(pos1 : Vector2, pos2 : Vector2, distance : Vector2) -> bool:
	return abs(pos1.x - pos2.x) < distance.x and \
		   abs(pos1.y - pos2.y) < distance.y

func save_stage_start_msec():
	stage_start_msec = OS.get_ticks_msec()

func get_stage_start_msec() -> float:
	return stage_start_msec

func change_state(new_state : String) -> void:
	state = new_state

func get_state() -> String:
	return state

var drop_item_chance_default: float = 25.0
var small_health_chance_default: float = 30.0
var big_health_chance_default: float = 15.0
var small_ammo_chance_default: float = 15.0
var big_ammo_chance_default: float = 10.0
var extra_life_chance_default: float = 0.1

func get_next_spawn_item(
	drop_item_chance: float = drop_item_chance_default, 
	small_health_chance: float = small_health_chance_default, 
	big_health_chance: float = big_health_chance_default, 
	small_ammo_chance: float = small_ammo_chance_default, 
	big_ammo_chance: float = big_ammo_chance_default, 
	extra_life_chance: float = extra_life_chance_default
) -> PackedScene:
	
	var chance: float = randf() * 100
	if chance > drop_item_chance:
		return null
		
	var items: Array = [
		{"item": small_heal_spawn, "chance": small_health_chance}, 
		{"item": heal_spawn, "chance": big_health_chance}, 
		{"item": small_ammo_spawn, "chance": small_ammo_chance}, 
		{"item": ammo_spawn, "chance": big_ammo_chance}, 
		{"item": life_spawn, "chance": extra_life_chance}, 
	]
	
	var total_chance: float = 0.0
	for entry in items:
		total_chance += entry["chance"]
		
	var roll: float = randf() * total_chance
	var cumulative: float = 0.0
	
	for entry in items:
		cumulative += entry["chance"]
		if roll <= cumulative:
			return entry["item"]
			
	return null

func is_between(_chance: float, _min: float, _max: float) -> bool:
	return _chance > _min and _chance < _max

func start_boss() -> void :
	Event.emit_signal("boss_cutscene_start")

func emit_stage_start_signal() -> void :
	Event.emit_signal("stage_start")

func emit_intro_signal() -> void :
	player.active = true
	player.visible = true
	Event.emit_signal("intro_x")

func start_end_cutscene() -> void :
	change_state("Cutscene")
	Event.emit_signal("end_cutscene_start")

func start_cutscene() -> void :
	change_state("Cutscene")
	Event.emit_signal("cutscene_start")

func end_cutscene() -> void :
	change_state("Normal")
	Event.emit_signal("cutscene_over")

func end_boss_death_cutscene() -> void :
	change_state("StageClear")
	clear_checkpoint()
	Event.emit_signal("stage_clear")

func add_bike(object: Node) -> void :
	bikes.append(object)
	
func debug_action_step() -> void :
	if debug_skip > 0:
		debug_skip += 1
	if debug_skip == 4:
		debug_skip = 1

func get_player_position() -> Vector2:
	if player:
		if player.is_inside_tree():
			last_player_position = player.global_position
	return last_player_position

func get_player_facing_direction() -> int:
	if player:
		return player.get_facing_direction()
	else:
		return 1

func start_debug_action(action: String = "action") -> void :
	if not debug_actions.has(action):
		debug_actions.append(action)

func debug_every_action_in_list() -> void :
	debug_action_step()
	for action in debug_actions:
		debug_action_every_other_frame(action)

func debug_action_every_other_frame(default: String = "action") -> void :
	if debug_skip == 1:
		Input.action_press(default)
	if debug_skip > 2:
		Input.action_release(default)

func save_seen_dialogue(dialog: Resource) -> void :
	if not dialog in seen_dialogues:
		seen_dialogues.append(dialog)

func was_dialogue_seen(dialog: Resource) -> bool:
	return dialog in seen_dialogues

func is_armor(collectible_name: String) -> bool:
	return "hermes" in collectible_name or "icarus" in collectible_name or "ultima" in collectible_name

func is_heart(collectible_name: String) -> bool:
	return "life_up" in collectible_name

func is_subtank(collectible_name: String) -> bool:
	return "tank" in collectible_name

func fill_subtanks() -> void:
	print_debug(":: Filling Subtanks...")
	Event.emit_signal("add_to_subtank",900.0)

var used_cheats := false

func is_cheating() -> bool:
	if OS.has_feature("editor"):
		return false
	return used_cheats

# The unlock is intentionally per boot. It is an entry gate, not progression.
const cheat_code_length := 4
const cheat_unlock_code := "4736"
var cheats_unlocked := false

func try_unlock_cheats(code: String) -> bool:
	if code == cheat_unlock_code:
		cheats_unlocked = true
		return true
	return false

var cheat_god_mode := false
var cheat_infinite_ammo := false
var cheat_infinite_health := false
var cheat_infinite_lives := false
var cheat_fast_max_charge := false
const cheat_invulnerability_source := "cheat_god_mode"

func set_cheat_god_mode(value: bool) -> void:
	cheat_god_mode = value
	used_cheats = used_cheats or value
	apply_cheats_to_player()

func set_cheat_infinite_ammo(value: bool) -> void:
	cheat_infinite_ammo = value
	used_cheats = used_cheats or value
	apply_cheats_to_player()

func set_cheat_infinite_health(value: bool) -> void:
	cheat_infinite_health = value
	used_cheats = used_cheats or value

func set_cheat_infinite_lives(value: bool) -> void:
	cheat_infinite_lives = value
	used_cheats = used_cheats or value

func set_cheat_fast_max_charge(value: bool) -> void:
	cheat_fast_max_charge = value
	used_cheats = used_cheats or value

func apply_cheats_to_player() -> void:
	if not is_player_in_scene():
		return
	if cheat_god_mode:
		player.add_invulnerability(cheat_invulnerability_source)
	else:
		player.remove_invulnerability(cheat_invulnerability_source)
	apply_ammo_cheat()
	call_deferred("apply_cheat_armor")

func object_has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if property.name == property_name:
			return true
	return false

# X and Axl expose compatible ammo flags. Zero's native saber controller does
# not, so it is deliberately left alone instead of being treated like X.
func apply_ammo_cheat() -> void:
	if not is_player_in_scene():
		return
	var weapon_controller = player.get_node_or_null("Shot")
	if not weapon_controller:
		return
	if not object_has_property(weapon_controller, "infinite_regular_ammo") or not object_has_property(weapon_controller, "infinite_charged_ammo"):
		return
	if cheat_infinite_ammo:
		weapon_controller.infinite_regular_ammo = true
		weapon_controller.infinite_charged_ammo = true
		return
	weapon_controller.infinite_regular_ammo = false
	weapon_controller.infinite_charged_ammo = false
	if CharacterManager.player_character == "X":
		var icarus = weapon_controller.get_node_or_null("Icarus Buster")
		var hermes = weapon_controller.get_node_or_null("Hermes Buster")
		weapon_controller.infinite_regular_ammo = hermes != null and hermes.active
		weapon_controller.infinite_charged_ammo = icarus != null and icarus.active

const armor_slots := ["head", "body", "arms", "legs"]
const armor_sets := ["normal", "icarus", "hermes"]
var cheat_armor := {"head": "normal", "body": "normal", "arms": "normal", "legs": "normal"}

func cycle_cheat_armor(slot: String, direction := 1) -> void:
	if CharacterManager.player_character != "X" or not slot in armor_slots:
		return
	var next: int = wrapi(armor_sets.find(cheat_armor[slot]) + direction, 0, armor_sets.size())
	cheat_armor[slot] = armor_sets[next]
	used_cheats = true
	apply_cheat_armor()

func apply_cheat_armor() -> void:
	if not is_player_in_scene() or CharacterManager.player_character != "X":
		return
	for slot in armor_slots:
		var set_name: String = cheat_armor[slot]
		if set_name != "normal":
			player.equip_parts(set_name + "_" + slot)
	player.finished_equipping()

var weapon_got : = "none"
var current_armor : Array
func prepare_weapon_get(weapon_name : String, equipped_armor : Array) -> void:
	print_debug(":: Preparing Weapon get for: " + weapon_name)
	weapon_got = weapon_name
	current_armor = equipped_armor

func finish_weapon_get() -> void:
	weapon_got = "none"
	current_armor = []

func has_beaten_the_game() -> bool:
	return GlobalVariables.get("seraph_lumine_defeated")
