extends X8OptionButton

#Switches the render resolution between the authored 16:9 canvas (398x224) and
#a taller 16:10 one (398x249). The extra space is added vertically, so sprites
#keep their size and the player simply sees more above and below.

func _ready() -> void:
	Event.connect("translation_updated",self,"display") # warning-ignore:return_value_discarded

func setup() -> void:
	GameManager.apply_aspect_ratio()
	display()

func increase_value() -> void: #override
	toggle()

func decrease_value() -> void: #override
	toggle()

func toggle() -> void:
	Configurations.set(GameManager.aspect_config_key, not GameManager.is_widescreen())
	GameManager.apply_aspect_ratio()
	display()

func display() -> void:
	display_value(GameManager.get_aspect_name())
