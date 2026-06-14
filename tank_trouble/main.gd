extends Node2D

# ═══════════════════════════════════════════════════════════
# Tank Trouble — Game Orchestrator & State Machine
# ═══════════════════════════════════════════════════════════

# ── Enums ──────────────────────────────────────────────────
enum GameState { MENU, PLAYING, ROUND_TRANSITION, GAME_OVER }
enum GameMode { MODE_1P, MODE_2P, MODE_3P }



# ── Spawn positions (world coords) ────────────────────────
const SPAWN_P1 := Vector2(60.0, 60.0)
const SPAWN_P2 := Vector2(900.0, 580.0)
const SPAWN_P3 := Vector2(900.0, 60.0)

# ── Tank colours ──────────────────────────────────────────
const P1_COL := [Color(0.2, 0.4, 0.9), Color(0.3, 0.5, 1.0), Color(0.1, 0.2, 0.5)]
const P2_COL := [Color(0.9, 0.2, 0.2), Color(1.0, 0.3, 0.3), Color(0.5, 0.1, 0.1)]
const P3_COL := [Color(0.2, 0.8, 0.2), Color(0.3, 1.0, 0.3), Color(0.1, 0.4, 0.1)]

# ── Gameplay tuning ────────────────────────────────────────
const POWERUP_SPAWN_MIN := 5.0
const POWERUP_SPAWN_MAX := 8.0
const MAX_POWERUPS := 3
const LASER_LENGTH := 800.0
const LASER_FADE := 0.2
const TRANSITION_DELAY := 1.8
const SHAKE_STR := 4.0
const SHAKE_LEN := 0.15
const LEADING_ADVANTAGE_GAP := 2  # 领先多少分触发优势
const LEADING_SPEED_BOOST := 1.25  # 领先时速度倍率

# ── Preloads ───────────────────────────────────────────────
const TankScript := preload("res://tank.gd")
const BulletScript := preload("res://bullet.gd")
const ExplosionScript := preload("res://explosion.gd")
const HUDClass := preload("res://hud.gd")
const MazeGen := preload("res://maze_generator.gd")

# PowerUp / AI scripts may not exist yet at parse time
var PowerUpScript = load("res://powerup.gd")
var AIScript = load("res://ai_laika.gd")

# ── State ──────────────────────────────────────────────────
var state := GameState.MENU
var game_mode := GameMode.MODE_2P
var scores := [0, 0, 0]
var round_num := 0
var round_active := false
var current_maze: Array = []
var _wall_cells: Array[Vector2] = []

# ── Difficulty & Tank Selection ──────────────────────────────
var selected_difficulty: int = Constants.Difficulty.NORMAL
var selected_tank_type: int = Constants.TankType.BALANCED
var _current_map_id: int = 0  # 用于成就追踪的地图ID

# ── Achievement System ──────────────────────────────────────
var achievement_system: Node = null

# ── Node references ───────────────────────────────────────
var tanks: Array[Node] = []
var bullet_container: Node2D = null
var explosion_container: Node2D = null
var wall_container: Node2D = null
var powerup_container: Node2D = null
var hud_node: CanvasLayer = null
var powerup_timer: Timer = null
var camera: Camera2D = null

# ── Pause menu ──────────────────────────────────────────────
var menu_manager: Control = null

# ── Menu state ─────────────────────────────────────────────
var _menu_btns: Array[Dictionary] = []
var _menu_hover := -1
var _sound_on := true

# ── Laser visual ───────────────────────────────────────────
var _laser_t := 0.0
var _laser_a := Vector2.ZERO
var _laser_b := Vector2.ZERO
var _laser_hit := false

# ── Screen shake ───────────────────────────────────────────
var _shake_t := 0.0

# ═══════════════════════════════════════════════════════════
# INIT
# ═══════════════════════════════════════════════════════════

func _ready() -> void:
	_setup_inputs()
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	_build_menu()
	state = GameState.MENU

	# ── Pause menu overlay ──
	var MenuManagerScript := load("res://menu_manager.gd")
	if MenuManagerScript:
		menu_manager = MenuManagerScript.new()
		add_child(menu_manager)
		menu_manager.resume_pressed.connect(_on_pause_resume)
		menu_manager.sound_toggled.connect(_on_pause_sound_toggled)
		menu_manager.quit_pressed.connect(_on_pause_quit)
		menu_manager.game_start_requested.connect(_on_game_start_requested)

	# ── Achievement system ──
	var AchievementScript := load("res://achievement_system.gd")
	if AchievementScript:
		achievement_system = AchievementScript.new()
		add_child(achievement_system)
		achievement_system.achievement_unlocked.connect(_on_achievement_unlocked)

	queue_redraw()


