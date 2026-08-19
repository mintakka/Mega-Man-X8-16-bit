extends Node


var save_slot: int = 0
var max_slots: int = 10
const save_version: String = "1.0.0.4"
const integration_schema: int = 2
const legacy_current_path: String = "user://savegame.save"

var game_data = {}
var newgame_plus: int = 0

signal loaded
signal saved


func get_config_path() -> String:
	return "user://config"
	
func save_config_data() -> void :
	
	var config_data = {
		"configs": Configurations.variables, 
		"keys": InputManager.modified_keys, 
		"achievements": Achievements.export_unlocked_list()
	}
	var bson = BSON.to_bson(config_data)
	var file = File.new()
	file.open(get_config_path(), File.WRITE)
	file.store_buffer(bson)
	file.close()

func load_config_data() -> void :
	var file = File.new()
	if not file.file_exists(get_config_path()):
		return
	file.open(get_config_path(), File.READ)
	file.seek_end(-1)
	var final = file.get_8()
	file.seek(0)
	if final == 0:
		var binary_json = file.get_buffer(file.get_len())
		file.close()
		var config_data = BSON.from_bson(binary_json)
		if config_data.has("configs"):
			Configurations.load_variables(config_data["configs"])
		if config_data.has("keys"):
			InputManager.load_modified_keys(config_data["keys"])
		if config_data.has("achievements"):
			Achievements.load_achievements(config_data["achievements"])
	else:
		var encrypted_json = file.get_as_text()
		file.close()
		var encrypted_dict = JSON.parse(encrypted_json)
		if encrypted_dict.error != OK:
			return
		var enc_data = encrypted_dict.result
		var config_data = Encryption.decrypt_sha256_aes_cbc(enc_data["file"], enc_data["config"])
		if config_data.has("configs"):
			Configurations.load_variables(config_data["configs"])
		if config_data.has("keys"):
			InputManager.load_modified_keys(config_data["keys"])
		if config_data.has("achievements"):
			Achievements.load_achievements(config_data["achievements"])


func get_save_slot(slot: int = 0) -> String:
	
	return "user://saves/save_slot_%d" % slot

func ensure_save_folder_exists() -> void :
	var dir = Directory.new()
	if not dir.dir_exists("user://saves"):
		dir.make_dir("user://saves")

func set_all_data() -> void :
	game_data["version"] = save_version
	game_data["schema_version"] = integration_schema
	game_data["collectibles"] = GameManager.collectibles
	game_data["equip_exceptions"] = GameManager.equip_exceptions
	game_data["variables"] = GlobalVariables.variables
	game_data["character"] = CharacterManager.export_save_state()
	game_data["meta"] = {
		"last_saved": OS.get_unix_time(), 
		"difficulty": CharacterManager.game_mode, 
		"game_mode_set": CharacterManager.game_mode_set, 
		"newgame_plus": newgame_plus
	}

func save(slot: int = 0) -> void :
	
	set_all_data()
	write_to_file(slot)
	call_deferred("save_config_data")
	emit_signal("saved")

func write_to_file(slot: int = 0) -> void :
	ensure_save_folder_exists()
	var file = File.new()
	var bson = BSON.to_bson(game_data)
	file.open(get_save_slot(slot), file.WRITE)
	file.store_buffer(bson)
	file.close()

func load_save(slot: int = 0) -> void :
	
	CharacterManager.game_mode_set = false
	CharacterManager.game_mode = 0
	newgame_plus = 0
	GameManager.collectibles = []
	GameManager.equip_exceptions = []
	GlobalVariables.variables = {}
	# Read the original Zashiko character file first. Per-slot character data,
	# when present, overrides it in apply_data().
	CharacterManager._load()
	load_from_file(slot)
	apply_data(slot)
	CharacterManager._save()
	emit_signal("loaded")
	
func load_from_file(slot: int = 0) -> void :
	var file = File.new()
	if not file.file_exists(get_save_slot(slot)):
		clear_save(slot)
	file.open(get_save_slot(slot), File.READ)
	file.seek_end(-1)
	var final = file.get_8()
	file.seek(0)
	if final == 0:
		var bson = file.get_buffer(file.get_len())
		var dict = BSON.from_bson(bson)
		game_data = dict
	else:
		var encrypted_json = file.get_as_text()
		var encrypted_dict = JSON.parse(encrypted_json)
		if encrypted_dict.error != OK:
			return
		var enc_data = encrypted_dict.result
		game_data = Encryption.decrypt_sha256_aes_cbc(enc_data["file"], enc_data["save"])
	file.close()

func load_latest_save() -> void :
	var latest_time: = - 1
	var latest_slot: = - 1
	for i in range(max_slots):
		var data = load_slot_metadata(i)
		var meta = {}
		if data.has("meta"):
			meta = data["meta"]
		if meta.has("last_saved"):
			var saved_time = int(meta["last_saved"])
			if saved_time > latest_time:
				latest_time = saved_time
				latest_slot = i
	if latest_slot != - 1:
		
		save_slot = latest_slot
		load_save(latest_slot)
	else:
		save_slot = 0
		var legacy_data := read_legacy_current_save()
		if not legacy_data.empty():
			game_data = normalize_save_data(legacy_data)
			apply_legacy_config(legacy_data)
			write_to_file(0)
			load_save(0)
		else:
			load_save(0)

func read_legacy_current_save() -> Dictionary:
	var file := File.new()
	if not file.file_exists(legacy_current_path):
		return {}
	if file.open(legacy_current_path, File.READ) != OK:
		return {}
	var result = file.get_var()
	file.close()
	if typeof(result) == TYPE_DICTIONARY:
		return result
	return {}

