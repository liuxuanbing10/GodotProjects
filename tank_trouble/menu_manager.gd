extends Control

## Pause / Options overlay for Tank Trouble.
##
## Attached as a child of main. Toggled via Escape during PLAYING state.
## Runs while the scene tree is paused (PROCESS_MODE_ALWAYS).

# ── Signals ──────────────────────────────────────────────────
signal resume_pressed()
signal sound_toggled(on: bool)
signal quit_pressed()

# ── State ────────────────────────────────────────────────────
var selected := 0
var visible_state := false
var sound_on := true

const OPTIONS := ["Resume", "Sound", "Quit to Menu"]


# ── Lifecycle ───────────────────────────────────────────────
func _ready() -> void:
	# Fill the viewport
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = MOUSE_FILTER_IGNORE
	hide()
	process_mode = PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func show_menu(sound: bool) -> void:
	sound_on = sound
	visible_state = true
	selected = 0
	show()
	queue_redraw()


func hide_menu() -> void:
	visible_state = false
	hide()


# ── Input ───────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not visible_state:
		return

	if event.is_action_pressed("ui_pause"):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()
		return

	# Mouse click on option buttons
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mp: Vector2 = event.position
		for i in OPTIONS.size():
			var r := Rect2(Constants.ARENA_W / 2.0 - 120, 280 + i * 65, 240, 48)
			if r.has_point(mp):
				get_viewport().set_input_as_handled()
				_execute_option(i)
				return
		return

	# Keyboard navigation
	if event.is_action_pressed("ui_up"):
		selected = maxi(selected - 1, 0)
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		selected = mini(selected + 1, OPTIONS.size() - 1)
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_execute_option(selected)


func _execute_option(index: int) -> void:
	match index:
		0:
			resume_pressed.emit()
		1:
			sound_on = not sound_on
			sound_toggled.emit(sound_on)
			queue_redraw()
		2:
			quit_pressed.emit()


# ── Visual ──────────────────────────────────────────────────
func _draw() -> void:
	if not visible_state:
		return

	# Semi-transparent backdrop
	draw_rect(Rect2(0, 0, Constants.ARENA_W, Constants.ARENA_H), Color(0, 0, 0, 0.65))

	var f := ThemeDB.fallback_font
	var fs := ThemeDB.fallback_font_size

	# ── Title ──
	draw_string(f, Vector2(Constants.ARENA_W / 2.0 - 90, 180),
			"PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, fs * 2,
			Color(1.0, 0.85, 0.2))

	# ── Buttons ──
	for i in OPTIONS.size():
		var y := 280 + i * 65
		var r := Rect2(Constants.ARENA_W / 2.0 - 120, y, 240, 48)

		var hover := i == selected
		var bg := Color(0.35, 0.35, 0.42) if hover else Color(0.2, 0.2, 0.26)
		draw_rect(r, bg)
		draw_rect(r, Color(0.5, 0.5, 0.55), false, 2.0)

		var label: String = OPTIONS[i]
		if i == 1:
			label = "Sound: ON" if sound_on else "Sound: OFF"

		draw_string(f, Vector2(r.position.x + 20, r.position.y + 33),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

	# ── 5. Controls hint with shadow ──
	var hint := "WASD/Arrows to navigate  |  Enter to select  |  ESC to close"
	var hint_pos := Vector2(Constants.ARENA_W / 2.0 - 120, 530)
	draw_string(f, hint_pos + Vector2(1, 1), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0, 0, 0, 0.4))
	draw_string(f, hint_pos, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.5, 0.5))


# ── Helpers ──────────────────────────────────────────────────
static func _rounded_rect_points(rect: Rect2, r: float, seg: int = 6) -> PackedVector2Array:
	"""Return a closed polygon approximating a rounded rectangle."""
	var pts := PackedVector2Array()
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y

	# Top-right corner arc (270° → 0°)
	for i in range(seg + 1):
		var a := PI * 1.5 + PI * 0.5 * i / seg
		pts.append(Vector2(x + w - r + cos(a) * r, y + r + sin(a) * r))

	# Bottom-right corner arc (0° → 90°)
	for i in range(seg + 1):
		var a := PI * 0.5 * i / seg
		pts.append(Vector2(x + w - r + cos(a) * r, y + h - r + sin(a) * r))

	# Bottom-left corner arc (90° → 180°)
	for i in range(seg + 1):
		var a := PI * 0.5 + PI * 0.5 * i / seg
		pts.append(Vector2(x + r + cos(a) * r, y + h - r + sin(a) * r))

	# Top-left corner arc (180° → 270°)
	for i in range(seg + 1):
		var a := PI + PI * 0.5 * i / seg
		pts.append(Vector2(x + r + cos(a) * r, y + r + sin(a) * r))

	return pts
