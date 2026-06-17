extends Node
class_name RoomGridSystem

# ── Inner types ───────────────────────────────────────────────────────────────

class Surface:
	var name : String
	var A    : Vector2
	var B    : Vector2
	var C    : Vector2
	var D    : Vector2
	var cols : int
	var rows : int
	var polygon : PackedVector2Array

# ── State ─────────────────────────────────────────────────────────────────────

var _surfaces : Dictionary = {}   # name → Surface
var _occupied : Dictionary = {}   # "surface:col:row" → Node

signal changed

# ── Setup ─────────────────────────────────────────────────────────────────────

func setup(data: Dictionary) -> void:
	_surfaces.clear()
	_occupied.clear()

	var gz   := data.get("zones", {})  as Dictionary
	var gcfg := data.get("grid",  {})  as Dictionary

	var floor_zone : Array = gz.get("floor", [])
	var wall_zone  : Array = gz.get("wall",  [])

	var fc : int = gcfg.get("floor_cols", 18)
	var fr : int = gcfg.get("floor_rows", 18)
	var wc : int = gcfg.get("wall_cols",  18)
	var wr : int = gcfg.get("wall_rows",  12)

	# floor: zone[0]=back, [1]=left, [2]=front, [3]=right
	if floor_zone.size() >= 4:
		var s := Surface.new()
		s.name = "floor"
		s.A = _v2(floor_zone[0]); s.B = _v2(floor_zone[3])
		s.C = _v2(floor_zone[2]); s.D = _v2(floor_zone[1])
		s.cols = fc;  s.rows = fr
		s.polygon = PackedVector2Array([s.A, s.B, s.C, s.D])
		_surfaces["floor"] = s

	# wall zone: [0]=top-back, [1]=top-right, [2]=bot-right,
	#            [3]=bot-back, [4]=bot-left, [5]=top-left
	if wall_zone.size() >= 6:
		var sr := Surface.new()
		sr.name = "wall_right"
		sr.A = _v2(wall_zone[0]); sr.B = _v2(wall_zone[1])
		sr.C = _v2(wall_zone[2]); sr.D = _v2(wall_zone[3])
		sr.cols = wc; sr.rows = wr
		sr.polygon = PackedVector2Array([sr.A, sr.B, sr.C, sr.D])
		_surfaces["wall_right"] = sr

		var sl := Surface.new()
		sl.name = "wall_left"
		sl.A = _v2(wall_zone[0]); sl.B = _v2(wall_zone[5])
		sl.C = _v2(wall_zone[4]); sl.D = _v2(wall_zone[3])
		sl.cols = wc; sl.rows = wr
		sl.polygon = PackedVector2Array([sl.A, sl.B, sl.C, sl.D])
		_surfaces["wall_left"] = sl

# ── Coordinate conversion ─────────────────────────────────────────────────────

# local_pos is in Room node's local space
func local_to_cell(local_pos: Vector2, preferred_surface: String = "") -> Dictionary:
	# Try preferred surface first (so items near surface edge stay on correct surface)
	var order := _surfaces.keys()
	if preferred_surface != "" and _surfaces.has(preferred_surface):
		order.erase(preferred_surface)
		order.push_front(preferred_surface)

	for sname in order:
		var s : Surface = _surfaces[sname]
		var uv := _inverse_bilerp(s.A, s.B, s.C, s.D, local_pos)
		if uv.x >= -0.05 and uv.x <= 1.05 and uv.y >= -0.05 and uv.y <= 1.05:
			var col := clampi(int(uv.x * s.cols), 0, s.cols - 1)
			var row := clampi(int(uv.y * s.rows), 0, s.rows - 1)
			return {"surface": sname, "col": col, "row": row}
	return {}

# Returns the world center of cell area (w×h cells starting at col, row)
func cell_to_local(surface: String, col: int, row: int, w: int = 1, h: int = 1) -> Vector2:
	if not _surfaces.has(surface): return Vector2.ZERO
	var s : Surface = _surfaces[surface]
	var u := (col + w * 0.5) / s.cols
	var v := (row + h * 0.5) / s.rows
	return _bilerp(s.A, s.B, s.C, s.D, u, v)

