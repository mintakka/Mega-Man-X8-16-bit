extends X8TextureButton

export var pick_sound : NodePath
export var able_to_unlock_debug := false
onready var sub_menu = get_child(0)

func _ready() -> void:
	#X8TextureButton._ready resolves menu_path and hooks the lock/unlock signals.
	#Without chaining to it `menu` stays null, so on_press died on
	#menu.lock_buttons() and never reached sub_menu.start() - the button looked
	#like it did nothing at all.
	._ready()
	var _s = sub_menu.connect("end", self,"_on_submenu_end")

func on_press() -> void:
	if able_to_unlock_debug:
		if Input.is_action_pressed("select_special"):
			GameManager.debug_enabled = true
		else:
			GameManager.debug_enabled = false
	
	get_node(pick_sound).play()
	menu.lock_buttons()
	strong_flash()
	sub_menu.start()

func _on_submenu_end() -> void:
	menu.unlock_buttons()
	grab_focus()
	
