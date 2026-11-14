extends RefCounted
class_name GridNavigator

const CARDINAL_DIRS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP,
]

var board: Board
var occupancy: Dictionary


func configure(board_ref: Board, occupancy_ref: Dictionary) -> void:
	board = board_ref
	occupancy = occupancy_ref


func cell_walkable_for(cell: Vector2i, mover: Unit) -> bool:
	if board == null or mover == null or board.is_blocked(cell):
		return false
	if not occupancy.has(cell):
		return true

	var occupant: Unit = occupancy[cell]
	if occupant == mover:
		return true
	return not occupant.blocks_movement_for(mover.faction)


func reachable_from(mover: Unit) -> Dictionary:
	var start: Vector2i = mover.cell
	var max_distance: int = mover.move_range
	var distances: Dictionary = {start: 0}
	var previous: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	var queue_index: int = 0

	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		var distance: int = distances[current]

		for direction in CARDINAL_DIRS:
			var next: Vector2i = current + direction
			if not board.in_bounds(next) or distances.has(next):
				continue
			var next_distance: int = distance + 1
			if next_distance > max_distance or not cell_walkable_for(next, mover):
				continue
			distances[next] = next_distance
			previous[next] = current
			queue.append(next)

	return {"dist": distances, "prev": previous}


func reachable_destinations(mover: Unit) -> Dictionary:
	var result: Dictionary = reachable_from(mover)
	var distances: Dictionary = result["dist"]
	var destinations: Array[Vector2i] = []

	for value in distances.keys():
		var cell: Vector2i = value
		if cell == mover.cell or occupancy.has(cell):
			continue
		destinations.append(cell)

	return {"dests": destinations, "prev": result["prev"]}


func reconstruct_path(previous: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if goal == start or not previous.has(goal):
		return path

	var current: Vector2i = goal
	while current != start:
		path.push_front(current)
		current = previous[current]
	return path


func shortest_path(mover: Unit, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if mover == null or board == null or start == goal:
		return empty

	var from_start: Dictionary = _distances_from(mover, start)
	if not from_start.has(goal):
		return empty
	var from_goal: Dictionary = _distances_from(mover, goal)
	if not from_goal.has(start):
		return empty

	var shortest_length: int = int(from_start[goal])
	var memo: Dictionary = {}
	var best: Dictionary = _best_shortest_path_step(
		mover,
		start,
		goal,
		Vector2i.ZERO,
		from_start,
		from_goal,
		shortest_length,
		memo
	)
	if best.is_empty():
		return empty
	return best["path"]


func _distances_from(mover: Unit, origin: Vector2i) -> Dictionary:
	var distances: Dictionary = {origin: 0}
	if mover == null or board == null:
		return {}

	var queue: Array[Vector2i] = [origin]
	var queue_index: int = 0
	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		var distance: int = int(distances[current])

		for direction in CARDINAL_DIRS:
			var next: Vector2i = current + direction
			if not board.in_bounds(next) or distances.has(next):
				continue
			if not cell_walkable_for(next, mover):
				continue
			distances[next] = distance + 1
			queue.append(next)

	return distances


func _best_shortest_path_step(
	mover: Unit,
	current: Vector2i,
	goal: Vector2i,
	last_direction: Vector2i,
	from_start: Dictionary,
	from_goal: Dictionary,
	shortest_length: int,
	memo: Dictionary
) -> Dictionary:
	if current == goal:
		return {"turns": 0, "path": []}

	var key: String = "%d,%d|%d,%d" % [current.x, current.y, last_direction.x, last_direction.y]
	if memo.has(key):
		return memo[key]

	# Preserve the prototype's cursor-path preference: among equally short
	# routes, choose the route with the most corners.
	var best_turns: int = -1_000_000
	var best_path: Array[Vector2i] = []
	var current_distance: int = int(from_start[current])

	for direction in CARDINAL_DIRS:
		var next: Vector2i = current + direction
		if not board.in_bounds(next):
			continue
		if not from_start.has(next) or not from_goal.has(next):
			continue
		if int(from_start[next]) != current_distance + 1:
			continue
		if int(from_start[next]) + int(from_goal[next]) != shortest_length:
			continue
		if not cell_walkable_for(next, mover):
			continue

		var child: Dictionary = _best_shortest_path_step(
			mover,
			next,
			goal,
			direction,
			from_start,
			from_goal,
			shortest_length,
			memo
		)
		if child.is_empty():
			continue

		var turns: int = int(child["turns"])
		if last_direction != Vector2i.ZERO and direction != last_direction:
			turns += 1
		if turns <= best_turns:
			continue

		best_turns = turns
		var candidate: Array[Vector2i] = [next]
		for step in child["path"]:
			candidate.append(step)
		best_path = candidate

	if best_turns < -999_999:
		memo[key] = {}
		return {}

	var result: Dictionary = {"turns": best_turns, "path": best_path}
	memo[key] = result
	return result