# Returns a quad (4 pts) covering the cell area in local space
func cell_quad(surface: String, col: int, row: int, w: int = 1, h: int = 1) -> PackedVector2Array:
	if not _surfaces.has(surface): return PackedVector2Array()
	var s : Surface = _surfaces[surface]
	var u0 := float(col)     / s.cols
	var u1 := float(col + w) / s.cols
	var v0 := float(row)     / s.rows
	var v1 := float(row + h) / s.rows
	return PackedVector2Array([
		_bilerp(s.A, s.B, s.C, s.D, u0, v0),
		_bilerp(s.A, s.B, s.C, s.D, u1, v0),
		_bilerp(s.A, s.B, s.C, s.D, u1, v1),
		_bilerp(s.A, s.B, s.C, s.D, u0, v1),
	])

# Compute best-fit (col, row) for a w×h item whose center is near local_pos
func local_to_cell_topleft(local_pos: Vector2, w: int, h: int, preferred_surface: String = "") -> Dictionary:
	var hit := local_to_cell(local_pos, preferred_surface)
	if hit.is_empty(): return {}
	var surface : String = hit["surface"]
	var s : Surface = _surfaces[surface]
	# Adjust so the item is centered on mouse
	var col : int
	var row : int
	if surface == "floor":
		# free edges at max col and max row → cut 1 cell there
		col = clampi(hit["col"] - w / 2, 0, s.cols - w - 1)
		row = clampi(hit["row"] - h / 2, 0, s.rows - h - 1)
	else:
		# wall: free edge at top (row=0) → cut 1 cell there; bottom naturally bounded
		col = clampi(hit["col"] - w / 2, 0, s.cols - w - 1)
		row = clampi(hit["row"] - h / 2, 1, s.rows - h)
	return {"surface": surface, "col": col, "row": row}

# ── Occupancy ─────────────────────────────────────────────────────────────────

# w=width, d=depth(floor rows), h=height(wall rows)
# Floor items: occupy w×d floor cells; if h>0 and against a wall, also wall cells.
#   row=0 → against wall_right  (wall_right col = floor col)
#   col=0 → against wall_left   (wall_left  col = floor row)
# Wall items (surface≠floor): occupy w×h wall cells.
func can_place(surface: String, col: int, row: int, w: int, d: int, h: int, exclude: Node2D = null) -> bool:
	if not _surfaces.has(surface): return false
	if surface == "floor":
		var s : Surface = _surfaces["floor"]
		for dc in range(w):
			for dr in range(d):
				var c := col + dc;  var r := row + dr
				if c < 0 or c >= s.cols or r < 0 or r >= s.rows: return false
				var occ = _occupied.get(_key("floor", c, r))
				if occ != null and occ != exclude: return false
		if h > 0:
			if row == 0 and _surfaces.has("wall_right"):
				var ws : Surface = _surfaces["wall_right"]
				var wr := ws.rows - h
				if wr < 0: return false
				for dc in range(w):
					for dr in range(h):
						var c := col + dc
						if c < 0 or c >= ws.cols: return false
						var occ = _occupied.get(_key("wall_right", c, wr + dr))
						if occ != null and occ != exclude: return false
			if col == 0 and _surfaces.has("wall_left"):
				var ws : Surface = _surfaces["wall_left"]
				var wr := ws.rows - h
				if wr < 0: return false
				for dc in range(d):
					for dr in range(h):
						var c := row + dc
						if c < 0 or c >= ws.cols: return false
						var occ = _occupied.get(_key("wall_left", c, wr + dr))
						if occ != null and occ != exclude: return false
	else:
		var s : Surface = _surfaces[surface]
		for dc in range(w):
			for dr in range(h):
				var c := col + dc;  var r := row + dr
				if c < 0 or c >= s.cols or r < 0 or r >= s.rows: return false
				var occ = _occupied.get(_key(surface, c, r))
				if occ != null and occ != exclude: return false
	return true

