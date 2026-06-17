extends Node2D

const LINE_COLOR_FLOOR := Color(0.0, 0.95, 1.0, 0.85)
const LINE_COLOR_WALL  := Color(0.0, 0.95, 1.0, 0.65)
const LINE_WIDTH       := 1.5
const COLOR_VALID      := Color(0.0, 1.0, 0.2, 0.45)
const COLOR_INVALID    := Color(1.0, 0.15, 0.0, 0.45)
const COLOR_HL_BORDER  := Color(1.0, 1.0, 1.0, 0.85)

var _surfaces : Array = []

# Highlight state — set via set_highlight / clear_highlight
var _hl_quads   : Array = []
var _hl_valid   : bool  = true
var _hl_active  : bool  = false

# ── Setup ─────────────────────────────────────────────────────────────────────

func setup(room_data: Dictionary) -> void:
	_surfaces.clear()
	var gz   := room_data.get("zones", {}) as Dictionary
	var gcfg := room_data.get("grid",  {}) as Dictionary

	var floor_zone : Array = gz.get("floor", [])
	var wall_zone  : Array = gz.get("wall",  [])

	var fc : int = gcfg.get("floor_cols", 6)
	var fr : int = gcfg.get("floor_rows", 6)
	var wc : int = gcfg.get("wall_cols",  6)
	var wr : int = gcfg.get("wall_rows",  4)

	if floor_zone.size() >= 4:
		_surfaces.append({
			"A": _v2(floor_zone[0]), "B": _v2(floor_zone[3]),
			"C": _v2(floor_zone[2]), "D": _v2(floor_zone[1]),
			"cols": fc, "rows": fr, "color": LINE_COLOR_FLOOR,
			"skip_col_end": true, "skip_row_end": true
		})

	if wall_zone.size() >= 6:
		_surfaces.append({
			"A": _v2(wall_zone[0]), "B": _v2(wall_zone[1]),
			"C": _v2(wall_zone[2]), "D": _v2(wall_zone[3]),
			"cols": wc, "rows": wr, "color": LINE_COLOR_WALL,
			"skip_col_end": true, "skip_row_start": true
		})
		_surfaces.append({
			"A": _v2(wall_zone[0]), "B": _v2(wall_zone[5]),
			"C": _v2(wall_zone[4]), "D": _v2(wall_zone[3]),
			"cols": wc, "rows": wr, "color": LINE_COLOR_WALL,
			"skip_col_end": true, "skip_row_start": true
		})

	queue_redraw()

# ── Highlight API ─────────────────────────────────────────────────────────────

func set_highlight(quads, valid: bool) -> void:
	if quads is PackedVector2Array:
		_hl_quads = [quads]
	else:
		_hl_quads = quads
	_hl_valid  = valid
	_hl_active = _hl_quads.size() > 0
	queue_redraw()

func clear_highlight() -> void:
	_hl_active = false
	queue_redraw()

# ── Draw ──────────────────────────────────────────────────────────────────────

func _draw() -> void:
	for s in _surfaces:
		var A    : Vector2 = s["A"];  var B    : Vector2 = s["B"]
		var C    : Vector2 = s["C"];  var D    : Vector2 = s["D"]
		var cols : int     = s["cols"]; var rows : int   = s["rows"]
		var col  : Color   = s["color"]

		var skip_cs : bool = s.get("skip_col_start", false)
		var skip_ce : bool = s.get("skip_col_end",   false)
		var skip_rs : bool = s.get("skip_row_start", false)
		var skip_re : bool = s.get("skip_row_end",   false)

		var u0 := 1.0/cols           if skip_cs else 0.0
		var u1 := float(cols-1)/cols if skip_ce else 1.0
		var v0 := 1.0/rows           if skip_rs else 0.0
		var v1 := float(rows-1)/rows if skip_re else 1.0

		var c_from := 1        if skip_cs else 0
		var c_to   := cols - 1 if skip_ce else cols
		for i in range(c_from, c_to + 1):
			var u := float(i) / cols
			draw_line(_bilerp(A,B,C,D, u,v0), _bilerp(A,B,C,D, u,v1), col, LINE_WIDTH)

		var r_from := 1        if skip_rs else 0
		var r_to   := rows - 1 if skip_re else rows
		for j in range(r_from, r_to + 1):
			var v := float(j) / rows
			draw_line(_bilerp(A,B,C,D, u0,v), _bilerp(A,B,C,D, u1,v), col, LINE_WIDTH)

	if _hl_active:
		var fill := COLOR_VALID if _hl_valid else COLOR_INVALID
		for q in _hl_quads:
			if q.size() < 3: continue
			draw_colored_polygon(q, fill)
			for i in q.size():
				draw_line(q[i], q[(i + 1) % q.size()], COLOR_HL_BORDER, 2.0)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _bilerp(A: Vector2, B: Vector2, C: Vector2, D: Vector2, u: float, v: float) -> Vector2:
	return A.lerp(B, u).lerp(D.lerp(C, u), v)

func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
