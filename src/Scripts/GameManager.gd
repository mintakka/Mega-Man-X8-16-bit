extends Node

const codename := "X8FC"
const version := "1.0.0.9"
const current_demo := "16-bit"

var player : Character
var camera : Camera2D
var state := "Normal"
var bikes = []
var debug_actions = []
var debug_skip := 1
var collectibles := []
var equip_exceptions := []
var equip_hearts := true
var equip_subtanks := true
var seen_dialogues = []
var current_level : String
const heal_spawn = preload("res://src/Objects/Heal.tscn")
const small_heal_spawn = preload("res://src/Objects/SmallHeal.tscn")
const ammo_spawn = preload("res://src/Objects/Pickups/Ammo.tscn")
const small_ammo_spawn = preload("res://src/Objects/Pickups/SmallAmmo.tscn")
const life_spawn = preload("res://src/Objects/Pickups/ExtraLife.tscn")
var last_time_debug_reset := 0.0
var end_stage_timer := 0.0
var stage_start_msec := 0.0
#Checkpoint
var checkpoint : CheckpointSettings

var checkpoint_cam_width := Vector2.ZERO
var checkpoint_cam_height := Vector2.ZERO

#Life System
const player_life_count := "player_lives"

var current_stage_info : StageInfo

#Which character the player picked on the select screen, and the one actually in
#play for the current stage. They differ whenever a stage forces a character -
#Noah's Park is always X - and keeping the pick separate means being forced into
#X for the intro does not overwrite what the player chose for later missions.
#Set when checkpoint positioning was asked for while no player existed yet.
#A swapped-in character joins the tree a frame after the level does, so the
#deferred positioning can arrive first and silently skip, which would drop Zero
#at the stage entrance instead of the checkpoint he died at.
var pending_checkpoint_positioning := false

var picked_character := CharacterRoster.DEFAULT
var active_character := CharacterRoster.DEFAULT

var time_attack:= false
var ta_status := "Recording..."

var ghost_file = "user://score.save"

var maximum_distance := Vector2(480,320)
var maximum_bike_distance := Vector2(199,100)
var debug_go_to_next_stage := false
var best_recording := []

var music_player : MusicPlayer
var music_volume := -6.0
var dialog_box

var player_died := false
var pause_sources: Array

var debug_enabled := false
var last_player_position := Vector2.ZERO

var lumine_boss_order : Array

func _ready() -> void:
	print ("GameManager: Initializing...")
	set_pause_mode(2)
	fix_unmapped_joypads()
	Input.connect("joy_connection_changed",self,"on_joy_connection_changed") # warning-ignore:return_value_discarded
	BossRNG.initialize()
	Savefile.load_save()
	apply_aspect_ratio()
	on_level_start()

#Render resolution. The game is authored for a 398x224 (16:9) canvas. The 16:10
#option keeps the width and adds vertical view (398x249) instead of cropping the
#sides, so nothing on screen shrinks - you simply see more above and below.
#StateCamera clamps against this height, and it already centres the view in
#camera zones shorter than the screen, so tight vertical rooms stay in bounds.
const view_width := 398
const view_height_16_9 := 224
const view_height_16_10 := 249
const aspect_config_key := "Widescreen"
var view_height : int = view_height_16_9

func get_native_size() -> Vector2:
	return Vector2(view_width, view_height)

func is_widescreen() -> bool:
	return Configurations.get(aspect_config_key) == true

func get_aspect_name() -> String:
	return "16:10" if is_widescreen() else "16:9"

func configured_view_height() -> int:
	return view_height_16_10 if is_widescreen() else view_height_16_9

#Only gameplay gets the taller canvas. Every menu screen (title, stage select,
#armor setup, key config, weapon get...) pins its contents with fixed margins
#inside a 398x224 layout and is full of hardcoded 224 offsets, so at 249 they
#stay pinned to the top and leave a strip of clear colour at the bottom.
#Rendering menus at their authored height letterboxes them cleanly instead.
func target_view_height() -> int:
	if is_widescreen() and is_in_gameplay_scene():
		return view_height_16_10
	return view_height_16_9

#Keyed off the scene rather than the player, so the canvas does not flip back
#and forth while the player is being freed and respawned on death.
func is_in_gameplay_scene() -> bool:
	var scene = get_tree().current_scene
	if not scene:
		return false
	return scene.filename.begins_with("res://src/Levels/")

func apply_aspect_ratio() -> void:
	set_canvas_height(target_view_height())
	update_window_size()

