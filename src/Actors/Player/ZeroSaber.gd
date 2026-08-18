extends Movement
class_name ZeroSaber

# Zero's Z-Saber. One ability covers every slash rather than a node per attack,
# because they all share the same shape - pick an attack from the current
# context, play its animation, open a damage window partway through - and the
# ground combo needs to hand off between them mid-animation, which is far
# simpler to do inside one state than across three conflicting abilities.
#
# The numbers are lifted from MMX-Next's player_saber_init: damage, and the
# [start, end, interval] hit windows. Those windows are measured in 60fps game
# steps (GML reads them off state_timer), and this project's Zero animations are
# expanded to one frame per 60fps step, so a step index here is also the
# animation frame index. That is the whole reason the rip preserves step timing.
#
# interval == 1 means a single hit landed on the start step. interval > 1 means
# the blade stays live from start to end and may hit the same target again every
# `interval` steps, which is what makes Ryuenjin and Hyouretsuzan multi-hit.

const SINGLE_HIT := 1

# offset/extents describe the blade box in pixels, before facing is applied.
const ATTACKS := {
	"atk1": {
		"animation": "atk_1", "damage": 2, "start": 0, "end": 6, "interval": SINGLE_HIT,
		"offset": Vector2(16, -8), "extents": Vector2(14, 12), "ground": true,
	},
	"atk2": {
		"animation": "atk_2", "damage": 2, "start": 2, "end": 6, "interval": SINGLE_HIT,
		"offset": Vector2(16, -8), "extents": Vector2(14, 12), "ground": true,
	},
	"atk3": {
		"animation": "atk_3", "damage": 1, "start": 0, "end": 8, "interval": 6,
		"offset": Vector2(18, -8), "extents": Vector2(16, 14), "ground": true,
	},
	"jump": {
		"animation": "atk_jump", "damage": 2, "start": 1, "end": 8, "interval": 2,
		"offset": Vector2(14, -4), "extents": Vector2(14, 14), "ground": false,
	},
	"wall": {
		"animation": "atk_wall", "damage": 2, "start": 3, "end": 8, "interval": 2,
		"offset": Vector2(12, -6), "extents": Vector2(12, 12), "ground": false,
	},
	"mikazukizan": {
		"animation": "atk_mikazukizan", "damage": 3, "start": 1, "end": 8, "interval": 6,
		"offset": Vector2(0, -8), "extents": Vector2(20, 18), "ground": false,
		"rise": 150.0,
	},
	"ryuenjin": {
		"animation": "atk_ryuenjin", "damage": 1, "start": 4, "end": 30, "interval": 6,
		"offset": Vector2(10, -18), "extents": Vector2(12, 20), "ground": true,
		"rise": 250.0,
	},
	"hyouretsuzan": {
		"animation": "atk_hyouretsuzan", "damage": 2, "start": 4, "end": -1, "interval": 6,
		"offset": Vector2(0, 12), "extents": Vector2(10, 18), "ground": false,
		"dive": 320.0,
	},
	"shippuuga": {
		"animation": "atk_shippuuga", "damage": 2, "start": 2, "end": 10, "interval": 6,
		"offset": Vector2(18, -6), "extents": Vector2(16, 12), "ground": true,
		"lunge": 170.0,
	},
	"raikousen": {
		"animation": "atk_raikousen", "damage": 2, "start": 12, "end": 32, "interval": 6,
		"offset": Vector2(24, -6), "extents": Vector2(30, 10), "ground": false,
		"lunge": 300.0,
	},
}

# The ground chain. Each link is only reached by pressing attack again while the
# previous one is swinging.
const COMBO := ["atk1", "atk2", "atk3"]

# The swap happens no earlier than step 8 so a mashed button cannot skip through
# the whole chain instantly. GML also ignores the press until step 3, but it
# polls a held key where this reads an edge, so the press that started the swing
# cannot re-register anyway - only step 0 needs excluding. Accepting the
# follow-up from step 1 makes mashing work, which the stricter window did not.
const COMBO_INPUT_STEP := 0
const COMBO_SWAP_STEP := 8