func place_item(item: Node2D, surface: String, col: int, row: int, w: int, d: int, h: int) -> void:
	remove_item(item)
	if surface == "floor":
		for dc in range(w):
			for dr in range(d):
				_occupied[_key("floor", col + dc, row + dr)] = item
		if h > 0:
			if row == 0 and _surfaces.has("wall_right"):
				var ws : Surface = _surfaces["wall_right"]
				var wr := ws.rows - h
				for dc in range(w):
					for dr in range(h):
						_occupied[_key("wall_right", col + dc, wr + dr)] = item
			if col == 0 and _surfaces.has("wall_left"):
				var ws : Surface = _surfaces["wall_left"]
				var wr := ws.rows - h
				for dc in range(d):
					for dr in range(h):
						_occupied[_key("wall_left", row + dc, wr + dr)] = item
		item.position = cell_to_local("floor", col, row, w, d)
	else:
		for dc in range(w):
			for dr in range(h):
				_occupied[_key(surface, col + dc, row + dr)] = item
		item.position = cell_to_local(surface, col, row, w, h)
	if item.has_meta("place_offset"):
		item.position += item.get_meta("place_offset")
	# z-order: floor items closer to viewer (higher row+col) render on top
	if surface == "floor":
		item.z_index = 1 + row + col
	else:
		item.z_index = 0  # wall items same level as grid
	item.set_meta("grid_surface", surface)
	item.set_meta("grid_col",     col)
	item.set_meta("grid_row",     row)
	changed.emit()

func surface_rows(surface: String) -> int:
	if not _surfaces.has(surface): return 0
	return (_surfaces[surface] as Surface).rows

func remove_item(item: Node2D) -> void:
	var to_del : Array = []
	for k in _occupied:
		if _occupied[k] == item: to_del.append(k)
	for k in to_del: _occupied.erase(k)

func get_item_grid(item: Node2D) -> Dictionary:
	if not item.has_meta("grid_surface"): return {}
	return {
		"surface": item.get_meta("grid_surface"),
		"col":     item.get_meta("grid_col"),
		"row":     item.get_meta("grid_row"),
		"w":       item.get_meta("grid_w", 1),
		"d":       item.get_meta("grid_d", 1),
		"h":       item.get_meta("grid_h", 0),
	}

# ── Math helpers ──────────────────────────────────────────────────────────────

func _bilerp(A: Vector2, B: Vector2, C: Vector2, D: Vector2, u: float, v: float) -> Vector2:
	return A.lerp(B, u).lerp(D.lerp(C, u), v)

func _inverse_bilerp(A: Vector2, B: Vector2, C: Vector2, D: Vector2, P: Vector2) -> Vector2:
	# Parallelogram approximation: solve A + E*u + F*v = P
	var E := B - A
	var F := D - A
	var PA := P - A
	var det := E.x * F.y - E.y * F.x
	if abs(det) < 1e-6: return Vector2(-1, -1)
	var u := (PA.x * F.y - PA.y * F.x) / det
	var v := (E.x * PA.y - E.y * PA.x) / det
	return Vector2(u, v)

func _key(surface: String, col: int, row: int) -> String:
	return "%s:%d:%d" % [surface, col, row]

# ── Footprint detection ───────────────────────────────────────────────────────

