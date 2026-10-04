extends Node

# "NoahsPark" and "NoahsPark2" are two different levels, and the difference
# matters a lot:
#
#   NoahsPark  -> src/Levels/NoahsPark/Intro_NoahsPark.tscn   (one-off intro)
#   NoahsPark2 -> Axl_mod/Levels/NoahsPark/Stage_NoahsPark.tscn (replayable)
#
# Only the replayable stage contains the K-Knuckle pickup and the upper route
# that leads to it. Every start button is supposed to send a player who already
# has "finished_intro" to stage select - where NoahsPark2 lives - instead of
# replaying the intro. The character carousel's GameStart defined the check but
# never called it, so picking a character without a queued mission replayed the
# intro, and the K-Knuckle area simply did not exist in the level being played.

var failures := []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func read_text(path: String) -> String:
	var file := File.new()
	if file.open(path, File.READ) != OK:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func node_count(scene_path: String, needle: String) -> int:
	return read_text(scene_path).count(needle)

func _ready() -> void:
	# The two stage names must keep resolving to two different scenes.
	var gm_source := read_text("res://src/Scripts/GameManager.gd")
	check("res://src/Levels/NoahsPark/Intro_NoahsPark.tscn" in gm_source,
		"NoahsPark no longer resolves to the intro stage")
	check("res://Axl_mod/Levels/NoahsPark/Stage_NoahsPark.tscn" in gm_source,
		"NoahsPark2 no longer resolves to the replayable stage")

	# The K-Knuckle only exists in the replayable stage. If this ever flips,
	# the routing rule below stops being the thing that gates Zero's upgrade.
	check(node_count("res://Axl_mod/Levels/NoahsPark/Stage_NoahsPark.tscn",
		"Pickups/WeaponCollect") > 0,
		"The replayable Noah's Park lost its K-Knuckle pickup")
	check(node_count("res://src/Levels/NoahsPark/Intro_NoahsPark.tscn",
		"Pickups/WeaponCollect") == 0,
		"The intro stage unexpectedly gained a weapon pickup")

	# Stage select must still offer the replayable stage, or finishing the
	# intro would leave no way to reach the K-Knuckle at all.
	check("Axl_mod/StageSelect/NoahsPark2.tres"
		in read_text("res://src/StageSelect/StageSelectScreen.tscn"),
		"Stage select no longer offers NoahsPark2")

	# Every start button must consult the intro flag before replaying it.
	var start_buttons := [
		"res://System/Screens/CharacterSelection/GameStart.gd",
		"res://src/Options/GameStartButton.gd",
		"res://src/Options/GameStartButtonX.gd",
		"res://src/Options/GameStartButtonZero.gd",
		"res://src/Options/GameStartButtonAxl.gd",
	]
	for path in start_buttons:
		var source := read_text(path)
		if source.empty():
			failures.append("Could not read " + path)
			continue
		if not "already_finished_noahs_park" in source:
			continue
		# Bound the slice to go_to_next_scene's own body. Reading to the end of
		# the file would match the helper's own "func already_finished_noahs_
		# park()" declaration and pass no matter what the routing does.
		var start := source.find("func go_to_next_scene")
		check(start != -1, path.get_file() + " has no go_to_next_scene")
		if start == -1:
			continue
		var after := source.find("\nfunc ", start + 1)
		var body := source.substr(start) if after == -1 \
			else source.substr(start, after - start)
		check("already_finished_noahs_park()" in body,
			path.get_file() + " never calls already_finished_noahs_park(); a " +
			"finished campaign can be sent back into the intro stage")

	if failures.empty():
		print("PASS StageRoutingTest")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