# How long after a swing ends the chain still counts as running. GML drops the
# chain the moment the swing finishes, which works there because its recovery is
# short; here it meant every press restarted at atk_1 and all three slashes
# looked identical. Holding the position for a moment is what makes mashing read
# as one-two-three.
const COMBO_GRACE := 0.35

# Ground slashes are cancelled by leaving the floor, but is_on_floor() flickers
# for a frame on slopes and moving platforms. Cancelling on a single false
# reading ended the swing almost immediately, which is why only the first frames
# of atk_1 were ever visible.
const AIRBORNE_FRAMES_TO_CANCEL := 4

# Where the blade sits while it is not cutting. Enemies carry no collision layer
# of their own - they detect an incoming "Player Projectile" body with their own
# hurtbox area and call hit() on it - so the blade has to physically enter that
# area for the signal to fire. Toggling the shape's `disabled` flag does not: the
# area then reports the overlap in get_overlapping_bodies() but never emits
# body_entered, and no damage is ever dealt. Moving the blade in and out is what
# produces a real entry transition.
const PARKED := Vector2(0, 100000)

export var saber_sound_light : AudioStream
export var saber_sound_heavy : AudioStream
export var saber_sound_ryuenjin : AudioStream
export var saber_sound_hyouretsuzan : AudioStream

onready var damage_area : KinematicBody2D = $SaberArea
onready var damage_shape : CollisionShape2D = $SaberArea/collisionShape2D

var attack := ""
var steps := 0
var queued_next := false
var ending := false
var airborne_steps := 0
# Where the ground chain got to, kept alive briefly after the swing ends so the
# next press continues it instead of starting over.
var combo_index := -1
var combo_grace := 0.0
var targets := []
# Target -> the step it was last damaged on, so a sustained blade re-hits on the
# attack's own interval instead of once per frame.
var last_hit_step := {}

func _ready() -> void:
	#The shape stays enabled for the whole life of the ability; position is what
	#turns the blade on and off.
	damage_shape.disabled = false
	park_hitbox()

#A slash is a whole-body animation, unlike X's buster which only swaps an arm
#layer. Claiming priority makes the swing stop Walk and keeps Idle and Fall -
#both of which declare conflicting_moves = ["Anything"] - from restarting and
#overwriting the animation mid-swing. It also means this ability must never
#list "Nothing", or StopAnyConflictingMoves would bail out before stopping
#anything and the slash would be painted over by the locomotion animations.
func is_high_priority() -> bool:
	return true

func _StartCondition() -> bool:
	return select_attack() != ""

# Mirrors MMX-Next's player_saber_check: the situation picks the attack, not a
# separate button per technique. Order matters - the directional and dash
# variants are tested before the plain slash so they win when they apply.
func select_attack() -> String:
	if character.is_on_floor():
		if holding("move_up"):
			return "ryuenjin"
		if character.is_executing("Dash"):
			return "shippuuga"
		return COMBO[next_combo_index()]
	if character.is_executing("WallSlide"):
		return "wall"
	if holding("move_down"):
		return "hyouretsuzan"
	if holding("move_up"):
		return "mikazukizan"
	#An air dash converts into the horizontal lightning dash rather than a plain
	#air slash, which is how Raikousen is reached without its own button.
	if character.is_executing("AirDash"):
		return "raikousen"
	return "jump"

#The next link in the ground chain: the one after whatever last landed if the
#grace window is still open, otherwise back to the first slash.
func next_combo_index() -> int:
	if combo_grace > 0.0 and combo_index >= 0 and combo_index + 1 < COMBO.size():
		return combo_index + 1
	return 0

func _process(delta : float) -> void:
	if combo_grace > 0.0 and not executing:
		combo_grace -= delta
		if combo_grace <= 0.0:
			combo_index = -1

func _Setup() -> void:
	ending = false
	airborne_steps = 0
	begin_attack(select_attack())

