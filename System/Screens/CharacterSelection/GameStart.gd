extends X8TextureButton

export  var pick_sound: NodePath

var char_name: String = ""


func set_player() -> void :
	CharacterManager.set_player_character(char_name)

func on_press() -> void :
	var choosing_for_mission := GameManager.has_pending_character_select_stage()
	if not choosing_for_mission:
		CharacterManager.started_fresh_game = true
		IGT.reset_rta()
		IGT.should_run_rta = true
	set_player()
	if not choosing_for_mission:
		CharacterManager.only_zero = CharacterManager.player_character == "Zero"
	elif CharacterManager.only_zero and CharacterManager.player_character != "Zero":
		CharacterManager.only_zero = false
	CharacterManager._save()
	Savefile.save(Savefile.save_slot)
	get_node(pick_sound).play()
	Event.emit_signal("fadeout_startmenu")
	strong_flash()
	menu.lock_buttons()
	menu.fader.duration = 0.0625
	menu.fader.SoftFadeOut()
	yield(menu.fader, "finished")
	GameManager.seen_dialogues.clear()
	go_to_next_scene()

# "NoahsPark" is the one-off intro stage, not the replayable one. Every other
# start button checks already_finished_noahs_park() before using it - this one
# defined the helper but never called it, so any route into the picker without
# a queued mission replayed the intro no matter how much of the campaign was
# already done. That also hid Zero's K-Knuckle: it only exists in the
# replayable NoahsPark2 stage, which is reachable from stage select.
func go_to_next_scene() -> void :
	if GameManager.has_pending_character_select_stage():
		GameManager.start_pending_character_select_stage()
	elif already_finished_noahs_park():
		GameManager.call_deferred("go_to_stage_select")
	else:
		GameManager.start_level("NoahsPark")

func already_finished_noahs_park() -> bool:
	return "finished_intro" in GameManager.collectibles
