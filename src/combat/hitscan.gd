class_name Hitscan
extends RefCounted


static func walls_to(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array) -> Dictionary:
	var dir := (to - from).normalized()
	var dist := from.distance_to(to)
	var pos := from
	var walls := 0
	var remain := dist
	for _i in 5:
		if remain < 0.05:
			return {"walls": walls, "reached": true}
		var q := PhysicsRayQueryParameters3D.create(pos, pos + dir * remain)
		q.collision_mask = 1
		q.exclude = exclude
		var h := space.intersect_ray(q)
		if h.is_empty():
			return {"walls": walls, "reached": true}
		var hitp: Vector3 = h.position
		if hitp.distance_to(to) <= 0.14:
			return {"walls": walls, "reached": true}
		walls += 1
		if walls > 2:
			return {"walls": walls, "reached": false}
		var step := 0.09
		pos = hitp + dir * step
		remain = pos.distance_to(to)
	return {"walls": walls, "reached": walls <= 2}


static func ray_sphere(from: Vector3, to: Vector3, center: Vector3, radius: float) -> float:
	var d := to - from
	var f := from - center
	var a := d.dot(d)
	var b := 2.0 * f.dot(d)
	var c := f.dot(f) - radius * radius
	var disc := b * b - 4.0 * a * c
	if disc < 0.0 or a == 0.0:
		return -1.0
	var s := sqrt(disc)
	var t0 := (-b - s) / (2.0 * a)
	var t1 := (-b + s) / (2.0 * a)
	var t := t0 if t0 >= 0.0 and t0 <= 1.0 else t1
	if t < 0.0 or t > 1.0:
		return -1.0
	return t


static func closest_hitbox(from: Vector3, to: Vector3, boxes: Array) -> Dictionary:
	var best_t := 1.1
	var best := {}
	for h in boxes:
		var t := ray_sphere(from, to, h.pos, h.radius)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = h
			best["t"] = t
			best["hit"] = from.lerp(to, t)
	return best
