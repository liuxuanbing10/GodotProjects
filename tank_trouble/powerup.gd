extends Area2D

# ── Enum ────────────────────────────────────────────────────
enum PowerUpType { BIG_SHOT, LASER, FRAG_BOMB, GATLING, HOMING }

# ── Constants ───────────────────────────────────────────────
const DESPAWN_TIME := 15.0
const FLOAT_AMPLITUDE := 4.0
const FLOAT_SPEED := 3.0

# ── Type Colors ─────────────────────────────────────────────
const _TYPE_COLORS := {
	PowerUpType.BIG_SHOT: Color(0.2, 0.4, 1.0),
	PowerUpType.LASER: Color(1.0, 0.2, 0.2),
	PowerUpType.FRAG_BOMB: Color(1.0, 0.6, 0.1),
	PowerUpType.GATLING: Color(1.0, 0.9, 0.1),
	PowerUpType.HOMING: Color(0.2, 1.0, 0.3),
}

# ── Signals ─────────────────────────────────────────────────
signal collected(tank_node: Node, powerup_type: int)

# ── Public state ────────────────────────────────────────────
var powerup_type: int

# ── Private state ───────────────────────────────────────────
var _lifetime := 0.0
var _base_y: float


# ── Setup ───────────────────────────────────────────────────
func setup(type: int, pos: Vector2) -> void:
	powerup_type = type
	position = pos
	_base_y = pos.y

	# Collision: layer 0 (no emission), mask 2 (detects tanks)
	collision_layer = 0
	collision_mask = 2

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)
	add_to_group("powerups")


# ── Lifecycle ──────────────────────────────────────────────
func _process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= DESPAWN_TIME:
		queue_free()
		return

	# Floating bob animation
	position.y = _base_y + sin(_lifetime * FLOAT_SPEED) * FLOAT_AMPLITUDE
	queue_redraw()


# ── Visual ─────────────────────────────────────────────────
func _draw() -> void:
	var col: Color = _TYPE_COLORS.get(powerup_type, Color.WHITE)
	var center := Vector2.ZERO
	var r := 16.0

	# Glow ring
	draw_circle(center, 22.0, Color(col.r, col.g, col.b, 0.3))

	# Background filled circle
	draw_circle(center, r, col)

	# Type-specific icon
	match powerup_type:
		PowerUpType.BIG_SHOT:
			_draw_big_shot_icon(center)
		PowerUpType.LASER:
			_draw_laser_icon(center)
		PowerUpType.FRAG_BOMB:
			_draw_frag_bomb_icon(center)
		PowerUpType.GATLING:
			_draw_gatling_icon(center)
		PowerUpType.HOMING:
			_draw_homing_icon(center)


func _draw_big_shot_icon(c: Vector2) -> void:
	# Two concentric white circles (unfilled)
	draw_circle(c, 8.0, Color.WHITE, false, 2.0)
	draw_circle(c, 4.0, Color.WHITE, false, 2.0)


func _draw_laser_icon(c: Vector2) -> void:
	# Diagonal line with arrow tip
	var p1 := c + Vector2(-5, 5)
	var p2 := c + Vector2(5, -5)
	draw_line(p1, p2, Color.WHITE, 2.0)
	# Arrow tip
	var tip := p2
	var left := tip + Vector2(2.0, 2.0).rotated(PI * 1.25)
	var right := tip + Vector2(2.0, 2.0).rotated(-PI * 1.25)
	draw_line(tip, left, Color.WHITE, 2.0)
	draw_line(tip, right, Color.WHITE, 2.0)


func _draw_frag_bomb_icon(c: Vector2) -> void:
	# Small filled center circle with 4 short rays
	draw_circle(c, 3.0, Color.WHITE)
	var ray_len := 5.0
	for i in range(4):
		var angle := float(i) * PI / 2.0
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(c + dir * 4.0, c + dir * (4.0 + ray_len), Color.WHITE, 1.5)


func _draw_gatling_icon(c: Vector2) -> void:
	# Three short horizontal bars (parallel lines)
	var bar_len := 8.0
	for i in range(3):
		var y_off := float(i - 1) * 4.0
		draw_line(c + Vector2(-bar_len / 2.0, y_off), c + Vector2(bar_len / 2.0, y_off), Color.WHITE, 2.0)


func _draw_homing_icon(c: Vector2) -> void:
	# Curved arc with arrow
	draw_arc(c, 7.0, deg_to_rad(30), deg_to_rad(150), 8, Color.WHITE, 2.0)
	# Arrow at the end of arc
	var tip := c + Vector2(cos(deg_to_rad(150)), sin(deg_to_rad(150))) * 7.0
	var left := tip + Vector2(2.5, 2.5).rotated(deg_to_rad(150) + PI * 0.8)
	var right := tip + Vector2(2.5, 2.5).rotated(deg_to_rad(150) - PI * 0.8)
	draw_line(tip, left, Color.WHITE, 2.0)
	draw_line(tip, right, Color.WHITE, 2.0)


# ── Collision ──────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("tanks"):
		collected.emit(body, powerup_type)
		queue_free()