# Call with item at its JSON pixel position (before place_item).
# Tries Polygon2D first (accurate), falls back to CollisionShape2D AABB.
func footprint_from_collision(item: Node2D, preferred_surface: String = "") -> Dictionary:
	# Primary: Polygon2D — use exact polygon for cell containment test
	var poly_result := _footprint_from_polygon2d(item, preferred_surface)
	if not poly_result.is_empty(): return poly_result

	# Fallback: CollisionShape2D AABB
	var cs := _find_collision_shape(item, Vector2.ZERO)
	if cs.is_empty(): return {}

	var cs_pos  : Vector2 = cs["pos"]
	var cs_size : Vector2 = cs["size"]
	var hw := cs_size.x / 2.0
	var hh := cs_size.y / 2.0

	var room_cs    := item.position + cs_pos
	var center_hit := local_to_cell(room_cs, preferred_surface)
	if center_hit.is_empty(): return {}

	var surface : String = center_hit["surface"]
	var s       : Surface = _surfaces[surface]
	var cx      : int = center_hit["col"]
	var cy      : int = center_hit["row"]

	var min_c := cx; var max_c := cx
	var min_r := cy; var max_r := cy
	var any   := false

	for dc in range(-5, 6):
		for dr in range(-5, 6):
			var col := cx + dc
			var row := cy + dr
			if col < 0 or col >= s.cols or row < 0 or row >= s.rows: continue
			var loc := cell_to_local(surface, col, row) - item.position
			if abs(loc.x - cs_pos.x) <= hw and abs(loc.y - cs_pos.y) <= hh:
				if not any:
					min_c = col; max_c = col; min_r = row; max_r = row; any = true
				else:
					if col < min_c: min_c = col
					if col > max_c: max_c = col
					if row < min_r: min_r = row
					if row > max_r: max_r = row

	if not any: return {}
	return {
		"surface": surface,
		"col": min_c, "row": min_r,
		"w": max(1, max_c - min_c + 1),
		"h": max(1, max_r - min_r + 1),
	}

# Build polygon points in Room local space from a Polygon2D child node.
func polygon2d_room_pts(item: Node2D) -> PackedVector2Array:
	for child in item.get_children():
		if not child is Polygon2D: continue
		var poly := child as Polygon2D
		if poly.polygon.size() < 3: continue
		var xform := poly.get_transform()
		var pts   := PackedVector2Array()
		for p in poly.polygon:
			pts.append(item.position + xform * p)
		return pts
	return PackedVector2Array()

func _footprint_from_polygon2d(item: Node2D, preferred_surface: String = "") -> Dictionary:
	var room_pts := polygon2d_room_pts(item)
	if room_pts.is_empty(): return {}

	# Centroid to find surface
	var centroid := Vector2.ZERO
	for p in room_pts: centroid += p
	centroid /= room_pts.size()

	var center_hit := local_to_cell(centroid, preferred_surface)
	if center_hit.is_empty(): return {}

	var surface : String = center_hit["surface"]
	var s       : Surface = _surfaces[surface]
	var cx      : int = center_hit["col"]
	var cy      : int = center_hit["row"]

	var min_c := cx; var max_c := cx
	var min_r := cy; var max_r := cy
	var any   := false

	for dc in range(-5, 6):
		for dr in range(-5, 6):
			var col := cx + dc
			var row := cy + dr
			if col < 0 or col >= s.cols or row < 0 or row >= s.rows: continue
			if Geometry2D.is_point_in_polygon(cell_to_local(surface, col, row), room_pts):
				if not any:
					min_c = col; max_c = col; min_r = row; max_r = row; any = true
				else:
					if col < min_c: min_c = col
					if col > max_c: max_c = col
					if row < min_r: min_r = row
					if row > max_r: max_r = row

	if not any: return {}
	return {
		"surface": surface,
		"col": min_c, "row": min_r,
		"w": max(1, max_c - min_c + 1),
		"h": max(1, max_r - min_r + 1),
	}

# Walk the subtree to find the first CollisionShape2D, accumulating node offsets.
func _find_collision_shape(node: Node, parent_offset: Vector2) -> Dictionary:
	for child in node.get_children():
		var offset := parent_offset
		if child is Node2D:
			offset = parent_offset + (child as Node2D).position
		if child is CollisionShape2D:
			var cs := child as CollisionShape2D
			if cs.shape is RectangleShape2D:
				return {"pos": offset, "size": (cs.shape as RectangleShape2D).size}
			elif cs.shape is CircleShape2D:
				var r := (cs.shape as CircleShape2D).radius
				return {"pos": offset, "size": Vector2(r * 2.0, r * 2.0)}
		else:
			var sub := _find_collision_shape(child, offset)
			if not sub.is_empty(): return sub
	return {}

func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
