extends Node

# Driver lives under root: the failing path calls change_scene(), which would
# free a test node that is itself the current scene.
func _ready() -> void:
	var d = Node.new()
	d.set_script(load("res://tools/integration_harness/PickerCancelRaceDriver.gd"))
	get_tree().root.call_deferred("add_child", d)
