class_name WorldNavigator
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

static func find_path(from: Vector2i, to: Vector2i, impassable: Array[Vector2i], bounds: Rect2i, road_cells: Array[Vector2i] = [], has_pathfinding: bool = false) -> Array[Vector2i]:
	if not bounds.has_point(from) or not bounds.has_point(to):
		return []
	if impassable.has(to) or from == to:
		return []
		
	var frontier: Array[Vector2i] = [from]
	var came_from: Dictionary = {from: from}
	var cost_so_far: Dictionary = {from: 0}
	
	while frontier.size() > 0:
		# Find lowest cost in frontier
		var current = frontier[0]
		var best_idx = 0
		var best_f = cost_so_far[current] + _heuristic(current, to)
		
		for i in range(1, frontier.size()):
			var node = frontier[i]
			var f = cost_so_far[node] + _heuristic(node, to)
			if f < best_f:
				best_f = f
				current = node
				best_idx = i
				
		frontier.remove_at(best_idx)
		
		if current == to:
			break
			
		for d in DIRECTIONS:
			var nxt = current + d
			if not bounds.has_point(nxt):
				continue
			if impassable.has(nxt) and nxt != to:
				continue
				
			var step_cost = 1
			if road_cells.size() > 0:
				if road_cells.has(nxt):
					step_cost = 1
				else:
					step_cost = 1 if has_pathfinding else 2
			var new_cost = cost_so_far[current] + step_cost
			if not cost_so_far.has(nxt) or new_cost < cost_so_far[nxt]:
				cost_so_far[nxt] = new_cost
				came_from[nxt] = current
				frontier.append(nxt)
				
	if not came_from.has(to):
		return []
		
	# Reconstruct path
	var path: Array[Vector2i] = []
	var curr = to
	while curr != from:
		path.append(curr)
		curr = came_from[curr]
	path.reverse()
	return path

static func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
