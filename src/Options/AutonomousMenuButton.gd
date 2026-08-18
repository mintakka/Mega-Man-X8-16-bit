extends X8TextureButton

export var pick_sound : NodePath
export var able_to_unlock_debug := false
onready var sub_menu = get_child(0)

func _ready() -> void:
	# Virtual callbacks run through the inheritance chain in Godot 3. Calling
	# the base _ready again duplicated its menu signals. Resolve defensively for
	# inherited scenes, and also guarantee the pressed connection in code so a
	# missing .tscn connection cannot silently make a submenu button inert.
	if menu == null and menu_path:
		menu = get_node(menu_path)
	connect_lock_signals(menu)
	if not is_connected("pressed", self, "_on_pressed"):
		connect("pressed", self, "_on_pressed")
	if not sub_menu.is_connected("end", self, "_on_submenu_end"):
		sub_menu.connect("end", self,"_on_submenu_end")

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
	
