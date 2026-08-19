extends Node

var failures := []

const stages := [
	"BoosterForest", "CentralWhite", "Dynasty", "MetalValley", "PitchBlack",
	"Primrose", "TroiaBase", "Inferno", "JakobElevator", "Gateway", "SigmaPalace"
]

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	for character in ["X", "Zero", "Axl"]:
		CharacterManager.player_character = character
		var noahs_path := "res://Axl_mod/Levels/NoahsPark/Stage_NoahsPark.tscn" if character == "Axl" else "res://src/Levels/NoahsPark/Intro_NoahsPark.tscn"
		validate_scene(character, "NoahsPark", noahs_path)
		for stage in stages:
			validate_scene(character, stage, "res://src/Levels/" + stage + "/Stage_" + stage + ".tscn")
	if failures.empty():
		print("PASS CampaignResourceMatrixTest (36 character-stage combinations)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func validate_scene(character: String, stage: String, path: String) -> void:
	var packed = load(path)
	check(packed is PackedScene, character + " / " + stage + " failed to load: " + path)
	if packed is PackedScene:
		var instance = packed.instance()
		check(instance != null, character + " / " + stage + " failed to instance")
		if instance:
			instance.free()
