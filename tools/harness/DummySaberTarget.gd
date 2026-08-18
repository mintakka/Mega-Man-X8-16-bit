extends Node2D

# Minimal deterministic enemy receiver for the headless saber-mask regression.
var active := true
var max_health := 100.0
var current_health := max_health
onready var area2D := $area2D

func _ready() -> void:
	add_to_group("Enemies")

func damage(value, _inflicter) -> float:
	current_health -= value
	return current_health
