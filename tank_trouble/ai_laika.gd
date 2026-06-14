extends Node

## Laika AI Controller
##
## Attached as a child of a Tank node. Sets host_tank.ai_move_dir,
## host_tank.ai_wants_shoot each physics frame.
##
## Uses A* pathfinding on the 24x16 maze grid and predictive shooting.
## Features: strafing at close range, power-up seeking, predictive pathfinding.

# ── Constants ──────────────────────────────────────────────
const PATH_RECALC := 0.5          # seconds between A* recalculations
const SHOOT_ANGLE_TOLERANCE := deg_to_rad(20.0)
const BULLET_SPEED := 380.0
const WAYPOINT_RADIUS := 20.0
const STUCK_TIMEOUT := 0.5

# ── AI behaviour tuning ───────────────────────────────────
const STRAFE_DIST := 200.0        # Within this distance, strafe instead of pathfind
const POWERUP_SEEK_DIST := 250.0  # Max distance to go out of way for a power-up
const PREDICTION_TIME := 0.8      # Seconds ahead for pathfinding prediction

# ── State ──────────────────────────────────────────────────
var difficulty: int = Constants.Difficulty.NORMAL
var host_tank: Node
var maze_grid: Array = []

var _path: Array[Vector2i] = []
var _path_idx := 0
var _recalc_timer := 0.0
var _reaction_timer := 0.0
var _stuck_timer := 0.0
var _last_pos := Vector2.ZERO
var _wander_dir := Vector2.DOWN
var _rng := RandomNumberGenerator.new()


# ── Setup ──────────────────────────────────────────────────
func setup(tank: Node, maze: Array) -> void:
	host_tank = tank
	maze_grid = maze
	if tank:
		_last_pos = tank.global_position
	_rng.randomize()


func set_difficulty(d: int) -> void:
	difficulty = d


func get_difficulty() -> int:
	return difficulty


# ── Per-frame logic ────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not host_tank or not is_instance_valid(host_tank):
		return

	_recalc_timer += delta
	_reaction_timer += delta

	var nearest: Node = _find_nearest_enemy()
	var dist_to_enemy := INF
	if nearest:
		dist_to_enemy = host_tank.global_position.distance_to(nearest.global_position)

	# ── Determine pathfinding target ──
	var target := _get_pathfinding_target(nearest)

	# ── Pathfinding ──
	if _recalc_timer >= PATH_RECALC and target != null:
		_recalc_timer = 0.0
		var start := _world_to_grid(host_tank.global_position)
		var end := _clamp_grid(_world_to_grid(target))
		_path = _astar(start, end)
		_path_idx = 0

	# ── Movement ──
	var move_dir := Vector2.ZERO

	# Priority 1: Strafe when close to enemy
	if nearest and dist_to_enemy < STRAFE_DIST:
		var to_enemy: Vector2 = nearest.global_position - host_tank.global_position
		if to_enemy.length_squared() > 0.001:
			var perp := Vector2(-to_enemy.y, to_enemy.x).normalized()
			# Pick strafe direction that doesn't face a wall
			if not _is_blocked(_world_to_grid(host_tank.global_position + perp * Constants.CELL * 0.6)):
				move_dir = perp.rotated(_rng.randf_range(-Constants.AI_ACCURACY[difficulty], Constants.AI_ACCURACY[difficulty]))
			elif not _is_blocked(_world_to_grid(host_tank.global_position - perp * Constants.CELL * 0.6)):
				move_dir = (-perp).rotated(_rng.randf_range(-Constants.AI_ACCURACY[difficulty], Constants.AI_ACCURACY[difficulty]))

	# Priority 2: Follow A* path
	if move_dir.length_squared() < 0.001 and _path_idx < _path.size():
		var target_wp := _grid_to_world(_path[_path_idx])
		if host_tank.global_position.distance_to(target_wp) < WAYPOINT_RADIUS:
			_path_idx += 1
		if _path_idx < _path.size():
			target_wp = _grid_to_world(_path[_path_idx])
			move_dir = (target_wp - host_tank.global_position).normalized()

	# Priority 3: Stuck recovery / wander
	if move_dir.length_squared() < 0.001:
		var dist: float = host_tank.global_position.distance_to(_last_pos)
		if dist < 5.0:
			_stuck_timer += delta
			if _stuck_timer >= STUCK_TIMEOUT:
				_wander_dir = _smart_wander_dir()
				_stuck_timer = 0.0
		else:
			_stuck_timer = 0.0
		move_dir = _wander_dir

	# Track position every frame
	_last_pos = host_tank.global_position

	# Pass desired movement direction directly to tank
	if move_dir.length_squared() > 0.001:
		host_tank.ai_move_dir = move_dir.normalized()
	else:
		host_tank.ai_move_dir = Vector2.ZERO

	# ── Shooting ──
	if nearest and _should_shoot(nearest, dist_to_enemy):
		host_tank.ai_wants_shoot = true
		_reaction_timer = 0.0


