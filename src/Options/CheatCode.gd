extends X8Menu

# Code entry that unlocks the in-game cheat menu. Opened from the options screen
# and driven entirely by the d-pad, so it works on a controller and on Android,
# where there is no keyboard and the game has no touch controls at all.
#
# Up/down change the digit under the cursor, left/right move between digits, and
# the confirm button submits. Nothing here stores the code - GameManager owns
# both the expected value and the unlocked flag, and the unlock lasts for the
# session rather than being written to the save.

const color_digit := Color(0.85098, 0.898039, 1.0, 1.0)
const color_active := Color(1.0, 0.913725, 0.0, 1.0)
const color_ok := Color(0.4, 1.0, 0.45, 1.0)
const color_bad := Color(1.0, 0.42, 0.38, 1.0)

onready var digits_row : Control = $Menu/Digits
onready var status : Label = $Menu/status

var digits := []
var cursor := 0
var entered := false
var auto_close_timer: Timer

func _ready() -> void:
	digits.resize(GameManager.cheat_code_length)
	for i in digits.size():
		digits[i] = 0
	refresh()

#The screen is driven entirely by _input rather than focusable buttons, so there
#is nothing to hand focus to. X8Menu.give_focus would set .silent on the node at
#initial_focus, which only exists on X8TextureButton.
func give_focus() -> void:
	pass

func _input(event : InputEvent) -> void:
	if not active or locked:
		return
	# Handle this leaf menu's exit here rather than calling ._input(event).
	#
	# Note what does NOT protect us: Godot 3 dispatches _input through the whole
	# script chain (call_multilevel), so X8Menu._input still runs on this same
	# event no matter what, and set_input_as_handled() below cannot stop it -
	# the viewport's handled check happened before either ran. The double fade
	# is prevented by end() calling lock_buttons() synchronously before it
	# yields, so the base's `if active and not locked` guard fails when it
	# fires. Keep that guard (and KeyConfig.end()'s re-entrancy check) intact:
	# relaxing either one reintroduces a second yielded fade callback on the
	# same embedded scene, which crashes Godot 3.5 during scene teardown.
	if event.is_action_pressed(exit_action):
		cancel_auto_close()
		end()
		get_tree().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		move_cursor(1)
	elif event.is_action_pressed("ui_left"):
		move_cursor(-1)
	elif event.is_action_pressed("ui_up"):
		change_digit(1)
	elif event.is_action_pressed("ui_down"):
		change_digit(-1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		submit()

func move_cursor(step : int) -> void:
	cursor = wrapi(cursor + step, 0, digits.size())
	play_choice_sound()
	refresh()

func change_digit(step : int) -> void:
	digits[cursor] = wrapi(digits[cursor] + step, 0, 10)
	entered = false
	play_choice_sound()
	refresh()

func get_code() -> String:
	var code := ""
	for digit in digits:
		code += str(digit)
	return code

func submit() -> void:
	entered = true
	# Already-unlocked sessions stay unlocked; a wrong code only reports itself.
	var accepted : bool = GameManager.try_unlock_cheats(get_code())
	play_choice_sound()
	refresh()
	if accepted:
		schedule_auto_close()

func schedule_auto_close() -> void:
	cancel_auto_close()
	auto_close_timer = Timer.new()
	auto_close_timer.one_shot = true
	auto_close_timer.wait_time = 1.2
	auto_close_timer.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(auto_close_timer)
	auto_close_timer.connect("timeout", self, "_on_auto_close")
	auto_close_timer.start()

func cancel_auto_close() -> void:
	if is_instance_valid(auto_close_timer):
		auto_close_timer.stop()
		auto_close_timer.queue_free()
	auto_close_timer = null

func _on_auto_close() -> void:
	var finished_timer := auto_close_timer
	auto_close_timer = null
	if is_instance_valid(finished_timer):
		finished_timer.queue_free()
	end()

func refresh() -> void:
	for i in digits.size():
		var label : Label = digits_row.get_node(str(i))
		label.text = str(digits[i])
		label.add_color_override("font_color", color_active if i == cursor else color_digit)

	if GameManager.cheats_unlocked:
		status.text = "CHEATS ENABLED"
		status.add_color_override("font_color", color_ok)
	elif entered:
		status.text = "INCORRECT"
		status.add_color_override("font_color", color_bad)
	else:
		status.text = "CHEATS LOCKED"
		status.add_color_override("font_color", color_digit)
