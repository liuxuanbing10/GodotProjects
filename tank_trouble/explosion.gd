extends Node2D

const DURATION := 0.4
var elapsed := 0.0
var max_radius := 40.0

# Pre-generated random values for sparks and debris
var _spark_angles: Array = []
var _spark_lengths: Array = []
var _debris_offsets: Array = []


func setup(pos: Vector2, radius: float = 40.0) -> void:
	global_position = pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	max_radius = radius
	# Pre-generate spark and debris variations for this explosion
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	_spark_angles = []
	_spark_lengths = []
	_debris_offsets = []
	for i in 8:
		_spark_angles.append(rng.randf_range(0.0, PI * 2.0))
		_spark_lengths.append(rng.randf_range(0.6, 1.6))
		_debris_offsets.append(rng.randf_range(-0.2, 0.2))


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var progress := elapsed / DURATION

	# ── 1. Glow (very large, very faint — drawn first = behind everything) ──
	var glow_r := max_radius * 1.8 * sqrt(progress)
	var glow_color := Color(1.0, 0.5, 0.15, 0.12 * (1.0 - progress))
	draw_circle(Vector2.ZERO, glow_r, glow_color)

	# ── 2. Hitflash (initial bright white flash at progress < 0.1) ──
	if progress < 0.1:
		var flash_alpha := 1.0 - progress / 0.1
		var flash_r := max_radius * 0.9
		draw_circle(Vector2.ZERO, flash_r, Color(1.0, 1.0, 1.0, flash_alpha * 0.8))

	# ── 3. Outer circle — shockwave (red fading to dark red, transparent at end) ──
	var outer_r := max_radius * progress
	var outer_color := Color.RED.lerp(Color(0.5, 0, 0), progress)
	outer_color.a = lerp(0.8, 0.0, progress)
	draw_circle(Vector2.ZERO, outer_r, outer_color)

	# ── 4. Smoke ring (new — gray, expands slower than shockwave) ──
	var smoke_r := max_radius * 0.78 * pow(progress, 0.85)
	var smoke_color := Color(0.4, 0.4, 0.4, lerp(0.45, 0.0, pow(progress, 0.6)))
	draw_circle(Vector2.ZERO, smoke_r, smoke_color)

	# ── 5. Middle circle — fire (orange → red, slowly fading) ──
	var mid_r := max_radius * 0.6 * progress
	var mid_color := Color.ORANGE.lerp(Color.RED, progress)
	mid_color.a = lerp(1.0, 0.4, progress)
	draw_circle(Vector2.ZERO, mid_r, mid_color)

	# ── 6. Center flash — core (enhanced: brighter/larger initially, shrinks after 30%) ──
	var core_r: float
	if progress < 0.3:
		core_r = max_radius * 0.45 * (progress / 0.3)
	else:
		core_r = lerp(max_radius * 0.45, max_radius * 0.1, (progress - 0.3) / 0.7)
	var core_color := Color(1.0, 1.0, 0.8).lerp(Color.ORANGE, progress * 0.5)
	core_color.a = lerp(1.0, 0.0, pow(progress, 1.5))
	draw_circle(Vector2.ZERO, core_r, core_color)

	# ── 7. Debris — 8 lines radiating outward (was 4) ──
	var base_angles := [0.0, PI * 0.5, PI, PI * 1.5]
	# Map the 8 debris lines to 4 cardinal + 4 diagonal directions with small offsets
	var dirs := [
		base_angles[0], base_angles[0] + PI * 0.25,
		base_angles[1], base_angles[1] + PI * 0.25,
		base_angles[2], base_angles[2] + PI * 0.25,
		base_angles[3], base_angles[3] + PI * 0.25,
	]
	for i in 8:
		var offset := 0.0 if _debris_offsets.is_empty() else _debris_offsets[i]
		var angle: float = dirs[i] + offset + progress * 2.0
		var length_factor := 0.7 if i % 2 == 0 else 1.0  # alternate short / long
		var length := max_radius * 1.5 * progress * length_factor
		var end := Vector2(cos(angle), sin(angle)) * length
		var debris_color := Color(1.0, 0.6, 0.1)
		debris_color.a = lerp(1.0, 0.0, progress)
		draw_line(Vector2.ZERO, end, debris_color, 1.5 if i % 2 == 0 else 2.5)

	# ── 8. Sparks / Embers (new — small bright dots flying further than debris) ──
	var spark_count := _spark_angles.size()
	if spark_count <= 0:
		spark_count = 7  # fallback if setup not called yet
	for i in spark_count:
		var angle: float
		var lf: float
		if i < _spark_angles.size():
			angle = _spark_angles[i]
			lf = _spark_lengths[i]
		else:
			angle = PI * 2.0 * i / spark_count
			lf = 0.8 + (i % 3) * 0.2
		var dist := max_radius * 2.2 * progress * lf
		var pos := Vector2(cos(angle), sin(angle)) * dist
		var spark_color := Color(1.0, 0.95, 0.6)
		spark_color.a = lerp(1.0, 0.0, pow(progress, 0.5))
		draw_circle(pos, 1.0 + lf * 0.5, spark_color)
