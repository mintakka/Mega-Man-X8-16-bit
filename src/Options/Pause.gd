extends CanvasLayer
onready var fader: ColorRect = $CoverScreen
onready var bg: TextureRect = $bg
onready var pause: TextureRect = $pause
onready var choice: AudioStreamPlayer = $choice
onready var key_config: CanvasLayer = $KeyConfig
onready var options_menu: CanvasLayer = $OptionsMenu
onready var achievements: CanvasLayer = $AchievementsScreen

var paused := false
var subtanks : Array
var using_subtank := false
var endgame := false
signal pause_starting
signal pause_started  
signal pause_ending
signal pause_ended
signal lock_buttons
signal unlock_buttons

func _ready() -> void:
	if not is_debugging():
		pause.visible = false
		bg.visible = false
		visible = true
	else:
		Pause()
	subtanks = get_subtank_controls()
	connect_subtank_signals()
	key_config.connect("end",self,"unlock_buttons") # warning-ignore:return_value_discarded
	options_menu.connect("end",self,"unlock_buttons") # warning-ignore:return_value_discarded
	achievements.connect("end",self,"unlock_buttons") # warning-ignore:return_value_discarded
	Event.connect("lumine_desperation",self,"on_lumine_desperation")
	Event.connect("aspect_ratio_changed",self,"update_aspect_offset") # warning-ignore:return_value_discarded
	update_aspect_offset()

#This menu is authored for the 398x224 canvas but overlays gameplay, which uses
#the taller canvas at 16:10. Shift the whole layer so it stays centred instead
#of sitting against the top edge.
func update_aspect_offset() -> void:
	offset.y = (GameManager.view_height - GameManager.view_height_16_9) / 2.0
	
func on_lumine_desperation():
	endgame = true

func lock_buttons() -> void:
	emit_signal("lock_buttons")
	
func unlock_buttons() -> void:
	emit_signal("unlock_buttons")

func connect_subtank_signals() -> void:
	for s in subtanks:
		var _d = s.connect("using",self,"on_subtank_use")
		_d =     s.connect("finished",self,"on_subtank_finish")

func on_subtank_use() -> void:
	using_subtank = true
	lock_buttons()

func on_subtank_finish() -> void:
	using_subtank = false
	unlock_buttons()

func _input(event: InputEvent) -> void:
	call_deferred("pause_input",event)

func pause_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if using_subtank:
			return
		if not key_config.active and not options_menu.active and not achievements.active:
			if can_pause():
				if not paused:
					Pause()
				elif paused:
					Unpause()
	

func start_keyconfig() -> void:
	print_debug("starting KeyConfig")
	lock_buttons()
	key_config.start()
	
func start_options() -> void:
	print_debug("starting Options")
	lock_buttons()
	options_menu.start()

func start_achievements() -> void:
	print_debug("starting Achievements")
	lock_buttons()
	achievements.start()
	
func button_call(method) -> void:
	print_debug("Button press: Executing method " + method)
	call(method)

func Pause() -> void:
	paused = true
	emit_signal("pause_starting")
	set_usable_subtanks()
	fader.FadeIn()
	GameManager.half_music_volume()
	Event.emit_signal("pause_menu_opened")
	GameManager.pause("PauseMenu")
	yield(fader,"finished")
	emit_signal("unlock_buttons")
	call_deferred("emit_signal","pause_started")

func Unpause() -> void:
	emit_signal("pause_ending")
	emit_signal("lock_buttons")
	fader.FadeOut()
	paused = false
	GameManager.normal_music_volume()
	Savefile.save()
	yield(fader,"finished")
	Event.emit_signal("pause_menu_closed")
	GameManager.unpause("PauseMenu")
	emit_signal("pause_ended")

func play_choice_sound() -> void:
	choice.play()

func is_debugging() -> bool:
	return get_parent().name != "Hud"

func can_pause() -> bool:
	if is_debugging():
		return true
	if not GameManager.player:
		return false
	return GameManager.player.has_control() and not fader.transitioning and not endgame

func set_usable_subtanks() -> void:
	for each in subtanks:
		each.visible = false
		if GameManager.equip_subtanks:
			each.visible = true
		if not each.subtank.id in GameManager.collectibles:
			each.visible = false

func get_subtank_controls() -> Array:
	var a = []
	a.append($"pause/Subtank Group/gridContainer/Subtank")
	a.append($"pause/Subtank Group/gridContainer/Subtank2")
	a.append($"pause/Subtank Group/gridContainer/Subtank3")
	a.append($"pause/Subtank Group/gridContainer/Subtank4")
	return a