# ── Shooting decision ─────────────────────────────────────
func _should_shoot(nearest: Node, dist: float) -> bool:
	# Scale reaction time by distance — faster reactions when close
	var dist_factor := clampf(dist / 500.0, 0.3, 1.0)
	var reaction := Constants.AI_REACTION_DELAY[difficulty] * dist_factor
	if _reaction_timer < reaction:
		return false

	var to_enemy: Vector2 = nearest.global_position - host_tank.global_position
	var target_pos: Vector2 = nearest.global_position

	# Simple prediction (enemy velocity * travel time)
	if nearest.has_method(&"get_velocity"):
		var enemy_vel: Vector2 = nearest.velocity
		var travel_time: float = dist / BULLET_SPEED
		target_pos += enemy_vel * travel_time

	var predicted_dir: Vector2 = (target_pos - host_tank.global_position).normalized()
	var facing_dir: Vector2 = Vector2.RIGHT.rotated(host_tank.rotation)

	# Apply accuracy deviation so Laika isn't perfectly accurate
	var effective_facing := facing_dir.rotated(_rng.randf_range(-Constants.AI_ACCURACY[difficulty], Constants.AI_ACCURACY[difficulty]))
	var angle_diff: float = absf(effective_facing.angle_to(predicted_dir))

	return angle_diff < SHOOT_ANGLE_TOLERANCE


# ── Pathfinding target selection ──────────────────────────
func _get_pathfinding_target(nearest: Node) -> Vector2:
	# Priority: nearby power-up over default pathfinding
	if nearest:
		var pu := _find_nearby_powerup()
		if pu != null:
			return pu.global_position

		# Default: predicted enemy position
		var predicted: Vector2 = nearest.global_position
		if nearest.has_method(&"get_velocity"):
			predicted += nearest.velocity * PREDICTION_TIME * Constants.AI_PURSUIT_IMMEDIACY[difficulty]
		return predicted

	# Fallback: offset from current position
	return host_tank.global_position + Vector2.RIGHT * 100.0


# ── Power-up detection ────────────────────────────────────
func _find_nearby_powerup() -> Node:
	# Find power-ups through the scene tree
	var root: Node = host_tank.get_tree().current_scene
	if not root:
		return null
	var container := root.get_node_or_null("Powerups")
	if not container or container.get_child_count() == 0:
		return null

	var nearest: Node = null
	var min_d_sq: float = POWERUP_SEEK_DIST * POWERUP_SEEK_DIST
	for pu in container.get_children():
		if not is_instance_valid(pu):
			continue
		var d_sq: float = host_tank.global_position.distance_squared_to(pu.global_position)
		if d_sq < min_d_sq:
			min_d_sq = d_sq
			nearest = pu

	return nearest


# ── Smarter stuck recovery ────────────────────────────────
func _smart_wander_dir() -> Vector2:
	# Try each cardinal direction — pick the first that isn't blocked
	var dirs := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	dirs.shuffle()
	for d in dirs:
		var next_cell := _world_to_grid(host_tank.global_position + d * Constants.CELL)
		if not _is_blocked(next_cell):
			return d
	return Vector2.DOWN


# ── Grid helper ───────────────────────────────────────────
func _is_blocked(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return true
	return maze_grid[cell.y][cell.x] == 1


static func _clamp_grid(cell: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, Constants.GRID_COLS - 1), clampi(cell.y, 0, Constants.GRID_ROWS - 1))


# ── Enemy detection ────────────────────────────────────────
func _find_nearest_enemy() -> Node:
	var nearest: Node = null
	var min_d: float = INF
	for t in get_tree().get_nodes_in_group("tanks"):
		if not is_instance_valid(t) or t == host_tank or t.player_id == host_tank.player_id:
			continue
		var d: float = host_tank.global_position.distance_squared_to(t.global_position)
		if d < min_d:
			min_d = d
			nearest = t
	return nearest


# ── Coordinate helpers ─────────────────────────────────────
static func _world_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / Constants.CELL), int(pos.y / Constants.CELL))


static func _grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * Constants.CELL + Constants.CELL / 2.0, cell.y * Constants.CELL + Constants.CELL / 2.0)


# ── A* pathfinding ─────────────────────────────────────────
func _astar(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	if not _in_bounds(start) or not _in_bounds(end):
		return []
	if maze_grid.is_empty():
		return [end]

	var open_set: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {_keyi(start): 0.0}
	var f_score: Dictionary = {_keyi(start): _heuristic(start, end)}

	while open_set.size() > 0:
		var best_idx: int = 0
		var best_f: float = f_score.get(_keyi(open_set[0]), INF)
		for i in range(1, open_set.size()):
			var f: float = f_score.get(_keyi(open_set[i]), INF)
			if f < best_f:
				best_f = f
				best_idx = i

		var current := open_set[best_idx]
		open_set.remove_at(best_idx)
		var ckey := _keyi(current)

		if current == end:
			var p: Array[Vector2i] = []
			var node := current
			while node != start:
				p.push_front(node)
				node = came_from.get(_keyi(node), start)
			return p

		for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var nb: Vector2i = current + dir
			if not _in_bounds(nb):
				continue
			if maze_grid[nb.y][nb.x] == 1:
				continue

			var nkey: int = _keyi(nb)
			var tent_g: float = g_score.get(ckey, INF) + 1.0
			if tent_g < g_score.get(nkey, INF):
				came_from[nkey] = current
				g_score[nkey] = tent_g
				f_score[nkey] = tent_g + _heuristic(nb, end)
				if not _in_list(open_set, nb):
					open_set.append(nb)

	return []


# ── A* helpers ─────────────────────────────────────────────
static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(abs(a.x - b.x) + abs(a.y - b.y))


static func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < Constants.GRID_COLS and c.y >= 0 and c.y < Constants.GRID_ROWS


static func _keyi(c: Vector2i) -> int:
	return c.y * Constants.GRID_COLS + c.x


static func _in_list(list: Array[Vector2i], c: Vector2i) -> bool:
	for item in list:
		if item == c:
			return true
	return false


# ── Random direction ───────────────────────────────────────
func _random_dir() -> Vector2:
	var dirs := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	return dirs[_rng.randi() % dirs.size()]