func default_character_state() -> Dictionary:
	return {
		"player_count": 1,
		"player_character": "X",
		"ultimate_x_armor": false,
		"black_zero_armor": false,
		"white_axl_armor": false,
		"beta_zero_unlocked": false,
		"beta_zero_activated": false,
		"custom_zero_unlocked": false,
		"custom_zero_armor": false
	}

func extract_legacy_character(data: Dictionary) -> Dictionary:
	if typeof(data.get("character")) == TYPE_DICTIONARY:
		return data["character"].duplicate(true)
	var candidate = null
	for key in ["selected_character", "picked_character", "active_character", "player_character"]:
		if data.has(key):
			candidate = data[key]
			break
	var variables = data.get("variables", {})
	if candidate == null and typeof(variables) == TYPE_DICTIONARY:
		for key in ["selected_character", "picked_character", "active_character", "player_character"]:
			if variables.has(key):
				candidate = variables[key]
				break
	if candidate == null:
		return {}
	var character := default_character_state()
	character["player_character"] = candidate
	return character

func normalize_save_data(data: Dictionary) -> Dictionary:
	var normalized := {
		"version": save_version,
		"schema_version": integration_schema,
		"collectibles": data.get("collectibles", []),
		"equip_exceptions": data.get("equip_exceptions", []),
		"variables": data.get("variables", {}),
		"meta": data.get("meta", {})
	}
	var character := extract_legacy_character(data)
	if not character.empty():
		normalized["character"] = character
	elif typeof(data.get("version")) == TYPE_REAL or typeof(data.get("version")) == TYPE_INT:
		# The pre-Zashiko save had no separate character file. Missing selection
		# therefore means its documented default, X.
		normalized["character"] = default_character_state()
	if typeof(normalized["meta"]) != TYPE_DICTIONARY:
		normalized["meta"] = {}
	if data.has("difficulty") and not normalized["meta"].has("difficulty"):
		normalized["meta"]["difficulty"] = data["difficulty"]
	return normalized

func apply_legacy_config(data: Dictionary) -> void:
	if typeof(data.get("configs")) == TYPE_DICTIONARY:
		Configurations.load_variables(data["configs"])
	if typeof(data.get("keys")) == TYPE_DICTIONARY:
		InputManager.load_modified_keys(data["keys"])
	if data.has("achievements"):
		Achievements.load_achievements(data["achievements"])
	save_config_data()

func load_slot_metadata(slot: int) -> Dictionary:
	var file = File.new()
	var path = "user://saves/save_slot_%d" % slot
	var result = {}
	if not file.file_exists(path):
		return {}
	file.open(path, File.READ)
	file.seek_end(-1)
	var final = file.get_8()
	file.seek(0)
	if final == 0:
		var bson = file.get_buffer(file.get_len())
		var dict = BSON.from_bson(bson)
		if dict.has("meta"):
			result["meta"] = dict["meta"]
		if dict.has("collectibles"):
			result["collectibles"] = dict["collectibles"]
		if dict.has("variables"):
			result["variables"] = dict["variables"]
	else:
		var encrypted_json = file.get_as_text()
		var encrypted_dict = JSON.parse(encrypted_json)
		if encrypted_dict.error != OK:
			return result
		else:
			var enc_data = encrypted_dict.result
			var decrypted = Encryption.decrypt_sha256_aes_cbc(enc_data["file"], enc_data["save"])
			if decrypted.has("meta"):
				result["meta"] = decrypted["meta"]
			if decrypted.has("collectibles"):
				result["collectibles"] = decrypted["collectibles"]
			if decrypted.has("variables"):
				result["variables"] = decrypted["variables"]
	file.close()
	return result

func apply_data(_slot: int = 0) -> void :
	if typeof(game_data) != TYPE_DICTIONARY:
		game_data = {}
	game_data = normalize_save_data(game_data)
	var meta: Dictionary = game_data["meta"]
	CharacterManager.game_mode = int(meta.get("difficulty", 0))
	CharacterManager.game_mode_set = bool(meta.get("game_mode_set", false))
	newgame_plus = int(meta.get("newgame_plus", 0))
	GameManager.collectibles = game_data["collectibles"]
	GameManager.equip_exceptions = game_data["equip_exceptions"]
	GlobalVariables.load_variables(game_data["variables"])
	if game_data.has("character"):
		CharacterManager.apply_save_state(game_data["character"])
	else:
		CharacterManager.update_game_mode()
	if game_data["variables"].has("igt"):
		IGT.set_time(GlobalVariables.get("igt"))
	call_deferred("emit_signal", "loaded")

func clear_save(slot: int = 0) -> void :
	game_data = {
		"version": save_version,
		"schema_version": integration_schema,
		"meta": {}, 
		"collectibles": [], 
		"equip_exceptions": [], 
		"variables": {},
		"character": default_character_state()
	}
	CharacterManager.game_mode_set = false
	CharacterManager.game_mode = 0
	newgame_plus = 0
	IGT.reset()
	GameManager.collectibles = []
	GameManager.equip_exceptions = []
	GlobalVariables.variables = {}
	CharacterManager.apply_save_state(default_character_state())
	write_to_file(slot)

func clear_global_variables() -> void :
	game_data["variables"] = {}
	GlobalVariables.load_variables(game_data["variables"])

func clear_game_data(slot: int = 0) -> void :
	set_all_data()
	game_data["collectibles"] = []
	game_data["equip_exceptions"] = []
	game_data["variables"] = {}
	apply_data(slot)
	write_to_file(slot)

func clear_keybinds(slot: int = 0) -> void :
	set_all_data()
	game_data["keys"] = {}
	InputMap.load_from_globals()
	apply_data(slot)
	write_to_file(slot)

func clear_options(slot: int = 0) -> void :
	set_all_data()
	game_data["configs"] = {}
	apply_data(slot)
	write_to_file(slot)