func begin_attack(new_attack : String) -> void:
	attack = new_attack
	steps = 0
	queued_next = false
	targets.clear()
	last_hit_step.clear()
	park_hitbox()
	var data : Dictionary = ATTACKS[attack]
	#Sized once per attack rather than every frame, so the shape resource is not
	#being mutated underneath the physics server mid-swing.
	if damage_shape.shape is RectangleShape2D:
		damage_shape.shape = damage_shape.shape.duplicate()
		damage_shape.shape.extents = data.extents
	combo_index = COMBO.find(attack)
	combo_grace = COMBO_GRACE
	character.play_animation(data.animation)
	#Committing to a facing at the start stops the slash from being steered
	#mid-swing, which would let the hitbox swap sides under the animation.
	if character.get_direction() != 0:
		character.update_facing_direction()
	play_sound(sound_for(attack))

#Ryuenjin and Hyouretsuzan have their own voice in the original; everything else
#splits between the light and heavy slash, with the combo finisher taking heavy.
func sound_for(which : String) -> AudioStream:
	match which:
		"ryuenjin":
			return saber_sound_ryuenjin
		"hyouretsuzan":
			return saber_sound_hyouretsuzan
		"atk3", "mikazukizan":
			return saber_sound_heavy
	return saber_sound_light

func _Update(delta : float) -> void:
	var data : Dictionary = ATTACKS[attack]

	if ending:
		return

	apply_movement(data, delta)
	hold_loop_segment(data)
	update_hitbox(data)
	damage_targets(data)

	if steps > COMBO_INPUT_STEP and attack_just_pressed():
		queued_next = true

	if should_advance_combo():
		begin_attack(COMBO[COMBO.find(attack) + 1])
		return

	steps += 1

# Grounded slashes plant Zero in place; the techniques carry their own motion.
func apply_movement(data : Dictionary, delta : float) -> void:
	if data.has("rise") and steps == 0:
		character.set_vertical_speed(-data.rise)
	elif data.has("dive"):
		character.set_vertical_speed(data.dive)
	elif data.has("lunge"):
		character.set_horizontal_speed(data.lunge * character.get_facing_direction())
	elif data.ground:
		character.set_horizontal_speed(0.0)

	if not data.ground and not data.has("dive") and not data.has("lunge"):
		process_gravity(delta)

#Hyouretsuzan runs until Zero lands, which can outlast its 9 frame animation.
#GML loops a tail segment for exactly this case and the ripper emits it as
#"<animation>_loop", so hand over to it rather than freezing on the last frame.
func hold_loop_segment(data : Dictionary) -> void:
	var length := animation_length(data.animation)
	if length == 0 or steps < length:
		return
	var loop_animation : String = data.animation + "_loop"
	if animation_length(loop_animation) > 0 and character.get_animation() != loop_animation:
		character.play_animation(loop_animation)

func window_is_open(data : Dictionary) -> bool:
	if steps < data.start:
		return false
	#end == -1 marks a window with no natural close - Hyouretsuzan stays live for
	#the whole dive and is ended by hitting the ground instead.
	return data.end == -1 or steps <= data.end

func update_hitbox(data : Dictionary) -> void:
	if not window_is_open(data):
		park_hitbox()
		return
	var facing = character.get_facing_direction()
	damage_area.position = Vector2(data.offset.x * facing, data.offset.y)

func park_hitbox() -> void:
	damage_area.position = PARKED

