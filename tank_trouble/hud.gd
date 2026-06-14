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

# --- Visual enhancement references ---
var _score_panel: ColorRect
var _round_panel: ColorRect
var _result_panel: ColorRect
var _game_over_panel: ColorRect
var _p1_indicator: ColorRect
var _p2_indicator: ColorRect
var _p3_indicator: ColorRect

var _continue_blink_time: float = 0.0


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	# Blinking animation for continue_label
	if continue_label != null and continue_label.visible:
		_continue_blink_time += delta * 4.0
		continue_label.modulate.a = 0.65 + 0.35 * sin(_continue_blink_time)


func _apply_label_style(label: Label, shadow_color: Color = Color(0, 0, 0, 0.8), outline_size: int = 0) -> void:
	label.add_theme_color_override("font_shadow_color", shadow_color)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	if outline_size > 0:
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		label.add_theme_constant_override("outline_size", outline_size)


func setup(player_count: int) -> void:
	# Store player count and derive game mode
	_player_count = player_count
	_game_mode = 0 if player_count == 1 else (1 if player_count == 2 else 2)

	# Clear any existing children
	score_labels.clear()
	for child in get_children():
		child.queue_free()
		remove_child(child)

	var center_x: float = Constants.ARENA_W / 2.0

	# ========== BACKGROUND PANELS ==========

	# Score bar panel (semi-transparent strip across the top)
	_score_panel = ColorRect.new()
	_score_panel.color = Color(0.1, 0.1, 0.15, 0.7)
	_score_panel.position = Vector2(0, 0)
	_score_panel.size = Vector2(Constants.ARENA_W, 46)
	add_child(_score_panel)

	# Round label panel
	_round_panel = ColorRect.new()
	_round_panel.color = Color(0, 0, 0, 0.6)
	_round_panel.position = Vector2(center_x - 110, Constants.ARENA_H * 0.3 - 6)
	_round_panel.size = Vector2(220, 52)
	_round_panel.hide()
	add_child(_round_panel)

	# Result label panel
	_result_panel = ColorRect.new()
	_result_panel.color = Color(0, 0, 0, 0.6)
	_result_panel.position = Vector2(center_x - 160, Constants.ARENA_H * 0.4 - 6)
	_result_panel.size = Vector2(320, 62)
	_result_panel.hide()
	add_child(_result_panel)

	# Game over label panel (larger)
	_game_over_panel = ColorRect.new()
	_game_over_panel.color = Color(0, 0, 0, 0.7)
	_game_over_panel.position = Vector2(center_x - 220, Constants.ARENA_H * 0.35 - 10)
	_game_over_panel.size = Vector2(440, 80)
	_game_over_panel.hide()
	add_child(_game_over_panel)

	# ========== SCORE AREA ==========

	# --- Score bar (single combined label) ---
	var score_bar := Label.new()
	score_bar.add_theme_font_size_override("font_size", 20)
	score_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_label_style(score_bar)

	if player_count == 1:
		score_bar.text = "You: 0    Laika: 0"
	elif player_count == 2:
		score_bar.text = "P1: 0    P2: 0"
	else:
		score_bar.text = "P1: 0    P2: 0    P3: 0"

	score_bar.position = Vector2(center_x - 120, 12)
	# Widen the label so text doesn't clip
	score_bar.size = Vector2(240 if player_count <= 2 else 360, 30)
	add_child(score_bar)
	score_labels.append(score_bar)

	# --- Player color indicators ---
	var indicator_size: Vector2 = Vector2(8, 20)
	var score_left: float = score_bar.position.x
	var score_width: float = score_bar.size.x

	# P1 indicator (blue) — left side
	_p1_indicator = ColorRect.new()
	_p1_indicator.color = Color(0.3, 0.5, 1.0)
	_p1_indicator.size = indicator_size
	_p1_indicator.position = Vector2(score_left + 10, score_bar.position.y + 5)
	add_child(_p1_indicator)

	# P2 indicator (red) — center-right for 2P, at 1/3 for 3P
	_p2_indicator = ColorRect.new()
	_p2_indicator.color = Color(1.0, 0.3, 0.3)
	_p2_indicator.size = indicator_size
	if player_count >= 3:
		_p2_indicator.position = Vector2(score_left + score_width / 3 + 8, score_bar.position.y + 5)
	else:
		_p2_indicator.position = Vector2(score_left + score_width / 2 + 10, score_bar.position.y + 5)
	add_child(_p2_indicator)

	# P3 indicator (green) — right side (3P only)
	_p3_indicator = ColorRect.new()
	_p3_indicator.color = Color(0.3, 1.0, 0.3)
	_p3_indicator.size = indicator_size
	_p3_indicator.visible = player_count == 3
	if player_count >= 3:
		_p3_indicator.position = Vector2(score_left + score_width * 2 / 3 + 8, score_bar.position.y + 5)
	else:
		_p3_indicator.position = Vector2(score_left + score_width - 26, score_bar.position.y + 5)
	add_child(_p3_indicator)

	# ========== CENTER LABELS ==========

	# --- Round label ---
	round_label = Label.new()
	round_label.hide()
	round_label.add_theme_font_size_override("font_size", 28)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_label_style(round_label)
	round_label.position = Vector2(center_x - 100, Constants.ARENA_H * 0.3)
	round_label.size = Vector2(200, 40)
	add_child(round_label)

	# --- Result label ---
	result_label = Label.new()
	result_label.hide()
	result_label.add_theme_font_size_override("font_size", 36)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_label_style(result_label, Color(0, 0, 0, 0.8), 2)
	result_label.position = Vector2(center_x - 150, Constants.ARENA_H * 0.4)
	result_label.size = Vector2(300, 50)
	add_child(result_label)

	# --- Game over label ---
	game_over_label = Label.new()
	game_over_label.hide()
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_label_style(game_over_label, Color(0, 0, 0, 0.8), 3)
	game_over_label.position = Vector2(center_x - 200, Constants.ARENA_H * 0.35)
	game_over_label.size = Vector2(400, 60)
	add_child(game_over_label)

	# --- Continue label ---
	continue_label = Label.new()
	continue_label.hide()
	continue_label.add_theme_font_size_override("font_size", 20)
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_label_style(continue_label, Color(0, 0, 0, 0.6))
	continue_label.text = "Press ENTER to continue"
	continue_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
	continue_label.position = Vector2(center_x - 150, Constants.ARENA_H * 0.5)
	continue_label.size = Vector2(300, 30)
	add_child(continue_label)

	# --- Controls hint ---
	controls_hint_label = Label.new()
	controls_hint_label.hide()
	controls_hint_label.add_theme_font_size_override("font_size", 14)
	controls_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_label_style(controls_hint_label, Color(0, 0, 0, 0.8))
	controls_hint_label.position = Vector2(center_x - 200, Constants.ARENA_H - 40)
	controls_hint_label.size = Vector2(400, 30)
	add_child(controls_hint_label)

	# Reset blink timer
	_continue_blink_time = 0.0


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
	_result_panel.show()

	# Auto-hide after 1.5 seconds
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 1.5
	timer.timeout.connect(_on_result_timer_timeout.bind(timer))
	add_child(timer)
	timer.start()


