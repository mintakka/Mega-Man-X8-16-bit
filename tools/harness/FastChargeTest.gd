extends Node

# FAST CHARGE turns a tap into the ordinary fully charged shot. With upgraded
# arms, holding that same press must continue charging to the tier-3 mega shot.

var frames := 0
var player
var projectiles := []

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	get_tree().connect("node_added", self, "_on_node_added")
	GameManager.active_character = CharacterRoster.X
	GameManager.cheat_fast_max_charge = true
	player = preload("res://src/Actors/Player.tscn").instance()
	add_child(player)
	player.active = true
	player.visible = true
	player.listening_to_inputs = true
	player.reactivate_charge()
	player.add_invulnerability("fast_charge_harness")
	player.equip_icarus_arms_parts()

func _physics_process(_delta : float) -> void:
	frames += 1
	if frames == 60: Input.action_press("fire")
	if frames == 61: Input.action_release("fire")
	if frames == 90:
		print("FAST CHARGE tap projectiles=%s charge_running=%s" % [
			projectiles, player.get_node("Charge").executing])
		assert("Charged Buster" in projectiles)
		assert(not "Icarus Lemon" in projectiles)
		assert(not "Medium Buster" in projectiles)
		assert(not "Laser Buster" in projectiles)
		assert(not player.get_node("Charge").executing)
		projectiles.clear()
	if frames == 105: Input.action_press("fire")
	if frames == 180: Input.action_release("fire")
	if frames == 205:
		print("FAST CHARGE hold projectiles=%s" % [projectiles])
		assert("Charged Buster" in projectiles)
		assert("Laser Buster" in projectiles)
		assert(not player.get_node("Charge").executing)
		projectiles.clear()
		GameManager.cheat_fast_max_charge = false
		player.equip_hermes_arms_parts()
	if frames == 220: Input.action_press("fire")
	if frames == 221: Input.action_release("fire")
	if frames == 250:
		print("FAST CHARGE disabled projectiles=%s" % [projectiles])
		assert("Lemon" in projectiles)
		assert(not "Charged Buster" in projectiles)
		print("FAST CHARGE PASS")
		get_tree().quit()

func _on_node_added(node : Node) -> void:
	if node.filename.begins_with("res://src/Actors/Weapons/Projectiles/"):
		var projectile_name := node.filename.get_file().get_basename()
		if projectile_name in ["Lemon", "Icarus Lemon", "Medium Buster", "Charged Buster", "Triad Charged Buster", "Laser Buster"]:
			projectiles.append(projectile_name)
