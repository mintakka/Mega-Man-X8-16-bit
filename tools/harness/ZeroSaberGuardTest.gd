extends Node

# Zero's saber must break a hidden Metool's guard like a charged buster, then
# kill the exposed low-tier enemy with its tuned five-damage light slash.

var frames := 0
var player
var saber
var metool
var guard_broken := false

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	GameManager.active_character = CharacterRoster.ZERO
	player = preload("res://src/Actors/Player.tscn").instance()
	add_child(player)
	player.active = true
	player.visible = true
	player.listening_to_inputs = true
	saber = player.get_node("Saber")
	metool = preload("res://src/Actors/Enemies/Metool/Metool.tscn").instance()
	add_child(metool)
	metool.get_node("Damage").only_on_screen = false
	metool.get_node("EnemyShield").activate()
	metool.connect("guard_break", self, "_on_guard_break")

func _physics_process(_delta : float) -> void:
	frames += 1
	if frames == 10:
		saber.apply_saber_hit(metool.get_node("Damage"), {"damage": 2})
	if frames == 14:
		print("SABER guard_broken=%s stunned=%s shield=%s health=%s" % [
			guard_broken, metool.get_node("EnemyStun").executing,
			metool.get_node("EnemyShield").active, metool.current_health])
		assert(guard_broken)
		assert(metool.get_node("EnemyStun").executing)
		assert(not metool.get_node("EnemyShield").active)
		assert(metool.current_health == metool.max_health)
	if frames == 20:
		saber.apply_saber_hit(metool.get_node("Damage"), {"damage": 2})
		print("SABER exposed health=%s damage=%s" % [
			metool.current_health, saber.saber_damage({"damage": 2})])
		assert(saber.saber_damage({"damage": 2}) == 5.0)
		assert(metool.current_health <= 0.0)
		assert(not player.get_node("Charge").active)
		print("ZERO SABER GUARD PASS")
		get_tree().quit()

func _on_guard_break() -> void:
	guard_broken = true
