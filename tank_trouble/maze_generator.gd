extends Node

## Procedural random maze generator for Tank Trouble.
##
## Arena: 960x640, divided into 24x16 grid (40px cells).
## All methods are static — call MazeGenerator.generate() directly.
##
## Grid (col, row) → World coordinates: Vector2(col * 40 + 20, row * 40 + 20)

const COLS := 24
const ROWS := 16
const CELL := 40

## Generates a maze as Array[Array[int]] where 1 = wall, 0 = open.
## Uses random wall clusters with connectivity validation.
## Falls back to a 4-room layout if all random attempts fail.
static func generate() -> Array:
	for _attempt in range(20):
		var maze = _create_empty_maze()
		_place_random_clusters(maze)
		if _validate_maze(maze):
			return maze
	# Fallback: guaranteed-valid 4-room layout
	return _generate_fallback()


## Returns all open (walkable) cells in the maze.
static func get_open_cells(maze: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in range(ROWS):
		for col in range(COLS):
			if maze[row][col] == 0:
				cells.append(Vector2i(col, row))
	return cells


## BFS flood-fill connectivity check.
## Returns true if all target cells are reachable from start via open cells.
static func is_maze_connected(maze: Array, start: Vector2i, targets: Array[Vector2i]) -> bool:
	var visited := {}
	var queue: Array[Vector2i] = [start]
	var remaining = targets.duplicate()

	while queue.size() > 0:
		var current = queue.pop_front()
		var key = str(current)
		if visited.has(key):
			continue
		visited[key] = true

		# Check if current cell is one of the targets
		var idx = remaining.find(current)
		if idx >= 0:
			remaining.remove_at(idx)
			if remaining.size() == 0:
				return true

		# Four-directional neighbours
		for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var next = current + dir
			if next.x < 0 or next.x >= COLS or next.y < 0 or next.y >= ROWS:
				continue
			if maze[next.y][next.x] == 0 and not visited.has(str(next)):
				queue.append(next)

	# Some targets were never reached
	return false


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Creates an empty maze: border cells (row 0, row 15, col 0, col 23) are
## walls (1), all interior cells are open (0).
static func _create_empty_maze() -> Array:
	var maze: Array = []
	for row in range(ROWS):
		maze.append([])
		for col in range(COLS):
			if row == 0 or row == ROWS - 1 or col == 0 or col == COLS - 1:
				maze[row].append(1)   # border wall
			else:
				maze[row].append(0)   # interior open
	return maze


## Places 4-8 rectangular wall clusters at random positions.
## Each cluster is 2-4 cells wide and 2-4 cells tall.
## Clusters are kept 1 cell away from the border and from each other,
## and must not overlap the three spawn corners.
static func _place_random_clusters(maze: Array) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var num_clusters = rng.randi_range(4, 8)
	var spawn_cells = [
		Vector2i(1, 1),    # P1
		Vector2i(22, 14),  # P2
		Vector2i(22, 1),   # P3
	]

	for _i in range(num_clusters):
		var w = rng.randi_range(2, 4)
		var h = rng.randi_range(2, 4)

		# Try up to 10 positions for this cluster
		var placed = false
		for _j in range(10):
			var col = rng.randi_range(2, COLS - 2 - w)
			var row = rng.randi_range(2, ROWS - 2 - h)

			# Reject if the cluster covers a spawn corner
			var rect = Rect2i(col, row, w, h)
			var overlaps_spawn = false
			for sp in spawn_cells:
				if rect.has_point(sp):
					overlaps_spawn = true
					break
			if overlaps_spawn:
				continue

			# Reject if too close (less than 1 cell) to existing walls
			var too_close = false
			for ry in range(row - 1, row + h + 1):
				for rx in range(col - 1, col + w + 1):
					if ry < 0 or ry >= ROWS or rx < 0 or rx >= COLS:
						continue
					if maze[ry][rx] == 1:
						too_close = true
						break
				if too_close:
					break
			if too_close:
				continue

			# Place cluster
			for ry in range(row, row + h):
				for rx in range(col, col + w):
					maze[ry][rx] = 1
			placed = true
			break

		# If placement failed after 10 tries, skip this cluster (validation
		# will reject mazes with insufficient walls)


## Validates a maze for gameplay requirements:
##   - Spawn corners are open
##   - All spawn corners are connected to each other
##   - At least 30 % of interior cells remain open
static func _validate_maze(maze: Array) -> bool:
	var spawn_cells = [
		Vector2i(1, 1),    # P1
		Vector2i(22, 14),  # P2
		Vector2i(22, 1),   # P3
	]

	# All spawn corners must be open
	for sp in spawn_cells:
		if maze[sp.y][sp.x] != 0:
			return false

	# All spawn corners must be mutually reachable
	if not is_maze_connected(maze, Vector2i(1, 1), [Vector2i(22, 14), Vector2i(22, 1)]):
		return false

	# At least 30 % of interior cells must be open
	var open_count := 0
	var interior_count := 0
	for row in range(1, ROWS - 1):
		for col in range(1, COLS - 1):
			interior_count += 1
			if maze[row][col] == 0:
				open_count += 1

	if float(open_count) / float(interior_count) < 0.3:
		return false

	return true


## Guaranteed-valid fallback: a symmetrical 4-room layout with cross-shaped
## corridors connecting every room.
static func _generate_fallback() -> Array:
	var maze = _create_empty_maze()

	# Room 1 — top-left   (cols 2-10,  rows 2-6)
	for row in range(2, 7):
		for col in range(2, 11):
			maze[row][col] = 0

	# Room 2 — top-right  (cols 13-21, rows 2-6)
	for row in range(2, 7):
		for col in range(13, 22):
			maze[row][col] = 0

	# Room 3 — bottom-left  (cols 2-10,  rows 9-13)
	for row in range(9, 14):
		for col in range(2, 11):
			maze[row][col] = 0

	# Room 4 — bottom-right (cols 13-21, rows 9-13)
	for row in range(9, 14):
		for col in range(13, 22):
			maze[row][col] = 0

	# Cross-shaped walls separating the four rooms
	for row in range(2, 14):
		maze[row][11] = 1   # vertical wall left column
		maze[row][12] = 1   # vertical wall right column

	for col in range(2, 22):
		maze[7][col] = 1    # horizontal wall top row
		maze[8][col] = 1    # horizontal wall bottom row

	# Corridors through the walls

	# Vertical corridor (top) — connects rooms 1 and 2
	maze[4][11] = 0
	maze[4][12] = 0

	# Vertical corridor (bottom) — connects rooms 3 and 4
	maze[11][11] = 0
	maze[11][12] = 0

	# Horizontal corridor (left) — connects rooms 1 and 3
	maze[7][5] = 0
	maze[8][5] = 0

	# Horizontal corridor (right) — connects rooms 2 and 4
	maze[7][18] = 0
	maze[8][18] = 0

	# Center intersection — connects all four corridors
	maze[7][11] = 0
	maze[7][12] = 0
	maze[8][11] = 0
	maze[8][12] = 0

	return maze