func set_canvas_height(new_height : int) -> void:
	if view_height == new_height:
		return
	view_height = new_height
	get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_2D, SceneTree.STRETCH_ASPECT_KEEP, get_native_size())
	Event.emit_signal("aspect_ratio_changed")
	print("GameManager: canvas set to " + str(get_native_size()) + " (" + get_aspect_name() + " selected)")

#The window keeps the configured aspect at all times, so entering and leaving a
#stage never resizes it - menus simply letterbox inside it.
func get_window_native_size() -> Vector2:
	return Vector2(view_width, configured_view_height())

func update_window_size() -> void:
	if Configurations.get("Fullscreen"):
		return
	var multiplier = Configurations.get("WindowSize")
	if not multiplier:
		multiplier = 3
	OS.set_window_size(get_window_native_size() * multiplier)

#Godot 3.5's bundled controller database has no entry for the Handheld Daemon /
#Legion Go emulated pad (045e:028f), so it falls back to raw evdev button order,
#where Select/Start report as 6/7 instead of JOY_SELECT(10)/JOY_START(11).
#That leaves Start and Select dead in game. Register the standard xpad mapping
#for that device only, so every other controller is left untouched.
const unmapped_joypad_guids := ["5e0400008f02"]
const xpad_mapping_body := ",a:b0,b:b1,back:b6,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b8,leftshoulder:b4,leftstick:b9,lefttrigger:a2,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b10,righttrigger:a5,rightx:a3,righty:a4,start:b7,x:b2,y:b3,platform:Linux,"

func on_joy_connection_changed(device : int, connected : bool) -> void:
	if connected:
		fix_unmapped_joypad(device)

func fix_unmapped_joypads() -> void:
	for device in Input.get_connected_joypads():
		fix_unmapped_joypad(device)

func fix_unmapped_joypad(device : int) -> void:
	var guid : String = Input.get_joy_guid(device)
	for fragment in unmapped_joypad_guids:
		if fragment in guid:
			var joy_name : String = Input.get_joy_name(device).replace(",","")
			Input.add_joy_mapping(guid + "," + joy_name + xpad_mapping_body, true)
			print("GameManager: registered missing controller mapping for " + joy_name + " (" + guid + ")")
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

func start_stage_music() -> void:
	if is_instance_valid(music_player):
		music_player.call_deferred("play_stage_song")

func start_level(StageName : String) -> void:
	
	clear_checkpoint()
	set_player_lives_to_at_least_2()
	current_level = StageName
	#Resolved once here, at the point the stage is known, so every later reload,
	#checkpoint respawn and death retry inside the stage reuses the same answer.
	active_character = CharacterRoster.resolve_for_stage(StageName, picked_character)
	var path : String
	if StageName == "NoahsPark":
		path = "res://src/Levels/NoahsPark/Intro_NoahsPark.tscn"
	else:
		path = "res://src/Levels/" + StageName + "/Stage_" + StageName + ".tscn"
	var _dv = get_tree().change_scene(path)
	call_deferred("restart_level")

func set_player_lives_to_at_least_2() -> void:
	if not GlobalVariables.exists(player_life_count) or GlobalVariables.get(player_life_count) < 2:
		GlobalVariables.set(player_life_count, 2)

func go_to_intro() -> void:
	print_debug(":::::::: going to intro")
	var _dv = get_tree().change_scene("res://src/Title/IntroCapcom.tscn")

func go_to_disclaimer() -> void:
	print_debug(":::::::: going to disclaimer")
	var _dv = get_tree().change_scene("res://src/Title/DisclaimerScreen.tscn")

func go_to_igt() -> void:
	print_debug(":::::::: going to igt screen")
	var _dv = get_tree().change_scene("res://src/Screens/IGTScreen.tscn")
	GameManager.call_deferred("restart_level")

func go_to_lumine_boss_test() -> void:
	print_debug(":::::::: going to seraph lumine boss test")
	var _dv = get_tree().change_scene("res://src/Levels/SigmaPalace/SeraphTest.tscn")
	GameManager.checkpoint = null
	GameManager.call_deferred("restart_level")
	

func end_level():
	Event.emit_signal("fade_out")
	end_stage_timer = 0.01
	GameManager.pause("EndLevel")
	debug_go_to_next_stage = true
	Savefile.save()

var won_against_final_boss := false

func end_game():
	Event.emit_signal("final_fade_out")
	end_stage_timer = 0.01
	GameManager.pause("EndGame")
	debug_go_to_next_stage = true
	won_against_final_boss = true
	Savefile.save()

