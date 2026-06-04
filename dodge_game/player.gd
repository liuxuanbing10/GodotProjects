extends Area2D

const SPEED := 400.0
const SHIP_W := 36.0
const SHIP_H := 28.0

var screen_w := 480.0

func _ready():
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(SHIP_W, SHIP_H)
	shape.shape = rect
	add_child(shape)
	screen_w = get_viewport_rect().size.x

func _process(delta):
	var dir = Input.get_axis("ui_left", "ui_right")
	position.x += dir * SPEED * delta
	position.x = clamp(position.x, SHIP_W / 2 + 10, screen_w - SHIP_W / 2 - 10)

func _draw():
	# Body
	var body := PackedVector2Array([
		Vector2(0, -SHIP_H / 2),
		Vector2(-SHIP_W / 2, SHIP_H / 2),
		Vector2(SHIP_W / 2, SHIP_H / 2),
	])
	draw_colored_polygon(body, Color(0.2, 0.6, 1.0))

	# Cockpit highlight
	var cockpit := PackedVector2Array([
		Vector2(0, -SHIP_H / 4),
		Vector2(-SHIP_W / 5, SHIP_H / 6),
		Vector2(SHIP_W / 5, SHIP_H / 6),
	])
	draw_colored_polygon(cockpit, Color(0.5, 0.8, 1.0))

	# Engine glow
	draw_circle(Vector2(0, SHIP_H / 2 - 2), 4, Color(1.0, 0.7, 0.2))
