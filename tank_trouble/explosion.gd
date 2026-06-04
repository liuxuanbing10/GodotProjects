extends Node2D

const DURATION := 0.4
var elapsed := 0.0
var max_radius := 40.0


func setup(pos: Vector2, radius: float = 40.0) -> void:
	global_position = pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	max_radius = radius


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var progress := elapsed / DURATION

	# Outer circle — shockwave (red fading to dark red, transparent at end)
	var outer_r := max_radius * progress
	var outer_color := Color.RED.lerp(Color(0.5, 0, 0), progress)
	outer_color.a = lerp(0.8, 0.0, progress)
	draw_circle(Vector2.ZERO, outer_r, outer_color)

	# Middle circle — fire (orange → red, slowly fading)
	var mid_r := max_radius * 0.6 * progress
	var mid_color := Color.ORANGE.lerp(Color.RED, progress)
	mid_color.a = lerp(1.0, 0.4, progress)
	draw_circle(Vector2.ZERO, mid_r, mid_color)

	# Center flash — core (yellow → orange, fades out fast)
	var core_r := max_radius * 0.3 * progress
	var core_color := Color.YELLOW.lerp(Color.ORANGE, progress)
	core_color.a = lerp(1.0, 0.0, progress)
	draw_circle(Vector2.ZERO, core_r, core_color)

	# Debris — 4 deterministic lines radiating outward
	var debris_angles := [0.0, PI * 0.5, PI, PI * 1.5]
	for i in 4:
		var angle: float = debris_angles[i] + progress * 2.0 + i * 0.5
		var length := max_radius * 1.5 * progress
		var end := Vector2(cos(angle), sin(angle)) * length
		var debris_color := Color(1.0, 0.5, 0.0)
		debris_color.a = lerp(1.0, 0.0, progress)
		draw_line(Vector2.ZERO, end, debris_color, 2.0)