func on_death():
	Event.emit_signal("fade_out")
	end_stage_timer = 0.01
	GameManager.pause("Death")
	BossRNG.player_died()
	Savefile.save()
	player_died = true

func finished_fade_out() -> void:
	if player_died:
		player_died = false
		#prevents going to stageselect on intro
		if current_level == "NoahsPark": 
			call_deferred("restart_level")
			#go_to_intro()

		#check if still has lives and reduce
		elif GlobalVariables.get(player_life_count) > 0 or cheat_infinite_lives:
			handle_player_death() #reduce life count
			call_deferred("restart_level")

		#game over
		else:
			Event.emit_signal("game_over")
			call_deferred("go_to_stage_select")

	#other cases such as victory
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
	pass
	
func go_to_credits():
	print_debug(":::::::: going to final cutscene")
	var _dv = get_tree().change_scene("res://src/Levels/SigmaPalace/CreditsScene.tscn")
	call_deferred("force_unpause")
	call_deferred("on_level_start")
	pass

func handle_player_death() -> void:
	if cheat_infinite_lives:
		print_debug("Player died, infinite lives cheat active, not reducing lives")
		return
	var lives = GlobalVariables.get(player_life_count)
	print_debug("Player died, current lives: " + str(lives) + " being reduced by 1")
	GlobalVariables.set(player_life_count, lives -1)

func go_to_stage_select() -> void: 
	print_debug(":::::::: going to stage select")
	var _dv = get_tree().change_scene("res://src/StageSelect/StageSelectScreen.tscn")

func go_to_weapon_get() -> void:
	print_debug(":::::::: going to weapon get")
	var _dv = get_tree().change_scene("res://src/WeaponGet/WeaponGetScene.tscn")
	call_deferred("force_unpause")
	call_deferred("on_level_start")

#The stage select hands off here instead of straight into the stage, so the
#player picks a character first. The stage is remembered rather than passed
#through the select screen, which keeps that screen from needing to know
#anything about stage routing.
func go_to_character_select(stage : StageInfo) -> void:
	print_debug(":::::::: going to character select")
	current_stage_info = stage
	var _dv = get_tree().change_scene("res://src/CharacterSelect/CharacterSelectScreen.tscn")

#Resumes exactly what the stage select would have done had the character select
#not been in the way.
func continue_after_character_select() -> void:
	var stage := current_stage_info
	if stage == null:
		go_to_stage_select()
		return
	if stage.should_play_stage_intro():
		go_to_stage_intro(stage)
	else:
		start_level(stage.get_load_name())

func go_to_stage_intro(stage : StageInfo) -> void:
	print_debug(":::::::: going to stage and boss intro")
	current_stage_info = stage
	var _dv = get_tree().change_scene("res://src/BossIntro/BossIntro.tscn")

func restart_level():
	print_debug("::::::::  Restarting level")
	get_tree().reload_current_scene()# warning-ignore:return_value_discarded
	GameManager.force_unpause()
	on_level_start()

func reached_checkpoint(new_checkpoint):
	if GameManager.time_attack:
		return

	if not checkpoint or new_checkpoint.id > checkpoint.id:
		set_checkpoint(new_checkpoint)
	else:
		print_debug("GameManager: Checkpoint not set: " + str(checkpoint.id))

func set_checkpoint(new_checkpoint):
	checkpoint = new_checkpoint
	Event.emit_signal("reached_checkpoint",new_checkpoint)
	print_debug("GameManager: New checkpoint: " + str(checkpoint.id))

func clear_checkpoint() -> void:
	checkpoint = null

func position_player_on_checkpoint() -> void:
	if not player:
		pending_checkpoint_positioning = true
		return
	if GameManager.time_attack:
		return
	if checkpoint:
		player.global_position = checkpoint.respawn_position
		player.set_direction(checkpoint.character_direction)
		var last_checkpoint_door = get_node_or_null(checkpoint.last_door)
		if last_checkpoint_door and last_checkpoint_door.has_method("reached_checkpoint"):
			last_checkpoint_door.reached_checkpoint()
		print("GameManager: moved player to checkpoint " + str(checkpoint.id))		
		Event.emit_signal("moved_player_to_checkpoint",checkpoint)

func set_player(object):
	print_debug("Setting player: " + object.name)
	player = object
	#Only retried when it was genuinely skipped, so a character that registered
	#in time is never repositioned twice - that would re-fire the checkpoint door.
	if pending_checkpoint_positioning:
		pending_checkpoint_positioning = false
		call_deferred("position_player_on_checkpoint")
	player.active = false
	player.visible = false
	player.deactivate()
	apply_cheats_to_player()

