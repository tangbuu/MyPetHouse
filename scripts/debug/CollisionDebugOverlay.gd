extends Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var shapes := get_tree().root.find_children("*", "CollisionShape2D", true, false)
	for node in shapes:
		var cs := node as CollisionShape2D
		if cs == null or cs.shape == null or not cs.is_inside_tree():
			continue
		var gt  := cs.global_transform
		var pos := to_local(gt.origin)
		var rot := gt.get_rotation()

		if cs.shape is RectangleShape2D:
			var half := (cs.shape as RectangleShape2D).size * 0.5
			var corners := PackedVector2Array([
				Vector2(-half.x, -half.y).rotated(rot) + pos,
				Vector2( half.x, -half.y).rotated(rot) + pos,
				Vector2( half.x,  half.y).rotated(rot) + pos,
				Vector2(-half.x,  half.y).rotated(rot) + pos,
			])
			draw_colored_polygon(corners, Color(0.0, 1.0, 0.2, 0.18))
			draw_polyline(PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]),
				Color(0.0, 1.0, 0.2, 0.9), 1.5)

		elif cs.shape is CircleShape2D:
			var r := (cs.shape as CircleShape2D).radius
			draw_circle(pos, r, Color(0.0, 1.0, 0.2, 0.18))
			draw_arc(pos, r, 0.0, TAU, 32, Color(0.0, 1.0, 0.2, 0.9), 1.5)

		elif cs.shape is CapsuleShape2D:
			var cap  := cs.shape as CapsuleShape2D
			var h    := cap.height * 0.5 - cap.radius
			var pts  := PackedVector2Array()
			for a in range(0, 181, 10):
				pts.append((Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * cap.radius
					+ Vector2(0, -h)).rotated(rot) + pos)
			for a in range(180, 361, 10):
				pts.append((Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * cap.radius
					+ Vector2(0,  h)).rotated(rot) + pos)
			draw_colored_polygon(pts, Color(0.0, 1.0, 0.2, 0.18))
			draw_polyline(PackedVector2Array(pts) + PackedVector2Array([pts[0]]),
				Color(0.0, 1.0, 0.2, 0.9), 1.5)