func _on_result_timer_timeout(timer: Timer) -> void:
	result_label.hide()
	_result_panel.hide()
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
	_game_over_panel.show()
	_continue_blink_time = 0.0


func show_round_number(num: int) -> void:
	round_label.text = "Round %d" % [num]
	round_label.show()
	_round_panel.show()

	# Auto-hide after 1 second
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 1.0
	timer.timeout.connect(_on_round_timer_timeout.bind(timer))
	add_child(timer)
	timer.start()


func _on_round_timer_timeout(timer: Timer) -> void:
	round_label.hide()
	_round_panel.hide()
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


# ── Achievement Notification ─────────────────────────────────
func show_achievement(name: String, desc: String) -> void:
	var lbl := Label.new()
	lbl.text = "🏆 " + name + "\n" + desc
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set("theme_override_colors/font_color", Color(1.0, 0.85, 0.2))
	lbl.set("theme_override_font_sizes/font_outline_size", 3)
	lbl.z_index = 200
	add_child(lbl)

	# 动画：从底部滑入居中，3秒后淡出
	var tween := create_tween()
	lbl.position = Vector2(size.x * 0.5 - 120, size.y - 80)
	lbl.modulate = Color(1, 1, 1, 0)

	# 滑入
	tween.tween_property(lbl, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(lbl, "position:y", size.y - 130, 0.3)

	# 停留2秒
	tween.tween_interval(2.0)

	# 淡出
	tween.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tween.tween_callback(lbl.queue_free)


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
	_result_panel.hide()
	_game_over_panel.hide()
	_round_panel.hide()
	# Keep score_labels visible (score panel and indicators stay)


func _get_player_name(player_id: int, game_mode: int) -> String:
	if game_mode == 0:  # 1P mode
		return "You" if player_id == 0 else "Laika"
	else:
		return "P%d" % [player_id + 1]