func add_collectibles_to_player():
	if player:
		for collectible in collectibles:
			if not has_equip_exception(collectible): 
				player.equip_parts(collectible)
		player.finished_equipping()

func has_equip_exception(collectible : String) -> bool:
	if is_armor(collectible):
		for exception in equip_exceptions:
			if exception in collectible:
				return true
				
	elif is_heart(collectible):
		if not equip_hearts:
			return true
		
	elif is_subtank(collectible):
		if not equip_subtanks:
			print("SSSSSSSSSSSSSSSSSSSSSS Subtank exceptin" + collectible)
			return true
		
	return false

func add_equip_exception(armor_part : String) -> void:
	if not armor_part in equip_exceptions:
		equip_exceptions.append(armor_part)
	else:
		equip_exceptions.erase(armor_part)
		equip_exceptions.append(armor_part)

func remove_equip_exception(armor_part : String) -> void:
	equip_exceptions.erase(armor_part)

func add_collectible_to_savedata(collectible : String):
	if not is_collectible_in_savedata(collectible):
		collectibles.append(collectible)
	else:
		reposition_collectible_in_savedata(collectible)

func remove_collectible_from_savedata(collectible : String):
	if is_collectible_in_savedata(collectible):
		collectibles.erase(collectible)

func is_collectible_in_savedata(collectible : String) -> bool:
	return collectible in collectibles

func reposition_collectible_in_savedata(collectible : String) -> void:
	collectibles.erase(collectible)
	collectibles.append(collectible)

func _physics_process(delta: float) -> void:
	handle_end_of_level(delta)
	if Input.is_action_just_pressed("fullscreen"):
		OS.window_fullscreen = !OS.window_fullscreen
		Configurations.set("Fullscreen",OS.window_fullscreen)
		Savefile.save()
	if cheat_infinite_health and player and is_instance_valid(player) and player.has_health():
		player.current_health = player.max_health
	#Follow scene changes: taller canvas in stages, authored canvas in menus.
	set_canvas_height(target_view_height())


func handle_end_of_level(delta: float) -> void:
	if end_stage_timer > 0:
		end_stage_timer += delta
		if end_stage_timer > 1:
			GameManager.force_unpause()
			#call_deferred("restart_level")

var primrose_paused := false

func primrose_pause():
	pause("Primrose")

func primrose_unpause():
	unpause("Primrose")
	
func pause(source : String):
	if not source in pause_sources:
		pause_sources.append(source)
		print("paused by " + source)
	update_pause_state()

func unpause(source : String):
	pause_sources.erase(source)
	print("removed pause of " + source)
	update_pause_state()

func force_unpause():
	pause_sources.clear()
	update_pause_state()

func update_pause_state():
	if pause_sources.size() > 0:
		get_tree().paused = true
		Event.emit_signal("pause")
	else:
		get_tree().paused = false
		Event.emit_signal("unpause")

func is_on_screen(target_global_position) -> bool:
	return abs(camera.get_camera_screen_center().x - target_global_position.x) < 230 and abs(camera.get_camera_screen_center().y - target_global_position.y) < 150

func precise_is_on_screen(target_global_position) -> bool:
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

func get_next_spawn_item(drop_item_chance = 25,
						 small_health_chance = 30, 
						 big_health_chance = 15,
						 small_ammo_chance = 15,
						 big_ammo_chance = 10,
						 extra_life_chance = 0.1):

	var chance = randf() * 100
	if not is_between(chance, 0, drop_item_chance):
		return null
	
	var shc = small_health_chance
	var bhc = shc + big_health_chance
	var sac = bhc + small_ammo_chance
	var bac = sac + big_ammo_chance
	var elc = bac + extra_life_chance
	var c = randf() * elc
	
	if is_between(c,0,shc):
		return small_heal_spawn
	elif is_between(c,shc,bhc):
		return heal_spawn
	elif is_between(c,bhc,sac):
		return small_ammo_spawn #return small weapon recharge
	elif is_between(c,sac,bac):
		return ammo_spawn #return big weapon recharge
	elif is_between(c,bac,elc):
		return life_spawn #return extra life

func is_between(c, _min, _max) -> bool:
	return c > _min and c < _max

func start_boss():
	Event.emit_signal("boss_cutscene_start")
	
func emit_stage_start_signal():
	Event.emit_signal("stage_start")
	
func emit_intro_signal():
	player.active = true
	player.visible = true
	Event.emit_signal("intro_x")

func start_end_cutscene() -> void:
	change_state("Cutscene")
	Event.emit_signal("end_cutscene_start")
	
