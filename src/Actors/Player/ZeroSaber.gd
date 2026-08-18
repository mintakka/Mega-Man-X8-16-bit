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

export var saber_sound_light : AudioStream
export var saber_sound_heavy : AudioStream
export var saber_sound_ryuenjin : AudioStream
export var saber_sound_hyouretsuzan : AudioStream

onready var damage_area : PhysicsBody2D = $SaberArea
onready var damage_shape : CollisionShape2D = $SaberArea/collisionShape2D

var attack := ""
var steps := 0
var queued_next := false
var ending := false
var targets := []
# Target -> the step it was last damaged on, so a sustained blade re-hits on the
# attack's own interval instead of once per frame.
var last_hit_step := {}

func _ready() -> void:
	set_hitbox_enabled(false)

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
		return "atk1"
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

func _Setup() -> void:
	ending = false
	begin_attack(select_attack())

func begin_attack(new_attack : String) -> void:
	attack = new_attack
	steps = 0
	queued_next = false
	targets.clear()
	last_hit_step.clear()
	set_hitbox_enabled(false)
	var data : Dictionary = ATTACKS[attack]
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
	var open := window_is_open(data)
	set_hitbox_enabled(open)
	if not open:
		return
	var facing = character.get_facing_direction()
	damage_shape.position = Vector2(data.offset.x * facing, data.offset.y)
	if damage_shape.shape is RectangleShape2D:
		damage_shape.shape.extents = data.extents

func set_hitbox_enabled(enabled : bool) -> void:
	damage_shape.set_deferred("disabled", not enabled)

func damage_targets(data : Dictionary) -> void:
	if not window_is_open(data):
		return
	for target in targets:
		if not is_instance_valid(target):
			continue
		if not (target.is_in_group("Enemies") or target.is_in_group("Enemy Projectile")):
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
	if data.ground and not character.is_on_floor() and steps > 0:
		return true
	return steps >= animation_length(data.animation)

func animation_length(anim : String) -> int:
	var frames = character.animatedSprite.frames
	if frames and frames.has_animation(anim):
		return frames.get_frame_count(anim)
	return 0

func _Interrupt() -> void:
	set_hitbox_enabled(false)
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