func _setup_inputs() -> void:
	# P1: WASD + Space (left side of keyboard)
	_act("p1_left", KEY_A)
	_act("p1_right", KEY_D)
	_act("p1_up", KEY_W)
	_act("p1_down", KEY_S)
	_act("p1_shoot", KEY_SPACE)

	# P2: Arrows + Enter (right side of keyboard)
	_act("p2_left", KEY_LEFT)
	_act("p2_right", KEY_RIGHT)
	_act("p2_up", KEY_UP)
	_act("p2_down", KEY_DOWN)
	_act("p2_shoot", KEY_ENTER)

	# Pause / menu navigation (both players)
	_act("ui_pause", KEY_ESCAPE)
	_act("ui_up", KEY_W)
	_act("ui_up", KEY_UP)
	_act("ui_down", KEY_S)
	_act("ui_down", KEY_DOWN)
	_act("ui_accept", KEY_ENTER)


func _act(name: String, key: int) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name)
	var e := InputEventKey.new()
	e.keycode = key as Key
	InputMap.action_add_event(name, e)


func _build_menu() -> void:
	var cx := int(Constants.ARENA_W / 2)
	_menu_btns = [
		{"r": Rect2(cx - 150, 260, 300, 50), "l": "1 Player (vs Laika)", "m": GameMode.MODE_1P},
		{"r": Rect2(cx - 150, 330, 300, 50), "l": "2 Players",             "m": GameMode.MODE_2P},
		{"r": Rect2(cx - 150, 400, 300, 50), "l": "3 Players",             "m": GameMode.MODE_3P},
	]


# ═══════════════════════════════════════════════════════════
# DRAWING
# ═══════════════════════════════════════════════════════════

func _draw() -> void:
	if state == GameState.MENU:
		_draw_menu()
	if _laser_t > 0.0:
		var a := clampf(_laser_t / LASER_FADE, 0.0, 1.0)
		draw_line(_laser_a, _laser_b, Color(1.0, 0.2, 0.2, a), 3.0)
		if _laser_hit:
			draw_circle(_laser_b, 6.0, Color(1.0, 0.3, 0.3, a * 0.7))

	# Draw walls (not on menu) — shaded with brick detail
	if state != GameState.MENU:
		var hs := Constants.CELL * 0.5
		for cell in _wall_cells:
			var cx := cell.x
			var cy := cell.y
			var tl := Vector2(cx - hs, cy - hs)
			var br := Vector2(cx + hs, cy + hs)

			# Deterministic colour variation from grid position
			var h := posmod(hash(cell), 21) - 10
			var base := Color(
					0.40 + h * 0.002,
					0.35 + h * 0.002,
					0.30 + h * 0.002)
			draw_rect(Rect2(tl, br - tl), base)

			# Edge highlights (2 px) — top/left lighter, bottom/right darker
			var lit := Color(
					0.55 + h * 0.002,
					0.50 + h * 0.002,
					0.45 + h * 0.002)
			var dark := Color(
					0.25 + h * 0.002,
					0.20 + h * 0.002,
					0.15 + h * 0.002)
			draw_line(tl, Vector2(cx + hs, cy - hs), lit, 2.0)
			draw_line(tl, Vector2(cx - hs, cy + hs), lit, 2.0)
			draw_line(Vector2(cx - hs, cy + hs), Vector2(cx + hs, cy + hs), dark, 2.0)
			draw_line(Vector2(cx + hs, cy - hs), Vector2(cx + hs, cy + hs), dark, 2.0)

			# Brick mortar lines (horizontal seams at 1/3 and 2/3)
			var mortar := Color(
					0.35 + h * 0.002,
					0.30 + h * 0.002,
					0.25 + h * 0.002)
			var y1 := cy - hs + Constants.CELL / 3.0
			var y2 := cy - hs + Constants.CELL * 2.0 / 3.0
			draw_line(Vector2(cx - hs + 1, y1), Vector2(cx + hs - 1, y1), mortar, 1.0)
			draw_line(Vector2(cx - hs + 1, y2), Vector2(cx + hs - 1, y2), mortar, 1.0)


