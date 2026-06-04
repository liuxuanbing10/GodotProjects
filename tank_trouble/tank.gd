extends CharacterBody2D

# ── Signals ────────────────────────────────────────────────
signal shoot_requested(origin: Vector2, dir: Vector2, shooter_id: int, powerup_type: int)
signal died(player_id: int)

# ── Constants ──────────────────────────────────────────────
const SPEED := 220.0
const TANK_SIZE := 18.0
const SHOOT_COOLDOWN := 0.35
const GATLING_INTERVAL := 0.15
const GATLING_SHOTS := 3

enum PowerUpType { NONE, BIG_SHOT, LASER, FRAG_BOMB, GATLING, HOMING }

# ── Public state ───────────────────────────────────────────
var player_id := 0
var current_powerup := PowerUpType.NONE

# AI control — set by AI controller
var is_ai := false
var ai_move_vector := Vector2.ZERO
var ai_wants_shoot := false

# ── Private state ──────────────────────────────────────────
var _facing := Vector2.UP
var _can_shoot := true
var _cooldown_timer: Timer

# Gatling burst
var _gatling_shots_remaining := 0
var _gatling_timer: Timer
var _gatling_timers: Array[Timer] = []  # track all burst timers for cleanup

# Visual colours
var _body_color: Color
var _barrel_color: Color
var _tread_color: Color

# Input action names
var _action_left := ""
var _action_right := ""
var _action_up := ""
var _action_down := ""
var _action_shoot := ""


# ── Setup ──────────────────────────────────────────────────
func setup(id: int, pos: Vector2, body_col: Color, barrel_col: Color, tread_col: Color,
		left: String, right: String, up: String, down: String, shoot: String,
		ai: bool = false) -> void:
	player_id = id
	position = pos
	_body_color = body_col
	_barrel_color = barrel_col
	_tread_color = tread_col
	_action_left = left
	_action_right = right
	_action_up = up
	_action_down = down
	_action_shoot = shoot
	is_ai = ai

	# Collision: layer 2 (tanks), mask 1 (walls) + 2 (other tanks)
	collision_layer = 2
	collision_mask = 1 | 2

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TANK_SIZE * 2.0, TANK_SIZE * 2.0)
	shape.shape = rect
	add_child(shape)

	add_to_group("tanks")

	# Clean up timers if we get freed during cooldown
	tree_exiting.connect(_cleanup_timers)


func _cleanup_timers() -> void:
	if _cooldown_timer and is_instance_valid(_cooldown_timer):
		_cooldown_timer.queue_free()
		_cooldown_timer = null
	for t in _gatling_timers:
		if is_instance_valid(t):
			t.queue_free()
	_gatling_timers.clear()
	_gatling_timer = null


# ── Physics ────────────────────────────────────────────────
func _physics_process(_delta: float) -> void:
	if not is_inside_tree():
		return

	var dir := _get_move_dir()
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		_facing = dir
		rotation = dir.angle()

	velocity = dir * SPEED
	move_and_slide()

	# Shooting
	if _wants_to_shoot() and _can_shoot:
		if is_ai:
			ai_wants_shoot = false  # Consume the one-shot signal
		_shoot()


func _get_move_dir() -> Vector2:
	if is_ai:
		return ai_move_vector

	var dx := Input.get_axis(_action_left, _action_right)
	var dy := Input.get_axis(_action_up, _action_down)
	return Vector2(dx, dy)


func _wants_to_shoot() -> bool:
	if is_ai:
		return ai_wants_shoot
	return Input.is_action_just_pressed(_action_shoot)


# ── Shooting ───────────────────────────────────────────────
func _shoot() -> void:
	_can_shoot = false

	var pu := current_powerup
	current_powerup = PowerUpType.NONE
	shoot_requested.emit(global_position, _facing, player_id, pu)

	# Handle gatling burst — queue follow-up shots
	if pu == PowerUpType.GATLING:
		_gatling_shots_remaining = GATLING_SHOTS - 1
		if _gatling_shots_remaining > 0:
			_gatling_timer = _create_gatling_timer()
			_gatling_timer.start()
	else:
		_start_cooldown()


func _on_gatling_tick() -> void:
	if not is_instance_valid(self):
		return
	_gatling_shots_remaining -= 1
	shoot_requested.emit(global_position, _facing, player_id, PowerUpType.GATLING)

	if _gatling_shots_remaining > 0:
		# Schedule next shot — track for cleanup
		var t := _create_gatling_timer()
		t.start()
	else:
		_start_cooldown()


func _create_gatling_timer() -> Timer:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = GATLING_INTERVAL
	add_child(t)
	t.timeout.connect(_on_gatling_tick)
	_gatling_timers.append(t)
	return t


func _start_cooldown() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	_cooldown_timer.wait_time = SHOOT_COOLDOWN
	add_child(_cooldown_timer)
	_cooldown_timer.timeout.connect(func() -> void:
		_can_shoot = true
		_cooldown_timer.queue_free()
	)
	_cooldown_timer.start()


# ── Damage ─────────────────────────────────────────────────
func hit() -> void:
	died.emit(player_id)
	queue_free()


# ── Power-up ───────────────────────────────────────────────
func apply_powerup(type: int) -> void:
	if current_powerup != PowerUpType.NONE:
		return  # Already holding one — ignore
	current_powerup = type


# ── Visual ─────────────────────────────────────────────────
func _draw() -> void:
	var s := TANK_SIZE

	# Body
	draw_rect(Rect2(-s, -s, s * 2.0, s * 2.0), _body_color)

	# Treads
	draw_rect(Rect2(-s - 2, -s - 2, s * 2.0 + 4, 4), _tread_color)
	draw_rect(Rect2(-s - 2, s - 2, s * 2.0 + 4, 4), _tread_color)

	# Barrel (drawn facing UP; rotation handles all directions)
	var barrel_len := s + 10.0
	draw_rect(Rect2(-2, -barrel_len, 4, barrel_len - s * 0.3), _barrel_color)

	# Turret dome
	draw_circle(Vector2.ZERO, s * 0.45, Color.WHITE)