func start_cutscene()-> void:
	change_state("Cutscene")
	Event.emit_signal("cutscene_start")

func end_cutscene()-> void:
	change_state("Normal")
	Event.emit_signal("cutscene_over")
	
func end_boss_death_cutscene()-> void:
	change_state("StageClear")
	clear_checkpoint()
	Event.emit_signal("stage_clear")

func add_bike(object : Node) -> void:
	bikes.append(object)
	
func debug_action_step():
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

func start_debug_action(action := "action"):
	if not debug_actions.has(action):
		debug_actions.append(action)

func debug_every_action_in_list():
	debug_action_step()
	for action in debug_actions:
		debug_action_every_other_frame(action)

func debug_action_every_other_frame(default := "action"):
	if debug_skip == 1:
		Input.action_press(default)
	if debug_skip > 2:
		Input.action_release(default)

func save_seen_dialogue(dialog) -> void:
	if not dialog in seen_dialogues:
		seen_dialogues.append(dialog)

func was_dialogue_seen(dialog) -> bool:
	return dialog in seen_dialogues

func is_armor(collectible_name : String) -> bool:
	return "hermes" in collectible_name or "icarus" in collectible_name

func is_heart(collectible_name : String) -> bool:
	return "life_up" in collectible_name

func is_subtank(collectible_name : String) -> bool:
	return "tank" in collectible_name

func fill_subtanks() -> void:
	print_debug(":: Filling Subtanks...")
	Event.emit_signal("add_to_subtank",900.0)

var used_cheats := false

func is_cheating() -> bool:
	if OS.has_feature("editor"):
		return false
	return used_cheats

#Player Cheats
var cheat_god_mode := false
var cheat_infinite_ammo := false
var cheat_infinite_health := false
var cheat_infinite_lives := false
const cheat_invulnerability_source := "cheat_god_mode"

func set_cheat_god_mode(value : bool) -> void:
	cheat_god_mode = value
	if value:
		used_cheats = true
	apply_cheats_to_player()

func set_cheat_infinite_ammo(value : bool) -> void:
	cheat_infinite_ammo = value
	if value:
		used_cheats = true
	apply_cheats_to_player()

func set_cheat_infinite_health(value : bool) -> void:
	cheat_infinite_health = value
	if value:
		used_cheats = true

func set_cheat_infinite_lives(value : bool) -> void:
	cheat_infinite_lives = value
	if value:
		used_cheats = true

func apply_cheats_to_player() -> void:
	if not player or not is_instance_valid(player):
		return
	if cheat_god_mode:
		player.add_invulnerability(cheat_invulnerability_source)
	else:
		player.remove_invulnerability(cheat_invulnerability_source)
	apply_ammo_cheat()
	call_deferred("apply_cheat_armor")

#Turning the ammo cheat off must not clobber what the equipped arms already
#grant: Icarus arms give infinite charged shots, Hermes arms infinite regular
#ones. Restore from whichever buster is active instead of blanking both.
func apply_ammo_cheat() -> void:
	var buster = player.get_node_or_null("Shot")
	if not buster:
		return
	if cheat_infinite_ammo:
		buster.infinite_regular_ammo = true
		buster.infinite_charged_ammo = true
		return
	var icarus = buster.get_node_or_null("Icarus Buster")
	var hermes = buster.get_node_or_null("Hermes Buster")
	buster.infinite_regular_ammo = hermes != null and hermes.active
	buster.infinite_charged_ammo = icarus != null and icarus.active

#Armor cheat: pick a set per slot. Parts are equipped by calling equip_parts()
#directly rather than emitting "collected", because that signal also runs
#Player.collect() -> add_collectible_to_savedata(), which would write the parts
#into the save file. This keeps the whole cheat session-only.
#Note the game has no un-equip path (there are no equip_no_*_parts functions),
#so clearing a slot back to "normal" only takes effect on the next level load.
const armor_slots := ["head", "body", "arms", "legs"]
const armor_sets := ["normal", "icarus", "hermes"]
var cheat_armor := {"head": "normal", "body": "normal", "arms": "normal", "legs": "normal"}

func cycle_cheat_armor(slot : String, direction := 1) -> void:
	var next : int = wrapi(armor_sets.find(cheat_armor[slot]) + direction, 0, armor_sets.size())
	cheat_armor[slot] = armor_sets[next]
	used_cheats = true
	apply_cheat_armor()

func apply_cheat_armor() -> void:
	if not is_player_in_scene():
		return
	for slot in armor_slots:
		var set_name : String = cheat_armor[slot]
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
