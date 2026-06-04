extends Camera3D

var time := 0.0

func _process(delta):
	time += delta * 0.4
	position.x = sin(time) * 7.0
	position.z = cos(time) * 7.0
	look_at(Vector3.ZERO)
