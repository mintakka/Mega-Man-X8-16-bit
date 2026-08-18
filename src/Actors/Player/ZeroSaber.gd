extends Movement
class_name ZeroSaber

# Zero's Z-Saber. One ability covers every slash: pick an attack from the current
# context, play its animation and matching source collision mask, then open its
# damage window partway through. The ground combo also hands off between attacks
# mid-animation, which is far simpler inside one state than across conflicting
# abilities.
#
# The numbers are lifted from MMX-Next's player_saber_init: damage, and the
# [start, end, interval] hit windows. The collision itself is generated from
# MMX-Next's precise, per-frame saber masks, aligned to the same 60 Hz animation
# timeline. This keeps reach on the visible blade instead of approximating each
# attack with a large hand-authored rectangle.
#
# interval == 1 means a single hit landed on the start step. interval > 1 means
# the blade stays live from start to end and may hit the same target again every
# `interval` steps, which is what makes Ryuenjin and Hyouretsuzan multi-hit.

const SINGLE_HIT := 1
const DAMAGE_MULTIPLIER := 2.5
const SaberMasks = preload("res://src/Actors/Player/zero_sprites/saber_masks.gd")

const ATTACKS := {
	"atk1": {
		"animation": "atk_1", "damage": 2, "start": 0, "end": 6, "interval": SINGLE_HIT,
		"ground": true,
	},
	"atk2": {
		"animation": "atk_2", "damage": 2, "start": 2, "end": 6, "interval": SINGLE_HIT,
		"ground": true,
	},
	"atk3": {
		"animation": "atk_3", "damage": 1, "start": 0, "end": 8, "interval": 6,
		"ground": true,
	},
	"jump": {
		"animation": "atk_jump", "damage": 2, "start": 1, "end": 8, "interval": 2,
		"ground": false,
	},
	"wall": {
		"animation": "atk_wall", "damage": 2, "start": 3, "end": 8, "interval": 2,
		"ground": false,
	},
	"mikazukizan": {
		"animation": "atk_mikazukizan", "damage": 3, "start": 1, "end": 8, "interval": 6,
		"ground": false, "rise": 150.0,
	},
	"ryuenjin": {
		"animation": "atk_ryuenjin", "damage": 1, "start": 4, "end": 30, "interval": 6,
		"ground": true, "rise": 250.0,
	},
	"hyouretsuzan": {
		"animation": "atk_hyouretsuzan", "damage": 2, "start": 4, "end": -1, "interval": 6,
		"ground": false, "dive": 320.0,
	},
	"shippuuga": {
		"animation": "atk_shippuuga", "damage": 2, "start": 2, "end": 10, "interval": 6,
		"ground": true, "lunge": 170.0,
	},
	"raikousen": {
		"animation": "atk_raikousen", "damage": 2, "start": 12, "end": 32, "interval": 6,
		"ground": false, "lunge": 300.0,
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

export var saber_sound_light : AudioStream
export var saber_sound_heavy : AudioStream
export var saber_sound_ryuenjin : AudioStream
export var saber_sound_hyouretsuzan : AudioStream

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
	var data : Dictionary = ATTACKS[attack]
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

# MMX-Next does precise per-frame collision against the saber sprite. The
# generated mask data stores that alpha silhouette as merged pixel cells. Each
# cell is transformed exactly like Zero's AnimatedSprite, then intersected with
# the enemy's actual damage Area2D shape. This also fixes the earlier ownership
# mistake: the "Enemies" group contains EnemyDamage receivers, not necessarily
# enemy roots, so searching below the group member could never find its sibling
# hurtbox and fell back to guessed body sizes.
func sweep_for_targets(_data : Dictionary) -> void:
	var mask_rects : Array = SaberMasks.rects_for(attack, steps)
	if mask_rects.empty():
		targets.clear()
		return
	var mask_polygons := make_mask_polygons(mask_rects)
	if mask_polygons.empty():
		targets.clear()
		return

	var overlapping := []
	for member in get_tree().get_nodes_in_group("Enemies"):
		if not is_instance_valid(member):
			continue
		var receiver = damage_receiver(member)
		if receiver == null or receiver in overlapping:
			continue
		if masks_hit_receiver(mask_polygons, receiver):
			overlapping.append(receiver)
	targets = overlapping

func make_mask_polygons(rects : Array) -> Array:
	var polygons := []
	var sprite_transform : Transform2D = character.animatedSprite.global_transform
	for rect in rects:
		var local := PoolVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		])
		polygons.append(transform_polygon(local, sprite_transform))
	return polygons

