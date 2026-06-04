extends Area2D

signal missed

var speed := 250.0
var radius := 15.0

func _ready():
	radius = randf_range(8.0, 22.0)
	speed = randf_range(200.0, 380.0)

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)

func _process(delta):
	position.y += speed * delta
	if position.y > get_viewport_rect().size.y + radius + 20:
		missed.emit()
		queue_free()

func _draw():
	# Main rock body
	draw_circle(Vector2.ZERO, radius, Color(0.6, 0.25, 0.15))
	# Darker patch
	draw_circle(Vector2(-radius * 0.2, -radius * 0.3), radius * 0.35, Color(0.45, 0.18, 0.1))
	# Highlight
	draw_circle(Vector2(radius * 0.15, -radius * 0.4), radius * 0.15, Color(0.7, 0.4, 0.25))
