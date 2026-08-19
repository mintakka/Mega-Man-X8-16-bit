extends Node

var failures := []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _ready() -> void:
	var legacy := {
		"version": 0.4,
		"collectibles": ["life_up_1", "icarus_arms"],
		"variables": {"player_lives": 7},
		"configs": {"Widescreen": true},
		"selected_character": 0
	}
	var migrated: Dictionary = Savefile.normalize_save_data(legacy)
	check(migrated["schema_version"] == Savefile.integration_schema, "Legacy schema was not upgraded")
	check(migrated["collectibles"] == legacy["collectibles"], "Legacy collectibles were lost")
	check(migrated["variables"] == legacy["variables"], "Legacy campaign variables were lost")
	check(migrated["character"]["player_character"] == 0, "Legacy character selector was not retained for canonicalization")

	GameManager.collectibles = migrated["collectibles"]
	CharacterManager.apply_save_state(migrated["character"])
	check(CharacterManager.player_character == "Zero", "Retired CharacterRoster Zero did not migrate")
	check(not CharacterManager.ultimate_x_armor, "Missing variant fields did not default off")

	var zashiko := Savefile.normalize_save_data({
		"version": "1.0.0.4",
		"collectibles": ["black_zero_armor"],
		"variables": {},
		"meta": {"difficulty": 2}
	})
	check(not zashiko.has("character"), "Original Zashiko char_data would be overwritten")
	check(zashiko["meta"]["difficulty"] == 2, "Zashiko difficulty was lost")

	GameManager.collectibles = ["white_axl_armor"]
	CharacterManager.apply_save_state({"player_character": "Axl", "white_axl_armor": true})
	check(CharacterManager.player_character == "Axl" and CharacterManager.white_axl_armor, "Axl variant did not restore")
	CharacterManager.apply_save_state({"player_character": "invalid"})
	check(CharacterManager.player_character == "X", "Unknown characters do not default to X")

	finish()

func finish() -> void:
	if failures.empty():
		print("PASS SaveMigrationTest")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
