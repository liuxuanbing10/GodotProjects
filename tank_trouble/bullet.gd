extends CharacterBody2D

# ── Bullet types（引用 constants.gd 中的统一枚举）────────────
# Constants.BulletType: NORMAL, BIG_SHOT, FRAG_BOMB, GATLING, HOMING

# ── Constants ──────────────────────────────────────────────
const SPEED := 380.0
const HOMING_SPEED := 300.0
const MAX_BOUNCES := 3
const MAX_LIFETIME := 3.0
const RADIUS := 5.0
const BIG_RADIUS := 10.0
const FRAG_BLAST_RADIUS := 120.0
const HOMING_TURN_RATE := 3.0  # radians/sec
const TRAIL_LENGTH := 6

# ── Public state ───────────────────────────────────────────
var bullet_type := Constants.BulletType.NORMAL
var bounces := 0
var shooter_id := -1

# ── Private state ──────────────────────────────────────────
var _lifetime := 0.0
var _trail: Array[Vector2] = []


# ── Setup ──────────────────────────────────────────────────
func setup(pos: Vector2, dir: Vector2, type: int, s_id: int) -> void:
	bullet_type = type
	shooter_id = s_id
	position = pos
	velocity = dir * SPEED

	# Collision: layer 4 (bullets), mask 1 (walls) + 2 (tanks)
	collision_layer = 4
	collision_mask = 1 | 2

	var r := BIG_RADIUS if type == Constants.BulletType.BIG_SHOT else RADIUS
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = r
	shape.shape = circle
	add_child(shape)

	add_to_group("bullets")


