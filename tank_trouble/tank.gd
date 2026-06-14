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

# 使用 constants.gd 中统一的枚举
# var PowerUp := Constants.PowerUp  # GDScript 4 支持 type alias，但兼容性考虑直接用 Constants.PowerUp

# ── Public state ───────────────────────────────────────────
var player_id := 0
var tank_type: int = Constants.TankType.BALANCED
var _speed_mult: float = 1.0  # 速度倍率（坦克类型+领先优势）
var current_powerup := Constants.PowerUp.NONE

# AI control — set by AI controller
var is_ai := false
var ai_move_dir := Vector2.ZERO
var ai_wants_shoot := false

# ── Private state ──────────────────────────────────────────
var _facing := Vector2.UP
var _cooldown: float = 0.0  # 射击冷却倒计时（秒），0 表示可以射击

# Gatling burst
var _gatling_shots_remaining := 0
var _gatling_timer: float = 0.0  # 格林机枪间隔倒计时

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
		ai: bool = false,
		tank_type: int = Constants.TankType.BALANCED,
		speed_mult: float = 1.0) -> void:
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
	self.tank_type = tank_type
	_speed_mult = speed_mult
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


func set_tank_type(t: int) -> void:
	tank_type = t

func set_speed_mult(m: float) -> void:
	_speed_mult = m


# 不再需要 tree_exiting 清理 Timer 了（已改用浮点倒计时）


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return

	# ── 冷却倒计时 ──
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_cooldown = 0.0

	# ── Gatling 间隔倒计时 ──
	if _gatling_shots_remaining > 0:
		_gatling_timer -= delta
		if _gatling_timer <= 0.0:
			_on_gatling_tick()

	# 8-directional free movement (no rotation-based steering)
	var move_dir := Vector2.ZERO
	if is_ai:
		move_dir = ai_move_dir
	else:
		move_dir = Vector2(
			Input.get_axis(_action_left, _action_right),
			Input.get_axis(_action_up, _action_down)
		)

	# Normalize diagonal so it isn't faster
	if move_dir.length_squared() > 1.0:
		move_dir = move_dir.normalized()

	# Update facing direction (for bullet spawn) and visual rotation
	if move_dir.length_squared() > 0.001:
		_facing = move_dir.normalized()
		# Smooth visual rotation to face movement direction
		var target_angle := _facing.angle()
		rotation = lerp_angle(rotation, target_angle, 12.0 * delta)

	# Move with smooth acceleration / deceleration
	var target_vel := move_dir * SPEED * Constants.TANK_TYPE_PROPS[tank_type].speed * _speed_mult
	if move_dir.length_squared() < 0.001:
		velocity = velocity.lerp(Vector2.ZERO, 12.0 * delta)
	else:
		velocity = velocity.lerp(target_vel, 10.0 * delta)
	move_and_slide()

	# Shooting
	if _wants_to_shoot() and _cooldown <= 0.0:
		if is_ai:
			ai_wants_shoot = false  # Consume the one-shot signal
		_shoot()


func _wants_to_shoot() -> bool:
	if is_ai:
		return ai_wants_shoot
	return Input.is_action_just_pressed(_action_shoot)


# ── Shooting ───────────────────────────────────────────────
func _shoot() -> void:
	var spawn_pos := global_position + _facing * BARREL_OFFSET
	var pu := current_powerup
	current_powerup = Constants.PowerUp.NONE
	shoot_requested.emit(spawn_pos, _facing, player_id, pu)

	# Handle gatling burst
	if pu == Constants.PowerUp.GATLING:
		_gatling_shots_remaining = GATLING_SHOTS - 1
		_gatling_timer = GATLING_INTERVAL
		# 第一发已在 shoot_requested.emit 中发出
	else:
		_cooldown = SHOOT_COOLDOWN * Constants.TANK_TYPE_PROPS[tank_type].cooldown


func _on_gatling_tick() -> void:
	if not is_instance_valid(self):
		return
	_gatling_shots_remaining -= 1
	shoot_requested.emit(global_position + _facing * BARREL_OFFSET, _facing, player_id, Constants.PowerUp.GATLING)

	if _gatling_shots_remaining > 0:
		_gatling_timer = GATLING_INTERVAL
	else:
		_cooldown = SHOOT_COOLDOWN * Constants.TANK_TYPE_PROPS[tank_type].cooldown


# ── Damage ─────────────────────────────────────────────────
func hit(bullet_type: int = -1) -> void:
	# bullet_type: 击杀来源的子弹类型（用于成就系统）
	died.emit(player_id, bullet_type)
	queue_free()


# ── Power-up ───────────────────────────────────────────────
func apply_powerup(type: int) -> void:
	if current_powerup != Constants.PowerUp.NONE:
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
	draw_colored_polygon(pts, Constants.TANK_TYPE_PROPS[tank_type].color)

	# ── Barrel (wider, with highlight and muzzle ring) ──
	var barrel_len := s + 10.0
	var bw := 4.0
	# Main barrel body (10px wide: -5 to +5)
	draw_rect(Rect2(0, -bw, barrel_len - s * 0.3, bw * 2.0), Constants.TANK_TYPE_PROPS[tank_type].color)
	# Barrel highlight — thin lighter stripe along top edge
	var hl := Color(Constants.TANK_TYPE_PROPS[tank_type].color.r * 1.3, Constants.TANK_TYPE_PROPS[tank_type].color.g * 1.3, Constants.TANK_TYPE_PROPS[tank_type].color.b * 1.3, 0.6)
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
	var eg := Color(Constants.TANK_TYPE_PROPS[tank_type].color.r * 1.5, Constants.TANK_TYPE_PROPS[tank_type].color.g * 1.5, Constants.TANK_TYPE_PROPS[tank_type].color.b * 1.5, 0.5)
	draw_rect(Rect2(-s - 3, -s * 0.3, 4.0, s * 0.6), eg)