# Enemies are found by sweeping the blade's rectangle over everything in the
# "Enemies" group rather than waiting for their hurtbox to report a collision.
# The hurtbox route is what the game's projectiles use, but it only fires when
# the projectile itself travels into the area under its own movement; the blade
# is teleported in and out for a few frames at a time and the entry event never
# arrives, so it dealt no damage at all. Sweeping is deterministic and needs no
# physics events.
func sweep_for_targets(data : Dictionary) -> void:
	var facing = character.get_facing_direction()
	var centre : Vector2 = character.global_position + Vector2(data.offset.x * facing, data.offset.y)
	var blade := Rect2(centre - data.extents, data.extents * 2.0)

	for enemy in get_tree().get_nodes_in_group("Enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if not blade.has_point(enemy.global_position) and not blade.intersects(hurt_rect(enemy)):
			continue
		var receiver = damage_receiver(enemy)
		if receiver != null and not (receiver in targets):
			targets.append(receiver)

# An enemy's hurtbox is its own area, so its extent is what the blade has to
# reach - the node origin alone is often at its feet.
func hurt_rect(enemy : Node2D) -> Rect2:
	var area = enemy.get_node_or_null("area2D")
	if area == null:
		return Rect2(enemy.global_position, Vector2.ZERO)
	var shape_node = area.get_node_or_null("collisionShape2D")
	if shape_node == null or shape_node.shape == null or not shape_node.shape is RectangleShape2D:
		return Rect2(area.global_position, Vector2.ZERO)
	var extents : Vector2 = shape_node.shape.extents * area.global_scale.abs()
	return Rect2(shape_node.global_position - extents, extents * 2.0)

# Damage is taken by the enemy's damage module, which owns its invulnerability
# and reduction rules, so it is preferred over the root node.
func damage_receiver(enemy : Node):
	for child in enemy.get_children():
		if child.has_method("damage") and "active" in child and child.active:
			return child
	if enemy.has_method("damage"):
		return enemy
	return null

func damage_targets(data : Dictionary) -> void:
	if not window_is_open(data):
		return
	sweep_for_targets(data)
	for target in targets:
		if not is_instance_valid(target):
			continue
		#What arrives here is whatever the hurtbox passed to hit(), which for an
		#enemy is its EnemyDamage node rather than the enemy root - so checking
		#for the "Enemies" group would reject every real hit. Anything that can
		#take damage exposes damage(); that is the actual contract.
		if not target.has_method("damage"):
			continue
		if not can_hit_again(target, data):
			continue
		last_hit_step[target] = steps
		target.damage(data.damage, self)
		character.emit_signal("melee_hit", target)

func can_hit_again(target, data : Dictionary) -> bool:
	if not last_hit_step.has(target):
		return true
	#A single-hit attack never repeats; a sustained one waits out its interval.
	if data.interval <= SINGLE_HIT:
		return false
	return steps - last_hit_step[target] >= data.interval

func should_advance_combo() -> bool:
	if not queued_next or steps < COMBO_SWAP_STEP:
		return false
	if not character.is_on_floor():
		return false
	var index := COMBO.find(attack)
	return index != -1 and index + 1 < COMBO.size()

func _EndCondition() -> bool:
	if attack == "":
		return true
	var data : Dictionary = ATTACKS[attack]
	#The dive only resolves on landing, however long the fall takes.
	if data.has("dive"):
		return character.is_on_floor()
	#Leaving the floor cancels a grounded slash, matching the GML cancel check.
	if data.ground and steps > 0:
		if character.is_on_floor():
			airborne_steps = 0
		else:
			airborne_steps += 1
			if airborne_steps >= AIRBORNE_FRAMES_TO_CANCEL:
				return true
	return steps >= animation_length(data.animation)

func animation_length(anim : String) -> int:
	var frames = character.animatedSprite.frames
	if frames and frames.has_animation(anim):
		return frames.get_frame_count(anim)
	return 0

func _Interrupt() -> void:
	park_hitbox()
	targets.clear()
	last_hit_step.clear()
	play_end_animation()
	attack = ""
	steps = 0
	queued_next = false

# Each slash has a matching recovery animation; playing it keeps Zero from
# snapping straight back to idle out of a follow-through.
func play_end_animation() -> void:
	if attack == "":
		return
	var end_animation : String = ATTACKS[attack].animation + "_end"
	if animation_length(end_animation) > 0:
		character.play_animation(end_animation)

func holding(action : String) -> bool:
	return character.get_action_strength(action) > 0.0

#Ability exposes `actions`, the list of input names this ability answers to, so
#the combo follow-up reads the same button that started the swing.
func attack_just_pressed() -> bool:
	for input in actions:
		if character.get_action_just_pressed(input):
			return true
	return false

# Called by the SaberArea when a body enters or leaves it.
func hit(body) -> void:
	if not (body in targets):
		targets.append(body)

func leave(body) -> void:
	if body in targets:
		targets.erase(body)
	last_hit_step.erase(body)
