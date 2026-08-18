// Splits Zero's own 15-frame intro sprite across the three animations the
// shared Intro module drives. His intro is already a complete teleport-in -
// vertical beam, droplet, energy sphere, silhouette, then Zero solidifying - so
// nothing needs synthesising or recolouring.
//
// Image 0 is the descending beam and is deliberately absent from GML's own
// "intro" table, which starts at image 1; it is held here while the beam falls.
// Times are 60fps steps and images 1-13 keep the exact timings from
// player_zero_animations.
function zero_intro_animations() {
	animation_add("beam|intro",
	[
		0, 0,
		8, 0
	]);

	animation_add("beam_in|intro",
	[
		0, 1,
		2, 2,
		4, 3,
		6, 4,
		8, 5,
		10, 6,
		12, 7,
		14, 8,
		16, 9,
		18, 10,
		21, 10
	]);

	animation_add("beam_equip|intro",
	[
		0, 11,
		12, 12,
		16, 13,
		18, 13
	]);
}
