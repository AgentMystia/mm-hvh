class_name Hitscan
extends RefCounted
## CS:GO-style traces. Autowall follows 2018 FireBullet / HandleBulletPenetration:
## TraceToExit up to 90 HU, lost damage from thickness² / 24 and weapon flPenetration.

const MAX_PENS := 4
const EXIT_STEP_HU := 4.0
const EXIT_MAX_HU := 90.0

const SURF := {
	"wood": 0.70,
	"glass": 0.99,
	"metal": 0.40,
	"brick": 0.48,
	"plaster": 0.80,
	"sand": 0.55,
	"concrete": 0.45,
	"tile": 0.70,
	"fabric": 0.80,
	"green": 0.60,
	"trim": 0.65,
	"marble": 0.50,
	"market": 0.70,
	"default": 0.80,
	"grate": 0.95,
}


static func _surf_mod(hit: Dictionary) -> float:
	var col = hit.get("collider")
	var name := "plaster"
	if col is Node and (col as Node).has_meta("surf"):
		name = str((col as Node).get_meta("surf"))
	return float(SURF.get(name, SURF["plaster"]))


static func trace_to_exit(space: PhysicsDirectSpaceState3D, enter: Vector3, dir: Vector3, exclude: Array) -> Dictionary:
	# Public 2018 autowall TraceToExit: walk 4 HU at a time (max 90 HU), then
	# trace back from the probe to the enter point. The first surface sitting
	# next to the probe is the far face of the brush.
	var maxd := Net.hu(EXIT_MAX_HU)
	var step := Net.hu(EXIT_STEP_HU)
	var dist := 0.0
	while dist < maxd - 0.001:
		dist += step
		var probe := enter + dir * dist
		var q := PhysicsRayQueryParameters3D.create(probe, enter)
		q.collision_mask = 1
		q.exclude = exclude
		q.hit_from_inside = true
		q.hit_back_faces = true
		var h := space.intersect_ray(q)
		if h.is_empty():
			continue
		var to_probe: float = probe.distance_to(h.position)
		var thick: float = enter.distance_to(h.position)
		if to_probe <= step * 1.85 and thick >= Net.hu(1.2) and thick <= maxd + 0.02:
			return {"ok": true, "pos": h.position, "thickness": thick, "hit": h}
	return {"ok": false, "pos": enter, "thickness": maxd, "hit": {}}


static func line_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array, local := false) -> bool:
	if space == null or not Perf.take_ray(local):
		return false
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.exclude = exclude
	q.hit_from_inside = true
	q.hit_back_faces = true
	var h := space.intersect_ray(q)
	if h.is_empty():
		return true
	return h.position.distance_to(to) <= 0.18


static func fire_bullet(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array, pen_power: float, start_dmg: float) -> Dictionary:
	var dir := (to - from)
	var span := dir.length()
	if span < 0.01:
		return {"dmg": 0, "walls": 0, "reached": false, "thick": []}
	dir /= span
	var pos := from
	var remain := span
	var dmg := start_dmg
	var walls := 0
	var thicks: Array = []
	var hits_left := MAX_PENS
	while hits_left > 0 and dmg >= 1.0:
		if remain < 0.04:
			return {"dmg": dmg, "walls": walls, "reached": true, "thick": thicks}
		var q := PhysicsRayQueryParameters3D.create(pos, pos + dir * remain)
		q.collision_mask = 1
		q.exclude = exclude
		q.hit_from_inside = true
		q.hit_back_faces = true
		var h := space.intersect_ray(q)
		if h.is_empty():
			return {"dmg": dmg, "walls": walls, "reached": true, "thick": thicks}
		var hitp: Vector3 = h.position
		if hitp.distance_to(to) <= 0.16:
			return {"dmg": dmg, "walls": walls, "reached": true, "thick": thicks}
		# Entered a wall. Need an exit within 90 HU or this is a solid.
		var ex := trace_to_exit(space, hitp, dir, exclude)
		if not bool(ex.ok):
			thicks.append(-snappedf(float(ex.thickness) / Net.HU, 0.1))
			return {"dmg": 0, "walls": walls + 1, "reached": false, "thick": thicks}
		var thick_hu: float = float(ex.thickness) / Net.HU
		if thick_hu < 0.5:
			thick_hu = 0.5
		thicks.append(snappedf(thick_hu, 0.1))
		var modifier: float = 1.0 / maxf(_surf_mod(h), 0.05)
		# 2018 HandleBulletPenetration lost-damage (Source inches).
		var pen := maxf(pen_power, 0.05)
		var lost := dmg * 0.16 + (thick_hu * thick_hu * modifier) / 24.0 + modifier * 3.0 * maxf(0.0, (3.0 / pen) * 1.25)
		dmg -= lost
		walls += 1
		if dmg < 1.0:
			return {"dmg": 0, "walls": walls, "reached": false, "thick": thicks}
		pos = Vector3(ex.pos) + dir * Net.hu(1.0)
		remain = pos.distance_to(to)
		hits_left -= 1
	if pos.distance_to(to) < 0.2:
		return {"dmg": dmg, "walls": walls, "reached": true, "thick": thicks}
	return {"dmg": 0, "walls": walls, "reached": false, "thick": thicks}


static func walls_to(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array) -> Dictionary:
	var r := fire_bullet(space, from, to, exclude, 2.0, 100.0)
	return {"walls": r.walls, "reached": r.reached}


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
