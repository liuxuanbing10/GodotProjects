extends Node2D

var score := 0
var game_over := false
var started := false

var player: Area2D
var score_label: Label
var game_over_label: Label
var start_label: Label
var spawn_timer: Timer
var bg_stars: Array

const PLAYER_SCRIPT := preload("res://player.gd")
const ROCK_SCRIPT := preload("res://rock.gd")

func _ready():
	_create_background()
	_create_player()
	_create_ui()
	_create_timer()

func _process(delta):
	if game_over and Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()

func _input(event):
	if event.is_action_pressed("ui_accept") and not game_over and not started:
		start_game()

# ---------- Background ----------

func _create_background():
	for i in 80:
		var star = Vector2(
			randf_range(0, get_viewport_rect().size.x),
			randf_range(0, get_viewport_rect().size.y)
		)
		bg_stars.append([star, randf() * 0.5 + 0.5])

func _draw():
	# Sky
	var rect = get_viewport_rect()
	draw_rect(rect, Color(0.04, 0.04, 0.1))
	# Stars
	for s in bg_stars:
		var pos = s[0] as Vector2
		var b = s[1] as float
		draw_circle(pos, 1.0 + b * 0.5, Color(b, b, b * 0.9))

# ---------- Player ----------

func _create_player():
	player = Area2D.new()
	player.set_script(PLAYER_SCRIPT)
	var screen = get_viewport_rect().size
	player.position = Vector2(screen.x / 2, screen.y - 60)
	add_child(player)
	player.area_entered.connect(_on_player_hit)

# ---------- UI ----------

func _create_ui():
	var ui = CanvasLayer.new()
	add_child(ui)

	var screen = get_viewport_rect().size

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.position = Vector2(12, 8)
	score_label.text = "得分: 0"
	ui.add_child(score_label)

	start_label = Label.new()
	start_label.add_theme_font_size_override("font_size", 28)
	start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_label.position = Vector2(screen.x / 2 - 90, screen.y / 2 - 20)
	start_label.text = "按 空格 开始"
	ui.add_child(start_label)

	game_over_label = Label.new()
	game_over_label.add_theme_font_size_override("font_size", 32)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.position = Vector2(screen.x / 2 - 120, screen.y / 2 - 40)
	game_over_label.text = "游戏结束\n按 空格 重新开始"
	game_over_label.visible = false
	ui.add_child(game_over_label)

func _create_timer():
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 1.2
	spawn_timer.one_shot = false
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timeout)

# ---------- Game Flow ----------

func start_game():
	started = true
	start_label.visible = false
	spawn_timer.start()

func spawn_rock():
	var rock = Area2D.new()
	rock.set_script(ROCK_SCRIPT)
	var screen = get_viewport_rect().size
	rock.position = Vector2(randf_range(30, screen.x - 30), -30)
	add_child(rock)
	rock.missed.connect(_on_rock_missed)

func _on_spawn_timeout():
	if not game_over:
		spawn_rock()

func _on_rock_missed():
	score += 1
	score_label.text = "得分: " + str(score)
	if score % 5 == 0 and spawn_timer.wait_time > 0.3:
		spawn_timer.wait_time = max(0.3, spawn_timer.wait_time - 0.08)

func _on_player_hit(_area: Area2D):
	if game_over:
		return
	game_over = true
	spawn_timer.stop()
	game_over_label.visible = true
	for child in get_children():
		if child is Area2D and child != player:
			child.set_process(false)