# ── Physics ────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= MAX_LIFETIME:
		queue_free()
		return

	# Store trail
	_trail.append(position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_front()

	# Homing: steer toward nearest target
	if bullet_type == Constants.BulletType.HOMING:
		_apply_homing(delta)

	var collision := move_and_collide(velocity * delta)
	if not collision:
		return

	var collider := collision.get_collider()

	# Frag bomb explodes on anything
	if bullet_type == Constants.BulletType.FRAG_BOMB:
		_frag_explode()
		queue_free()
		return

	# Hit a tank?
	if collider and collider.is_in_group("tanks"):
		if collider.player_id != shooter_id:
			collider.hit()
			queue_free()
			return
		# Self-hit: ignore, keep moving
		return

	# Wall bounce
	bounces += 1
	if bounces > MAX_BOUNCES:
		queue_free()
		return
	velocity = velocity.bounce(collision.get_normal())


func _apply_homing(delta: float) -> void:
	var target: Node = _find_nearest_enemy()
	if not target or not is_instance_valid(target):
		return

	var to_target: Vector2 = target.global_position - global_position
	var desired: Vector2 = to_target.normalized()
	var current_dir := velocity.normalized()

	# Rotate toward target
	var angle_diff := current_dir.angle_to(desired)
	var max_turn := HOMING_TURN_RATE * delta
	var turn := clampf(angle_diff, -max_turn, max_turn)

	var new_dir := current_dir.rotated(turn).normalized()
	velocity = new_dir * HOMING_SPEED
	rotation = new_dir.angle()


func _find_nearest_enemy() -> Node:
	var nearest: Node = null
	var min_dist := INF
	for t in get_tree().get_nodes_in_group("tanks"):
		if not is_instance_valid(t) or t == self or t.player_id == shooter_id:
			continue
		var d := global_position.distance_squared_to(t.global_position)
		if d < min_dist:
			min_dist = d
			nearest = t
	return nearest


func _frag_explode() -> void:
	# Create explosion at current position
	var exp := preload("res://explosion.gd")
	if exp:
		var e := Node2D.new()
		e.set_script(exp)
		e.setup(global_position, FRAG_BLAST_RADIUS * 0.4)
		get_parent().add_child(e)

	# Find tanks in blast radius
	for t in get_tree().get_nodes_in_group("tanks"):
		if not is_instance_valid(t) or t.player_id == shooter_id:
			continue
		if global_position.distance_to(t.global_position) <= FRAG_BLAST_RADIUS:
			t.hit()


# ── Visual ─────────────────────────────────────────────────
func _draw() -> void:
	var r := BIG_RADIUS if bullet_type == Constants.BulletType.BIG_SHOT else RADIUS
	var tc := _get_type_color()

	# ── Trail (existing circles preserved) ──
	for i in _trail.size():
		var t := _trail[i]
		var alpha := float(i) / float(_trail.size()) * 0.4
		var tr := lerpf(1.0, float(r) * 0.3, float(i) / float(_trail.size()))
		draw_circle(t - position, tr, Color(tc.r, tc.g, tc.b, alpha))

	# ── Trail spark dots ──
	for i in _trail.size():
		if i % 2 == 0:
			var t := _trail[i]
			var sx := ((i * 7 + 3) % 5 - 2) * 0.8
			var sy := ((i * 11 + 5) % 7 - 3) * 0.8
			var sa := float(i) / float(_trail.size()) * 0.5
			draw_circle(t - position + Vector2(sx, sy), 1.0, Color(tc.r, tc.g, tc.b, sa))

	# ── Type-specific glow & effects ──
	match bullet_type:
		Constants.BulletType.NORMAL:
			# Two concentric glow rings
			draw_circle(Vector2.ZERO, r * 2.5, Color(tc.r, tc.g, tc.b, 0.15))
			draw_circle(Vector2.ZERO, r * 1.5, Color(tc.r, tc.g, tc.b, 0.35))

		Constants.BulletType.BIG_SHOT:
			# Much larger: 3 concentric rings with strong presence
			var br := r * 1.5
			draw_circle(Vector2.ZERO, br * 2.0, Color(tc.r, tc.g, tc.b, 0.2))
			draw_circle(Vector2.ZERO, br * 1.3, Color(tc.r, tc.g, tc.b, 0.4))
			draw_circle(Vector2.ZERO, br, Color(tc.r, tc.g, tc.b, 0.6))

		Constants.BulletType.FRAG_BOMB:
			# Two glow rings + surrounding spark dots
			draw_circle(Vector2.ZERO, r * 2.5, Color(tc.r, tc.g, tc.b, 0.15))
			draw_circle(Vector2.ZERO, r * 1.5, Color(tc.r, tc.g, tc.b, 0.3))
			var n := 7
			for j in n:
				var a := float(j) / float(n) * TAU
				var o := Vector2(cos(a), sin(a)) * r * 1.8
				draw_circle(o, 1.5, Color(tc.r, tc.g, tc.b, 0.6))

		Constants.BulletType.GATLING:
			# Two glow rings + motion lines for speed feel
			draw_circle(Vector2.ZERO, r * 2.0, Color(tc.r, tc.g, tc.b, 0.2))
			draw_circle(Vector2.ZERO, r * 1.3, Color(tc.r, tc.g, tc.b, 0.4))
			draw_line(Vector2(-r * 0.5, -r - 3), Vector2(-r * 0.5, -r - 1), Color(tc.r, tc.g, tc.b, 0.5), 1.0)
			draw_line(Vector2(-r * 0.5, r + 1), Vector2(-r * 0.5, r + 3), Color(tc.r, tc.g, tc.b, 0.5), 1.0)

		Constants.BulletType.HOMING:
			# Two glow rings + orbiting satellite dot
			draw_circle(Vector2.ZERO, r * 2.5, Color(tc.r, tc.g, tc.b, 0.15))
			draw_circle(Vector2.ZERO, r * 1.5, Color(tc.r, tc.g, tc.b, 0.3))
			var oa := _lifetime * 4.0
			var op := Vector2(cos(oa), sin(oa)) * r * 1.5
			draw_circle(op, 2.0, Color(tc.r, tc.g, tc.b, 0.8))

	# ── Main bullet body ──
	draw_circle(Vector2.ZERO, r, tc)
	draw_circle(Vector2.ZERO, r * 0.4, Color.WHITE)


func _get_type_color() -> Color:
	match bullet_type:
		Constants.BulletType.NORMAL:   return Color(1.0, 0.9, 0.3)   # yellow
		Constants.BulletType.BIG_SHOT: return Color(0.2, 0.5, 1.0)   # blue
		Constants.BulletType.FRAG_BOMB:return Color(1.0, 0.5, 0.1)   # orange
		Constants.BulletType.GATLING:  return Color(1.0, 0.9, 0.3)   # yellow
		Constants.BulletType.HOMING:   return Color(0.2, 1.0, 0.4)   # green
		_:                   return Color(1.0, 0.9, 0.3)
