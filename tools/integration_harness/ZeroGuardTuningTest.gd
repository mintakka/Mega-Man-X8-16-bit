extends Node

var failures := []
var guard_broken := false

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	CharacterManager.player_character = "Zero"
	var player = CharacterManager.get_player_character_object().instance()
	add_child(player)
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")

	check(player.get_node("Damage").prevent_knockbacks,
		"Zero lost his innate knockback resistance")
	player.get_node("Shot").activate_saber_moves()
	var sprite: AnimatedSprite = player.get_node("animatedSprite")
	var combo = player.get_node("SaberCombo")
	sprite.animation = "saber_1"
	sprite.frame = 2
	combo.hitbox_and_position()
	var ground_hitbox = combo.current_hitbox
	check(is_instance_valid(ground_hitbox), "Zero's first saber swing did not spawn a hitbox")
	if is_instance_valid(ground_hitbox):
		ground_hitbox.timer = 1.0
		check(ground_hitbox.break_guards,
			"Zero's first standard saber swing cannot stagger guarded enemies")
	sprite.animation = "saber_2"
	sprite.frame = 2
	combo.hitbox_and_position()
	check(is_instance_valid(combo.current_hitbox) and combo.current_hitbox.break_guards,
		"Zero's second standard saber swing cannot stagger guarded enemies")

	var jump = player.get_node("SaberJump")
	sprite.animation = "saber_jump"
	sprite.frame = 3
	jump.hitbox_and_position()
	check(is_instance_valid(jump.current_hitbox) and jump.current_hitbox.break_guards,
		"Zero's jumping standard saber cannot stagger guarded enemies")

	var wall = player.get_node("SaberWall")
	sprite.animation = "saber_slide"
	sprite.frame = 2
	wall.hitbox_and_position()
	check(is_instance_valid(wall.current_hitbox) and wall.current_hitbox.break_guards,
		"Zero's wall standard saber cannot stagger guarded enemies")

	var metool = preload("res://src/Actors/Enemies/Metool/Metool.tscn").instance()
	add_child(metool)
	metool.get_node("Damage").only_on_screen = false
	metool.connect("guard_break", self, "_on_guard_break")
	var shield = metool.get_node("EnemyShield")
	shield.activate()
	var starting_health = metool.current_health
	if is_instance_valid(ground_hitbox):
		shield.deflect_projectile(ground_hitbox)
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	check(guard_broken, "A hidden Metool did not receive Zero's guard-break signal")
	check(metool.get_node("EnemyStun").executing,
		"A hidden Metool did not enter its native stagger state")
	check(not shield.active, "The Metool shield stayed active after Zero's saber stagger")
	check(metool.current_health == starting_health,
		"The guarded saber strike bypassed the helmet instead of opening it")

	if is_instance_valid(ground_hitbox):
		ground_hitbox.hit(metool.get_node("Damage"))
	check(metool.current_health <= 0.0,
		"Zero's follow-up standard saber did not defeat the exposed low-tier Metool")
	finish()

func _on_guard_break() -> void:
	guard_broken = true

func finish() -> void:
	if failures.empty():
		print("PASS ZeroGuardTuningTest")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
