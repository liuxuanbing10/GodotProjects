extends CharacterBody2D

# ── Signals ────────────────────────────────────────────────
signal shoot_requested(origin: Vector2, dir: Vector2, shooter_id: int, powerup_type: int)
signal died(player_id: int)

# ── Constants ──────────────────────────────────────────────
const SPEED := 300.0
const TANK_SIZE := 18.0
const SHOOT_COOLDOWN := 0.35
const GATLING_INTERVAL := 0.15
const GATLING_SHOTS := 3
const ROTATION_SPEED := 4.5
const BARREL_OFFSET := 24.0

enum PowerUpType { NONE, BIG_SHOT, LASER, FRAG_BOMB, GATLING, HOMING }

# ── Public state ───────────────────────────────────────────
var player_id := 0
var current_powerup := PowerUpType.NONE

# AI control — set by AI controller
var is_ai := false
var ai_rotation_input := 0.0
var ai_thrust_input := 0.0
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
	rotation = -PI / 2.0  # Face UP initially (rotation 0 = RIGHT)

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
func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return

	# Rotate — smooth
	var rot := _get_rotation_input()
	rotation += rot * ROTATION_SPEED * delta

	# Facing direction derived from rotation
	var facing_dir := Vector2.RIGHT.rotated(rotation)
	_facing = facing_dir

	# Thrust with smooth acceleration / deceleration
	var thrust := _get_thrust_input()
	var target := facing_dir * thrust * SPEED
	if thrust == 0.0:
		# Decelerate quickly when no input
		velocity = velocity.lerp(Vector2.ZERO, 12.0 * delta)
	else:
		# Accelerate toward target
		velocity = velocity.lerp(target, 10.0 * delta)
	move_and_slide()

	# Shooting
	if _wants_to_shoot() and _can_shoot:
		if is_ai:
			ai_wants_shoot = false  # Consume the one-shot signal
		_shoot()


func _get_rotation_input() -> float:
	if is_ai:
		return ai_rotation_input
	return Input.get_axis(_action_left, _action_right)


func _get_thrust_input() -> float:
	if is_ai:
		return ai_thrust_input
	# get_axis(up, down): up=-1, down=+1
	# Negate so: up=+1(forward), down=-1(reverse)
	return -Input.get_axis(_action_up, _action_down)


func _wants_to_shoot() -> bool:
	if is_ai:
		return ai_wants_shoot
	return Input.is_action_just_pressed(_action_shoot)


# ── Shooting ───────────────────────────────────────────────
func _shoot() -> void:
	_can_shoot = false

	var spawn_pos := global_position + _facing * BARREL_OFFSET
	var pu := current_powerup
	current_powerup = PowerUpType.NONE
	shoot_requested.emit(spawn_pos, _facing, player_id, pu)

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
	shoot_requested.emit(global_position + _facing * BARREL_OFFSET, _facing, player_id, PowerUpType.GATLING)

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

	# ── Drop shadow ──
	draw_rect(Rect2(-s + 2, -s + 2, s * 2.0, s * 2.0), Color(0, 0, 0, 0.25))

	# ── Treads (wider bands with alternating stripes) ──
	var tw := s * 2.0 + 6.0
	var th := 5.0
	# Top tread background
	draw_rect(Rect2(-s - 3, -s - 3, tw, th), _tread_color)
	# Bottom tread background
	draw_rect(Rect2(-s - 3, s - 2, tw, th), _tread_color)
	# Tread stripes (alternating lighter/darker)
	var stripe_count := 4
	var sw := tw / stripe_count
	for i in stripe_count:
		var x := -s - 3 + i * sw
		var shade := 1.2 if i % 2 == 0 else 0.8
		var sc := Color(_tread_color.r * shade, _tread_color.g * shade, _tread_color.b * shade, 1.0)
		draw_rect(Rect2(x, -s - 3, sw, th), sc)
		draw_rect(Rect2(x, s - 2, sw, th), sc)

	# ── Body (rounded corners via octagonal polygon) ──
	var cr := 4.0
	var pts := PackedVector2Array([
		Vector2(-s + cr, -s),
		Vector2( s - cr, -s),
		Vector2( s, -s + cr),
		Vector2( s,  s - cr),
		Vector2( s - cr,  s),
		Vector2(-s + cr,  s),
		Vector2(-s,  s - cr),
		Vector2(-s, -s + cr),
	])
	draw_colored_polygon(pts, _body_color)

	# ── Barrel (wider, with highlight and muzzle ring) ──
	var barrel_len := s + 10.0
	var bw := 4.0
	# Main barrel body (10px wide: -5 to +5)
	draw_rect(Rect2(0, -bw, barrel_len - s * 0.3, bw * 2.0), _barrel_color)
	# Barrel highlight — thin lighter stripe along top edge
	var hl := Color(_barrel_color.r * 1.3, _barrel_color.g * 1.3, _barrel_color.b * 1.3, 0.6)
	draw_rect(Rect2(0, -bw, barrel_len - s * 0.3, 2.0), hl)
	# Muzzle ring at barrel tip
	var mx := barrel_len - s * 0.3 - 2.0
	draw_rect(Rect2(mx, -bw - 1, 3.0, bw * 2.0 + 2.0), Color.WHITE)

	# ── Turret dome (concentric gradient circles + specular highlight) ──
	var dr := s * 0.45
	# Outer ring (darkest)
	draw_circle(Vector2.ZERO, dr, Color.WHITE * 0.7)
	# Mid ring (medium)
	draw_circle(Vector2.ZERO, dr * 0.75, Color.WHITE * 0.85)
	# Inner ring (brightest)
	draw_circle(Vector2.ZERO, dr * 0.5, Color.WHITE)
	# Specular highlight — small white dot offset top-left
	draw_circle(Vector2(-dr * 0.2, -dr * 0.2), dr * 0.2, Color(1, 1, 1, 0.8))

	# ── Engine glow — small colored rect at rear (left side) ──
	var eg := Color(_body_color.r * 1.5, _body_color.g * 1.5, _body_color.b * 1.5, 0.5)
	draw_rect(Rect2(-s - 3, -s * 0.3, 4.0, s * 0.6), eg)
