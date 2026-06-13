extends CanvasLayer
class_name HUD

# --- Arena constants ---


# --- Properties ---
var score_labels: Array[Label] = []
var round_label: Label
var result_label: Label
var game_over_label: Label
var continue_label: Label
var controls_hint_label: Label

var _player_count := 2
var _game_mode := 1  # 0 = 1P (vs AI), 1 = 2P, 2 = 3P


func _ready() -> void:
	pass


func setup(player_count: int) -> void:
	# Store player count and derive game mode
	_player_count = player_count
	_game_mode = 0 if player_count == 1 else (1 if player_count == 2 else 2)

	# Clear any existing children
	score_labels.clear()
	for child in get_children():
		child.queue_free()
		remove_child(child)

	# --- Score bar (single combined label) ---
	var center_x: float = Constants.ARENA_W / 2.0
	var score_bar := Label.new()
	score_bar.add_theme_font_size_override("font_size", 20)
	score_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if player_count == 1:
		score_bar.text = "You: 0    Laika: 0"
	elif player_count == 2:
		score_bar.text = "P1: 0    P2: 0"
	else:
		score_bar.text = "P1: 0    P2: 0    P3: 0"

	score_bar.position = Vector2(center_x - 120, 10)
	# Widen the label so text doesn't clip
	score_bar.size = Vector2(240 if player_count <= 2 else 360, 30)
	add_child(score_bar)
	score_labels.append(score_bar)

	# --- Round label ---
	round_label = Label.new()
	round_label.hide()
	round_label.add_theme_font_size_override("font_size", 28)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.position = Vector2(center_x - 100, Constants.ARENA_H * 0.3)
	round_label.size = Vector2(200, 40)
	add_child(round_label)

	# --- Result label ---
	result_label = Label.new()
	result_label.hide()
	result_label.add_theme_font_size_override("font_size", 36)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.position = Vector2(center_x - 150, Constants.ARENA_H * 0.4)
	result_label.size = Vector2(300, 50)
	add_child(result_label)

	# --- Game over label ---
	game_over_label = Label.new()
	game_over_label.hide()
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.position = Vector2(center_x - 200, Constants.ARENA_H * 0.35)
	game_over_label.size = Vector2(400, 60)
	add_child(game_over_label)

	# --- Continue label ---
	continue_label = Label.new()
	continue_label.hide()
	continue_label.add_theme_font_size_override("font_size", 20)
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.text = "Press ENTER to continue"
	continue_label.modulate = Color(0.5, 0.5, 0.5)  # GRAY
	continue_label.position = Vector2(center_x - 150, Constants.ARENA_H * 0.5)
	continue_label.size = Vector2(300, 30)
	add_child(continue_label)

	# --- Controls hint ---
	controls_hint_label = Label.new()
	controls_hint_label.hide()
	controls_hint_label.add_theme_font_size_override("font_size", 14)
	controls_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_hint_label.position = Vector2(center_x - 200, Constants.ARENA_H - 40)
	controls_hint_label.size = Vector2(400, 30)
	add_child(controls_hint_label)


func update_scores(scores: Array) -> void:
	if score_labels.is_empty():
		return

	var combined := ""
	if _player_count == 1:
		combined = "You: %d    Laika: %d" % [scores[0], scores[1]]
	elif _player_count == 2:
		combined = "P1: %d    P2: %d" % [scores[0], scores[1]]
	else:
		combined = "P1: %d    P2: %d    P3: %d" % [scores[0], scores[1], scores[2]]

	score_labels[0].text = combined


func show_round_result(winner_id: int, scores: Array) -> void:
	update_scores(scores)

	var name_str := _get_player_name(winner_id, _game_mode)
	result_label.text = "%s scores!" % [name_str]
	result_label.show()

	# Auto-hide after 1.5 seconds
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 1.5
	timer.timeout.connect(_on_result_timer_timeout.bind(timer))
	add_child(timer)
	timer.start()


func _on_result_timer_timeout(timer: Timer) -> void:
	result_label.hide()
	if is_instance_valid(timer):
		timer.queue_free()


func show_game_over(winner_id: int, is_ai: bool = false) -> void:
	if _game_mode == 0:  # 1P mode
		if is_ai:
			game_over_label.text = "Laika Wins!"
		else:
			game_over_label.text = "You Win!"
	else:
		game_over_label.text = "P%d Wins!" % [winner_id + 1]

	game_over_label.show()
	continue_label.show()


func show_round_number(num: int) -> void:
	round_label.text = "Round %d" % [num]
	round_label.show()

	# Auto-hide after 1 second
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 1.0
	timer.timeout.connect(_on_round_timer_timeout.bind(timer))
	add_child(timer)
	timer.start()


func _on_round_timer_timeout(timer: Timer) -> void:
	round_label.hide()
	if is_instance_valid(timer):
		timer.queue_free()


func show_controls_hint() -> void:
	var hints := ""
	match _game_mode:
		0:  # 1P vs AI
			hints = "WASD: Move  |  Space: Shoot  |  ESC: Pause"
		1:  # 2P
			hints = "P1: WASD+Space  |  P2: Arrows+Enter  |  ESC: Pause"
		2:  # 3P
			hints = "P1: WASD+Space  |  P2: Arrows+Enter  |  P3: Mouse  |  ESC: Pause"

	controls_hint_label.text = hints
	controls_hint_label.show()

	# Auto-hide after 4 seconds
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 4.0
	timer.timeout.connect(_on_controls_hint_timeout.bind(timer))
	add_child(timer)
	timer.start()


func _on_controls_hint_timeout(timer: Timer) -> void:
	controls_hint_label.hide()
	if is_instance_valid(timer):
		timer.queue_free()


func hide_all() -> void:
	result_label.hide()
	game_over_label.hide()
	continue_label.hide()
	round_label.hide()
	controls_hint_label.hide()
	# Keep score_labels visible


func _get_player_name(player_id: int, game_mode: int) -> String:
	if game_mode == 0:  # 1P mode
		return "You" if player_id == 0 else "Laika"
	else:
		return "P%d" % [player_id + 1]