func _draw_menu() -> void:
	# Gradient background
	var top_col := Color(0.05, 0.05, 0.15)
	var bot_col := Color(0.12, 0.08, 0.2)
	for y in range(0, Constants.ARENA_H, 4):
		var t := y / Constants.ARENA_H
		draw_rect(Rect2(0, y, Constants.ARENA_W, 4), top_col.lerp(bot_col, t))

	# Subtle grid dots
	var dot_col := Color(0.2, 0.18, 0.25, 0.25)
	for x in range(0, Constants.ARENA_W, 40):
		for y in range(0, Constants.ARENA_H, 40):
			draw_circle(Vector2(x + 20, y + 20), 1.0, dot_col)

	var f := ThemeDB.fallback_font
	var fs := ThemeDB.fallback_font_size
	var cx := Constants.ARENA_W / 2.0

	# Title glow (soft ring)
	var gc := Color(1.0, 0.7, 0.1, 0.1)
	for ox in [-4.0, 4.0]:
		for oy in [-4.0, 4.0]:
			draw_string(f, Vector2(cx - 170 + ox, 100 + oy),
					"TANK TROUBLE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs * 3, gc)

	# Title shadow
	draw_string(f, Vector2(cx - 168, 102),
			"TANK TROUBLE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs * 3, Color(0, 0, 0, 0.3))

	# Main title
	draw_string(f, Vector2(cx - 170, 100),
			"TANK TROUBLE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs * 3, Color(1.0, 0.85, 0.2))

	# Accent lines flanking title
	var line_col := Color(0.4, 0.35, 0.5, 0.5)
	draw_line(Vector2(cx - 240, 128), Vector2(cx - 20, 128), line_col, 1.0)
	draw_line(Vector2(cx + 20, 128), Vector2(cx + 240, 128), line_col, 1.0)
	draw_line(Vector2(cx - 240, 129), Vector2(cx - 20, 129), Color(0.25, 0.2, 0.35, 0.3), 1.0)
	draw_line(Vector2(cx + 20, 129), Vector2(cx + 240, 129), Color(0.25, 0.2, 0.35, 0.3), 1.0)

	# Subtitle
	draw_string(f, Vector2(cx - 60, 155),
			"坦克动荡", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.7, 0.7, 0.7))

	# Buttons (rounded rects)
	for i in _menu_btns.size():
		var b := _menu_btns[i]
		var hover := i == _menu_hover
		var fill := Color(0.25, 0.25, 0.35) if not hover else Color(0.4, 0.4, 0.5)
		var border_col := Color(0.5, 0.5, 0.6) if not hover else Color(0.7, 0.7, 0.8)

		# Outer border
		_draw_rounded_rect(b.r, border_col, 8.0)
		# Inner fill (inset by 2px)
		var inner := Rect2(
				b.r.position + Vector2(2, 2),
				b.r.size - Vector2(4, 4))
		_draw_rounded_rect(inner, fill, 6.0)

		# Text
		draw_string(f, Vector2(b.r.position.x + 20, b.r.position.y + 33),
				b.l, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

	# Settings gear + sound indicator
	var gear := Vector2(Constants.ARENA_W - 45, 30)
	draw_circle(gear, 14, Color(0.3, 0.3, 0.35))
	draw_circle(gear, 10, Color(0.05, 0.05, 0.15))
	draw_string(f, Vector2(Constants.ARENA_W - 55, 38),
			"♪" if _sound_on else "✕", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	# Decorative tank silhouettes
	_draw_tank_silhouette(Vector2(80, Constants.ARENA_H - 80), Color(0.2, 0.2, 0.3, 0.3), false)
	_draw_tank_silhouette(Vector2(Constants.ARENA_W - 80, Constants.ARENA_H - 80), Color(0.2, 0.2, 0.3, 0.3), true)
	_draw_tank_silhouette(Vector2(80, 80), Color(0.2, 0.2, 0.3, 0.3), false)
	_draw_tank_silhouette(Vector2(Constants.ARENA_W - 80, 80), Color(0.2, 0.2, 0.3, 0.3), true)


func _draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	var r := rect
	if radius <= 0:
		draw_rect(r, color)
		return
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var r2 := Vector2(radius, radius)
	# Center rectangle
	draw_rect(Rect2(r.position.x + radius, r.position.y, r.size.x - radius * 2, r.size.y), color)
	# Left/right bars
	draw_rect(Rect2(r.position.x, r.position.y + radius, r.size.x, r.size.y - radius * 2), color)
	# Four corner circles (overlap covers gaps)
	draw_circle(r.position + r2, radius, color)
	draw_circle(r.position + Vector2(r.size.x - radius, radius), radius, color)
	draw_circle(r.position + Vector2(radius, r.size.y - radius), radius, color)
	draw_circle(r.position + Vector2(r.size.x - radius, r.size.y - radius), radius, color)


func _draw_tank_silhouette(pos: Vector2, color: Color, flip_h: bool) -> void:
	var dir := -1.0 if flip_h else 1.0
	# Body (horizontal rectangle)
	draw_rect(Rect2(pos.x - 16, pos.y - 10, 32, 20), color)
	# Turret (circle)
	draw_circle(pos, 7, color)
	# Barrel (line)
	draw_line(pos, pos + Vector2(dir * 24, 0), color, 3.0)


# ═══════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if state == GameState.MENU:
		_menu_input(event)
	elif state == GameState.PLAYING and event.is_action_pressed("ui_pause"):
		get_viewport().set_input_as_handled()
		if menu_manager:
			menu_manager.show_menu(_sound_on)
			get_tree().paused = true
	elif state == GameState.GAME_OVER:
		if event.is_action_pressed("ui_accept"):
			_return_to_menu()


func _menu_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mp: Vector2 = event.position
		for b in _menu_btns:
			if b.r.has_point(mp):
				_start_game(b.m)
				return
		# Settings gear
		if mp.distance_to(Vector2(Constants.ARENA_W - 45, 30)) < 16:
			_sound_on = not _sound_on
			queue_redraw()
	elif event is InputEventMouseMotion:
		var mp: Vector2 = event.position
		var h := -1
		for i in _menu_btns.size():
			if _menu_btns[i].r.has_point(mp):
				h = i
				break
		if h != _menu_hover:
			_menu_hover = h
			queue_redraw()


# ═══════════════════════════════════════════════════════════
# PROCESS (laser, shake, P3 mouse)
# ═══════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	# Laser fade
	if _laser_t > 0.0:
		_laser_t -= delta
		if _laser_t <= 0.0:
			_laser_t = 0.0
			queue_redraw()

	# Screen shake
	if _shake_t > 0.0:
		_shake_t -= delta
		if camera:
			camera.offset = Vector2(
					randf_range(-SHAKE_STR, SHAKE_STR),
					randf_range(-SHAKE_STR, SHAKE_STR))
			if _shake_t <= 0.0:
				camera.offset = Vector2.ZERO

	# P3 mouse control — direct movement toward mouse cursor
	if state == GameState.PLAYING and game_mode == GameMode.MODE_3P and tanks.size() >= 3:
		var p3 := tanks[2]
		if is_instance_valid(p3):
			var mp: Vector2 = get_global_mouse_position()
			var p3pos: Vector2 = p3.global_position
			var to_mouse := mp - p3pos
			if to_mouse.length_squared() > 100.0:
				p3.ai_move_dir = to_mouse.normalized()
			else:
				p3.ai_move_dir = Vector2.ZERO
			p3.ai_wants_shoot = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


# ═══════════════════════════════════════════════════════════
# GAME LIFECYCLE
# ═══════════════════════════════════════════════════════════

func _start_game(mode: int) -> void:
	game_mode = mode as GameMode
	scores = [0, 0, 0]
	round_num = 0
	state = GameState.PLAYING
	queue_redraw()
	_start_round()


func _start_round() -> void:
	round_num += 1
	round_active = false
	_cleanup_round()

	# 每5回合用一次预设地图，其余随机生成
	var use_preset := (round_num % 5 == 0)
	current_maze = MazeGen.get_map(use_preset, -1)
	_current_map_id = round_num  # 简化地图ID用于成就追踪

	# ── Arena ──
	_build_arena(current_maze)

	# ── Containers ──
	bullet_container = Node2D.new()
	bullet_container.name = "Bullets"
	add_child(bullet_container)

	explosion_container = Node2D.new()
	explosion_container.name = "Explosions"
	add_child(explosion_container)

	powerup_container = Node2D.new()
	powerup_container.name = "Powerups"
	add_child(powerup_container)

	# ── Tanks ──
	tanks.clear()

	# 领先优势：得分最高的玩家获得速度加成
	var max_score := scores.max()
	var leading_ids: Array[int] = []
	for i in scores.size():
		if scores[i] == max_score and max_score > 0:
			leading_ids.append(i)

	match game_mode:
		GameMode.MODE_1P:
			var p1_tank := _create_tank(0, SPAWN_P1,
					P1_COL[0], P1_COL[1], P1_COL[2], false,
					"p1_left", "p1_right", "p1_up", "p1_down", "p1_shoot",
					selected_tank_type, 1.0)
			tanks.append(p1_tank)
			var ai := _create_tank(1, SPAWN_P2,
					P2_COL[0], P2_COL[1], P2_COL[2], true,
					"", "", "", "", "",
					Constants.DIFFICULTY_DEFAULT_TANK[selected_difficulty],
					LEADING_SPEED_BOOST if 1 in leading_ids else 1.0)
			tanks.append(ai)
			_attach_ai(ai, selected_difficulty)

		GameMode.MODE_2P:
			tanks.append(_create_tank(0, SPAWN_P1,
					P1_COL[0], P1_COL[1], P1_COL[2], false,
					"p1_left", "p1_right", "p1_up", "p1_down", "p1_shoot",
					selected_tank_type, LEADING_SPEED_BOOST if 0 in leading_ids else 1.0))
			tanks.append(_create_tank(1, SPAWN_P2,
					P2_COL[0], P2_COL[1], P2_COL[2], false,
					"p2_left", "p2_right", "p2_up", "p2_down", "p2_shoot",
					selected_tank_type, LEADING_SPEED_BOOST if 1 in leading_ids else 1.0))

		GameMode.MODE_3P:
			tanks.append(_create_tank(0, SPAWN_P1,
					P1_COL[0], P1_COL[1], P1_COL[2], false,
					"p1_left", "p1_right", "p1_up", "p1_down", "p1_shoot",
					selected_tank_type, LEADING_SPEED_BOOST if 0 in leading_ids else 1.0))
			tanks.append(_create_tank(1, SPAWN_P2,
					P2_COL[0], P2_COL[1], P2_COL[2], false,
					"p2_left", "p2_right", "p2_up", "p2_down", "p2_shoot",
					selected_tank_type, LEADING_SPEED_BOOST if 1 in leading_ids else 1.0))
			tanks.append(_create_tank(2, SPAWN_P3,
					P3_COL[0], P3_COL[1], P3_COL[2], true,
					"", "", "", "", "",
					Constants.DIFFICULTY_DEFAULT_TANK[selected_difficulty],
					LEADING_SPEED_BOOST if 2 in leading_ids else 1.0))

	# ── HUD ──
	var pc := 1 if game_mode == GameMode.MODE_1P else (2 if game_mode == GameMode.MODE_2P else 3)
	hud_node = HUDClass.new()
	add_child(hud_node)
	hud_node.setup(pc)
	hud_node.update_scores(scores)
	hud_node.show_round_number(round_num)
	hud_node.show_controls_hint()

	# 通知成就系统回合开始
	if achievement_system:
		achievement_system.record_round_start()

	# ── Powerup timer ──
	powerup_timer = Timer.new()
	powerup_timer.one_shot = false
	powerup_timer.timeout.connect(_spawn_powerup)
	add_child(powerup_timer)
	powerup_timer.start(randf_range(POWERUP_SPAWN_MIN, POWERUP_SPAWN_MAX))

	round_active = true


func _cleanup_round() -> void:
	if powerup_timer:
		powerup_timer.stop()
		powerup_timer.queue_free()
		powerup_timer = null

	for t in tanks:
		if is_instance_valid(t):
			t.queue_free()
	tanks.clear()

	for n in [bullet_container, explosion_container, powerup_container, wall_container]:
		if n and is_instance_valid(n):
			n.queue_free()

	bullet_container = null
	explosion_container = null
	powerup_container = null
	wall_container = null

	if hud_node and is_instance_valid(hud_node):
		hud_node.queue_free()
		hud_node = null

	_wall_cells.clear()


func _end_round(winner_id: int) -> void:
	if not round_active:
		return
	round_active = false
	state = GameState.ROUND_TRANSITION

	if powerup_timer:
		powerup_timer.stop()

	_clear_children(bullet_container)
	_clear_children(powerup_container)

	scores[winner_id] += 1
	hud_node.update_scores(scores)

	# 通知成就系统
	if achievement_system:
		achievement_system.record_win(_current_map_id)

	if scores[winner_id] >= Constants.WIN_SCORE:
		var is_ai_win := game_mode == GameMode.MODE_1P and winner_id == 1
		hud_node.show_game_over(winner_id, is_ai_win)
		state = GameState.GAME_OVER
	else:
		hud_node.show_round_result(winner_id, scores)
		get_tree().create_timer(TRANSITION_DELAY).timeout.connect(_on_transition_end)


func _on_transition_end() -> void:
	if state == GameState.ROUND_TRANSITION:
		_start_round()


func _return_to_menu() -> void:
	_cleanup_round()
	state = GameState.MENU
	_menu_hover = -1
	queue_redraw()


# ═══════════════════════════════════════════════════════════
# PAUSE MENU HANDLERS
# ═══════════════════════════════════════════════════════════

func _on_pause_resume() -> void:
	if menu_manager:
		menu_manager.hide_menu()
	get_tree().paused = false


func _on_pause_sound_toggled(on: bool) -> void:
	_sound_on = on


func _on_pause_quit() -> void:
	if menu_manager:
		menu_manager.hide_menu()
	get_tree().paused = false
	_return_to_menu()


func _on_game_start_requested(difficulty: int, tank_type: int) -> void:
	selected_difficulty = difficulty
	selected_tank_type = tank_type
	_start_game(game_mode)


func _on_achievement_unlocked(achievement: int, data: Dictionary) -> void:
	# HUD will show achievement notification if available
	if hud_node and is_instance_valid(hud_node):
		hud_node.show_achievement(data.get("name", ""), data.get("desc", ""))
	# 播放成就音效（音效基础设施就绪后在此添加）


static func _clear_children(n: Node2D) -> void:
	if not n or not is_instance_valid(n):
		return
	for c in n.get_children():
		c.queue_free()


# ═══════════════════════════════════════════════════════════
# ARENA
# ═══════════════════════════════════════════════════════════

func _build_arena(maze: Array) -> void:
	wall_container = StaticBody2D.new()
	wall_container.name = "Walls"
	wall_container.collision_layer = 1
	add_child(wall_container)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(Constants.CELL, Constants.CELL)

	for row in Constants.GRID_ROWS:
		for col in Constants.GRID_COLS:
			if maze[row][col] == 1:
				var cs := CollisionShape2D.new()
				cs.shape = shape
				cs.position = Vector2(col * Constants.CELL + Constants.CELL * 0.5, row * Constants.CELL + Constants.CELL * 0.5)
				wall_container.add_child(cs)
				_wall_cells.append(cs.position)

	queue_redraw()


# ═══════════════════════════════════════════════════════════
# TANK
# ═══════════════════════════════════════════════════════════

func _create_tank(id: int, pos: Vector2,
		body: Color, barrel: Color, tread: Color,
		is_ai: bool,
		left: String, right: String, up: String, down: String, shoot: String,
		tank_type: int = Constants.TankType.BALANCED,
		speed_mult: float = 1.0) -> Node:

	var t := CharacterBody2D.new()
	t.set_script(TankScript)
	t.setup(id, pos, body, barrel, tread, left, right, up, down, shoot, is_ai, tank_type, speed_mult)
	t.shoot_requested.connect(_on_tank_shoot)
	t.died.connect(_on_tank_died)
	add_child(t)
	return t


func _attach_ai(tank_node: Node, difficulty: int = Constants.Difficulty.NORMAL) -> void:
	if not AIScript:
		return
	var ai := Node.new()
	ai.set_script(AIScript)
	ai.setup(tank_node, current_maze)
	ai.set_difficulty(difficulty)
	tank_node.add_child(ai)


# ═══════════════════════════════════════════════════════════
# BULLETS / LASER
# ═══════════════════════════════════════════════════════════

func _on_tank_shoot(origin: Vector2, direction: Vector2, shooter_id: int, powerup_type: int) -> void:
	if not round_active:
		return
	# LASER is handled directly by main.gd (raycast)
	if powerup_type == 2:
		_fire_laser(origin, direction, shooter_id)
		return

	var b := CharacterBody2D.new()
	b.set_script(BulletScript)
	b.setup(origin, direction, _bullet_type(powerup_type), shooter_id)
	bullet_container.add_child(b)


static func _bullet_type(powerup: int) -> int:
	# 使用 constants.gd 中统一的转换数组（索引 = PowerUp 枚举值）
	if powerup < 0 or powerup >= Constants.POWERUP_TO_BULLET_TYPE.size():
		return Constants.BulletType.NORMAL
	var bullet_t := Constants.POWERUP_TO_BULLET_TYPE[powerup]
	return bullet_t if bullet_t >= 0 else Constants.BulletType.NORMAL


func _fire_laser(origin: Vector2, direction: Vector2, shooter_id: int) -> void:
	var ss := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.new()
	q.from = origin
	q.to = origin + direction * LASER_LENGTH
	q.collision_mask = 2  # tanks only

	for t in tanks:
		if is_instance_valid(t) and t.player_id == shooter_id:
			q.exclude = [t]
			break

	var r := ss.intersect_ray(q)

	_laser_a = origin
	_laser_t = LASER_FADE
	queue_redraw()

	if r:
		_laser_b = r.position
		_laser_hit = true
		var hit: Node = r.collider
		if hit and hit.has_method("hit"):
			hit.hit(Constants.BulletType.GATLING)  # 激光用GATLING作为类型标识
			_spawn_explosion(hit.global_position, 30.0)
	else:
		_laser_b = origin + direction * LASER_LENGTH
		_laser_hit = false


# ═══════════════════════════════════════════════════════════
# TANK DEATH
# ═══════════════════════════════════════════════════════════

func _on_tank_died(player_id: int, bullet_type: int = -1) -> void:
	if not round_active:
		return

	# Explosion at death location
	for t in tanks:
		if is_instance_valid(t) and t.player_id == player_id:
			_spawn_explosion(t.global_position, 40.0)
			break

	# 通知成就系统：记录击杀类型（从击杀者的视角）
	if achievement_system:
		achievement_system.record_kill(bullet_type, _current_map_id)
		achievement_system.record_death()

	if game_mode == GameMode.MODE_3P:
		# Last tank standing wins
		var alive: Array[int] = []
		for t in tanks:
			if is_instance_valid(t):
				alive.append(t.player_id)
		if alive.size() <= 1:
			var winner := alive[0] if alive.size() == 1 else 0
			_end_round(winner)
	else:
		# 1P / 2P: the other player scores
		var winner := 1 - player_id
		_end_round(winner)


# ═══════════════════════════════════════════════════════════
# POWERUPS
# ═══════════════════════════════════════════════════════════

func _spawn_powerup() -> void:
	if not round_active or not powerup_container or not PowerUpScript:
		return

	if powerup_container.get_child_count() >= MAX_POWERUPS:
		return

	var open := MazeGen.get_open_cells(current_maze)
	if open.is_empty():
		return

	# Exclude cells occupied by tanks
	var valid: Array[Vector2i] = []
	for cell in open:
		var wp := Vector2(cell.x * Constants.CELL + Constants.CELL * 0.5, cell.y * Constants.CELL + Constants.CELL * 0.5)
		var occ := false
		for t in tanks:
			if is_instance_valid(t) and t.global_position.distance_to(wp) < 40.0:
				occ = true
				break
		if not occ:
			valid.append(cell)

	if valid.is_empty():
		return

	var cell := valid[randi() % valid.size()]
	var wp := Vector2(cell.x * Constants.CELL + Constants.CELL * 0.5, cell.y * Constants.CELL + Constants.CELL * 0.5)
	var pt := randi() % 5 + 1  # Constants.PowerUp.BIG_SHOT(1) ~ HOMING(5)

	var pu := Area2D.new()
	pu.set_script(PowerUpScript)
	pu.setup(pt, wp)
	pu.collected.connect(_on_powerup_collected)
	powerup_container.add_child(pu)

	# Reschedule with random interval
	powerup_timer.start(randf_range(POWERUP_SPAWN_MIN, POWERUP_SPAWN_MAX))


func _on_powerup_collected(tank_node: Node, powerup_type: int) -> void:
	if not is_instance_valid(tank_node) or not tank_node.has_method("apply_powerup"):
		return
	# powerup_type 已经是 Constants.PowerUp 枚举值，直接传给坦克
	tank_node.apply_powerup(powerup_type)


# ═══════════════════════════════════════════════════════════
# EXPLOSION FX
# ═══════════════════════════════════════════════════════════

func _spawn_explosion(pos: Vector2, radius: float = 40.0) -> void:
	var e := Node2D.new()
	e.set_script(ExplosionScript)
	e.setup(pos, radius)
	explosion_container.add_child(e)
	_shake_t = SHAKE_LEN
