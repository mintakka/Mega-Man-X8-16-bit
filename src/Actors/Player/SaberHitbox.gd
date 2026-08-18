extends KinematicBody2D

# The blade's damage body. A KinematicBody2D on purpose: this is moved in and
# out of enemy hurtboxes every swing by setting position, and a RigidBody2D
# moved that way never notifies the physics server of the motion - the hurtbox
# then reports the overlap through get_overlapping_bodies() but never emits
# body_entered, so no hit is ever registered. The game's own projectiles are
# kinematic bodies for the same reason.
#
# Enemies carry no collision layer of their own; their hurtbox spots an incoming
# "Player Projectile" body and calls hit() on it, which is forwarded to the
# saber ability.

var break_guards := false

func get_facing_direction() -> int:
	return get_parent().character.get_facing_direction()

func hit(_body) -> void:
	get_parent().hit(_body)

func leave(_body) -> void:
	get_parent().leave(_body)

func deflect(_whatever) -> void:
	pass
