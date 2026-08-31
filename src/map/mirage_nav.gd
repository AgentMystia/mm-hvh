class_name MirageNav
extends RefCounted
## CS:GO de_mirage.nav (v16) graph. Bots A* on area centers.

var areas: Array = []
var by_id: Dictionary = {}
var loaded := false


func load_file(path := "res://assets/maps/de_mirage/nav.json") -> void:
	loaded = false
	areas.clear()
	by_id.clear()
	_load_shards()
	if areas.is_empty() and FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var j = JSON.parse_string(f.get_as_text())
			if typeof(j) == TYPE_DICTIONARY:
				areas = j.get("areas", [])
	if areas.is_empty():
		push_warning("nav.json missing")
		return
	for i in areas.size():
		by_id[int(areas[i].id)] = i
	loaded = areas.size() > 0
	print("MirageNav areas=%d" % areas.size())


func _load_shards() -> void:
	var man_path := "res://assets/maps/de_mirage/nav_manifest.json"
	if not FileAccess.file_exists(man_path):
		return
	var mf := FileAccess.open(man_path, FileAccess.READ)
	if mf == null:
		return
	var man = JSON.parse_string(mf.get_as_text())
	if typeof(man) != TYPE_DICTIONARY:
		return
	var n := int(man.get("shards", 0))
	var collected: Array = []
	for i in n:
		var sp := "res://assets/maps/de_mirage/nav_%02d.json" % i
		if not FileAccess.file_exists(sp):
			return
		var sf := FileAccess.open(sp, FileAccess.READ)
		if sf == null:
			return
		var part = JSON.parse_string(sf.get_as_text())
		if typeof(part) != TYPE_DICTIONARY:
			return
		collected.append_array(part.get("areas", []))
	if collected.size() > 0:
		areas = collected


func area_index_at(pos: Vector3) -> int:
	var best := -1
	var best_d := 1e9
	for i in areas.size():
		var a: Dictionary = areas[i]
		var mn: Array = a.min
		var mx: Array = a.max
		if pos.x < float(mn[0]) - 0.4 or pos.x > float(mx[0]) + 0.4:
			continue
		if pos.z < float(mn[1]) - 0.4 or pos.z > float(mx[1]) + 0.4:
			continue
		var cy := float(a.y)
		var dy := absf(pos.y - cy)
		if dy < best_d:
			best_d = dy
			best = i
	if best >= 0:
		return best
	return nearest_index(pos)


func nearest_index(pos: Vector3) -> int:
	var best := -1
	var bd := 1e9
	for i in areas.size():
		var c: Array = areas[i].c
		var d := Vector3(float(c[0]), float(c[1]), float(c[2])).distance_squared_to(pos)
		if d < bd:
			bd = d
			best = i
	return best


func _center(i: int) -> Vector3:
	var c: Array = areas[i].c
	return Vector3(float(c[0]), float(c[1]), float(c[2]))


func path(from_pos: Vector3, to_pos: Vector3) -> Array:
	if not loaded or areas.is_empty():
		return [to_pos]
	var s := area_index_at(from_pos)
	var g := area_index_at(to_pos)
	if s < 0 or g < 0:
		return [to_pos]
	if s == g:
		return [to_pos]
	var came: Dictionary = {}
	var gscore: Dictionary = {s: 0.0}
	var open: Array = [s]
	var in_open: Dictionary = {s: true}
	var goal_c := _center(g)
	var guard := 0
	while not open.is_empty() and guard < 5000:
		guard += 1
		var bi := 0
		var bf := 1e9
		for k in open.size():
			var idx: int = open[k]
			var f := float(gscore.get(idx, 1e9)) + _center(idx).distance_to(goal_c)
			if f < bf:
				bf = f
				bi = k
		var cur: int = open[bi]
		open.remove_at(bi)
		in_open.erase(cur)
		if cur == g:
			break
		var a: Dictionary = areas[cur]
		for nid in a.n:
			if not by_id.has(int(nid)):
				continue
			var nb: int = by_id[int(nid)]
			var tg := float(gscore[cur]) + _center(cur).distance_to(_center(nb))
			if tg < float(gscore.get(nb, 1e9)):
				came[nb] = cur
				gscore[nb] = tg
				if not in_open.has(nb):
					open.append(nb)
					in_open[nb] = true
	if not came.has(g) and s != g:
		return [_center(g), to_pos]
	var chain: Array = []
	var x := g
	var hops := 0
	while x != s and hops < 256:
		chain.append(_center(x))
		if not came.has(x):
			break
		x = int(came[x])
		hops += 1
	chain.reverse()
	chain.append(to_pos)
	return chain