func masks_hit_receiver(mask_polygons : Array, receiver : Node) -> bool:
	var area = receiver_hurtbox(receiver)
	if area == null:
		return false
	for shape_node in collision_shapes(area):
		var hurt_polygon := collision_polygon(shape_node)
		if hurt_polygon.empty():
			continue
		var hurt_bounds := polygon_bounds(hurt_polygon)
		for mask_polygon in mask_polygons:
			if not polygon_bounds(mask_polygon).intersects(hurt_bounds):
				continue
			if not Geometry.intersect_polygons_2d(mask_polygon, hurt_polygon).empty():
				return true
	return false

func receiver_hurtbox(receiver : Node):
	if "custom_hitbox" in receiver and is_instance_valid(receiver.custom_hitbox):
		return receiver.custom_hitbox
	if "area2D" in receiver and is_instance_valid(receiver.area2D):
		return receiver.area2D
	var own_area = receiver.get_node_or_null("area2D")
	if own_area != null:
		return own_area
	var owner = receiver.get_parent()
	if owner != null:
		return owner.get_node_or_null("area2D")
	return null

func collision_shapes(node : Node) -> Array:
	var shapes := []
	collect_collision_shapes(node, shapes)
	return shapes

func collect_collision_shapes(node : Node, out : Array) -> void:
	for child in node.get_children():
		if child is CollisionShape2D and not child.disabled and child.shape != null:
			out.append(child)
		elif child is CollisionPolygon2D and not child.disabled and not child.polygon.empty():
			out.append(child)
		if child.get_child_count() > 0:
			collect_collision_shapes(child, out)

func collision_polygon(shape_node : Node2D) -> PoolVector2Array:
	if shape_node is CollisionPolygon2D:
		return transform_polygon(shape_node.polygon, shape_node.global_transform)

	var shape = shape_node.shape
	var local := PoolVector2Array()
	if shape is RectangleShape2D:
		var e : Vector2 = shape.extents
		local = PoolVector2Array([
			Vector2(-e.x, -e.y), Vector2(e.x, -e.y),
			Vector2(e.x, e.y), Vector2(-e.x, e.y),
		])
	elif shape is CircleShape2D:
		local = circle_polygon(shape.radius)
	elif shape is CapsuleShape2D:
		local = capsule_polygon(shape.radius, shape.height)
	elif shape is ConvexPolygonShape2D:
		local = shape.points
	return transform_polygon(local, shape_node.global_transform)

func circle_polygon(radius : float, point_count := 24) -> PoolVector2Array:
	var points := PoolVector2Array()
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func capsule_polygon(radius : float, height : float, point_count := 24) -> PoolVector2Array:
	var points := PoolVector2Array()
	var straight_half := max(0.0, height * 0.5 - radius)
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		var direction := Vector2(cos(angle), sin(angle))
		var cap_offset := straight_half if direction.y >= 0.0 else -straight_half
		points.append(Vector2(direction.x * radius, direction.y * radius + cap_offset))
	return points

func transform_polygon(polygon : PoolVector2Array, transform : Transform2D) -> PoolVector2Array:
	var transformed := PoolVector2Array()
	for point in polygon:
		transformed.append(transform.xform(point))
	return transformed

func polygon_bounds(polygon : PoolVector2Array) -> Rect2:
	if polygon.empty():
		return Rect2()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for index in range(1, polygon.size()):
		bounds = bounds.expand(polygon[index])
	return bounds

# Damage is taken by the enemy's damage module, which owns its invulnerability
# and reduction rules, so it is preferred over the root node.
func damage_receiver(enemy : Node):
	for child in enemy.get_children():
		if child.has_method("damage") and "active" in child and child.active:
			return child
	# Some EnemyDamage nodes add themselves to the group when their owner scene
	# does not. Root Actor nodes also expose damage(), so this fallback must come
	# after preferring their dedicated damage module above.
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
		# The receiver is normally EnemyDamage rather than the enemy root. Anything
		# that can take damage exposes damage(); that is the actual contract.
		if not target.has_method("damage"):
			continue
		if not can_hit_again(target, data):
			continue
		last_hit_step[target] = steps
		apply_saber_hit(target, data)
		character.emit_signal("melee_hit", target)

#Zero trades projectile safety for close-range power. A 2-damage light slash
#therefore lands for 5, enough to one-shot the ordinary 1-5 HP enemies while
#leaving sturdier reploids, ride armour and bosses as multi-hit targets.
func saber_damage(data : Dictionary) -> float:
	return float(data.damage) * DAMAGE_MULTIPLIER

func apply_saber_hit(target : Node, data : Dictionary) -> void:
	var damage_value := DamageValue.new(
		saber_damage(data), self, "Zero Saber", character.get_facing_direction(),
		true, character.global_position)
	#EnemyDamage.direct_hit routes through an active shield first. Because this
	#DamageValue breaks guards, a hidden Metool receives the same guard-break and
	#stagger event as X's charged buster instead of simply ignoring the blade.
	if target.has_method("direct_hit"):
		target.direct_hit(damage_value)
	else:
		target.damage(damage_value.get_damage(), self)

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
