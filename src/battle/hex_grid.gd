class_name HexGrid
extends RefCounted

# Axial coordinates (q, r)
# Using flat-topped or pointy-topped hexes. For a landscape 1920x1080 battlefield,
# pointy-topped hexes give a classic HoMM3 / King's Bounty perspective:
# X = size * sqrt(3) * (q + r/2.0)
# Y = size * 3/2.0 * r

const SQRT_3 := 1.7320508075688772

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

static func hex_to_pixel(q: int, r: int, size: float, origin: Vector2) -> Vector2:
	var x := size * SQRT_3 * (float(q) + float(r) / 2.0)
	var y := size * 1.5 * float(r)
	return origin + Vector2(x, y)

static func pixel_to_hex(point: Vector2, size: float, origin: Vector2) -> Vector2i:
	var pt := point - origin
	var q := (SQRT_3 / 3.0 * pt.x - 1.0 / 3.0 * pt.y) / size
	var r := (2.0 / 3.0 * pt.y) / size
	return axial_round(q, r)

static func axial_round(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundi(q)
	var rr := roundi(r)
	var rs := roundi(s)
	
	var q_diff := absf(float(rq) - q)
	var r_diff := absf(float(rr) - r)
	var s_diff := absf(float(rs) - s)
	
	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	return Vector2i(rq, rr)

static func distance(a: Vector2i, b: Vector2i) -> int:
	return (absi(a.x - b.x) + absi(a.x + a.y - b.x - b.y) + absi(a.y - b.y)) / 2

static func get_neighbors(hex: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in DIRECTIONS:
		result.append(hex + d)
	return result

static func get_reachable_hexes(start: Vector2i, max_steps: int, obstacles: Array[Vector2i], field_bounds: Rect2i) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	var visited: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_cost = visited[current]
		if current != start and not reachable.has(current):
			reachable.append(current)
			
		if current_cost >= max_steps:
			continue
			
		for next_hex in get_neighbors(current):
			if not is_in_bounds(next_hex, field_bounds):
				continue
			if obstacles.has(next_hex):
				continue
			var next_cost = current_cost + 1
			if not visited.has(next_hex) or next_cost < visited[next_hex]:
				visited[next_hex] = next_cost
				queue.append(next_hex)
				
	return reachable

## Поле — прямоугольник, как в HoMM3: нечётные ряды сдвинуты на полгекса
## вправо («odd-r»). Раньше границы задавались прямо в осевых координатах, и поле
## было параллелограммом: строй шёл по диагонали, углы экрана пустовали.
## Бой считает в осевых (q, r); данные и раскладки задают клетку как (колонка, ряд).
static func offset_to_axial(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x - (cell.y - (cell.y & 1)) / 2, cell.y)

static func axial_to_offset(hex: Vector2i) -> Vector2i:
	return Vector2i(hex.x + (hex.y - (hex.y & 1)) / 2, hex.y)

static func offsets_to_axial(cells: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for c in cells:
		result.append(offset_to_axial(c))
	return result

## Все клетки поля (в осевых координатах), ряд за рядом.
static func field_cells(bounds: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(bounds.position.y, bounds.end.y):
		for col in range(bounds.position.x, bounds.end.x):
			result.append(offset_to_axial(Vector2i(col, row)))
	return result

## bounds — прямоугольник в (колонка, ряд).
static func is_in_bounds(hex: Vector2i, bounds: Rect2i) -> bool:
	return bounds.has_point(axial_to_offset(hex))

static func get_hex_points(center: Vector2, size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle_deg := 60.0 * i - 30.0
		var angle_rad := deg_to_rad(angle_deg)
		points.append(center + Vector2(cos(angle_rad), sin(angle_rad)) * size)
	return points
