class_name Resolver
extends RefCounted
## 2018-flavour resolver: last-moving LBY, standing LBY, breaker detection, bruteforce, delta.

enum Mode { LBY, BRUTE, DELTA, HYBRID }

class Rec:
	var last_moving_lby := 0.0
	var last_lby := 0.0
	var lby_update_at := 0.0
	var moving := false
	var misses := 0
	var side := 1
	var delta := 58.0
	var broken := false
	var last_resolved := 0.0
	var layers_fakewalk := false


var recs: Dictionary = {}  # instance_id -> Rec
var time := 0.0


func rec(p: Node) -> Rec:
	var id := p.get_instance_id()
	if not recs.has(id):
		recs[id] = Rec.new()
	return recs[id]


func observe(p: Node, dt: float) -> void:
	time += dt
	if p == null or not p.alive:
		return
	var r := rec(p)
	var aa: AntiAim = p.aa
	var spd: float = Vector2(p.velocity.x, p.velocity.z).length()
	r.moving = spd > Net.hu(1.1) and bool(p.grounded)
	if absf(Net.ang_delta(aa.lby, r.last_lby)) > 1.0:
		if not r.moving and absf(Net.ang_delta(aa.lby, r.last_moving_lby)) > 60.0:
			r.broken = true
			r.delta = absf(Net.ang_delta(aa.lby, r.last_moving_lby))
			r.side = 1 if Net.ang_delta(aa.lby, r.last_moving_lby) > 0.0 else -1
		r.last_lby = aa.lby
		r.lby_update_at = time
	if r.moving:
		r.last_moving_lby = aa.lby
		r.broken = false


func resolve(p: Node) -> float:
	var r := rec(p)
	var aa: AntiAim = p.aa
	if not bool(Cheat.t("rage/resolver", true)):
		return aa.fake_yaw
	var ovr := int(Cheat.t("rage/resolver_override", 0))
	if ovr == 1:
		r.last_resolved = Net.ang_norm(aa.lby + 58.0)
		return r.last_resolved
	if ovr == 2:
		r.last_resolved = Net.ang_norm(aa.lby - 58.0)
		return r.last_resolved
	if ovr == 3:
		r.last_resolved = aa.lby
		return aa.lby
	if ovr == 4:
		r.last_resolved = r.last_moving_lby
		return r.last_moving_lby
	var mode := int(Cheat.t("rage/resolver_type", 3))
	# Shooting players: eyes = real (2018 on-shot)
	if p.shot_this_tick:
		return aa.real_yaw
	if r.moving and not r.layers_fakewalk:
		r.last_resolved = aa.lby
		return aa.lby
	match mode:
		Mode.LBY:
			return _lby(p, r)
		Mode.BRUTE:
			return _brute(p, r)
		Mode.DELTA:
			return _delta(p, r)
		_:
			return _hybrid(p, r)


func miss(p: Node) -> void:
	var r := rec(p)
	r.misses += 1
	r.side *= -1


func hit(p: Node) -> void:
	rec(p).misses = 0


func _lby(p: Node, r: Rec) -> float:
	var aa: AntiAim = p.aa
	# First 0.22s after stop: last moving LBY is still real.
	if time - r.lby_update_at < 0.22 and not r.broken:
		return r.last_moving_lby
	if r.broken:
		# Breaker: LBY is fake. Inverse of logged delta.
		return Net.ang_norm(aa.lby + r.side * r.delta)
	return aa.lby


func _brute(p: Node, r: Rec) -> float:
	var aa: AntiAim = p.aa
	var base := aa.lby
	match r.misses % 5:
		0:
			return Net.ang_norm(base + 180.0)
		1:
			return Net.ang_norm(base + 120.0)
		2:
			return Net.ang_norm(base - 120.0)
		3:
			return Net.ang_norm(base + 58.0)
		_:
			return Net.ang_norm(base - 58.0)


func _delta(p: Node, r: Rec) -> float:
	var aa: AntiAim = p.aa
	var d := r.delta if r.delta > 1.0 else 58.0
	if r.misses % 2 == 0:
		return Net.ang_norm(aa.lby - d * r.side)
	return Net.ang_norm(aa.lby + d * r.side)


func _hybrid(p: Node, r: Rec) -> float:
	# gamesense 2018 flavour: moving LBY, then breaker inverse, then brute on misses.
	if r.misses == 0:
		return _lby(p, r)
	if r.misses <= 2:
		return _delta(p, r)
	return _brute(p, r)


func label(p: Node) -> String:
	var r := rec(p)
	if r.moving:
		return "LBY MOVE"
	if r.broken:
		return "BREAK ±%d" % int(r.delta)
	if r.misses > 0:
		return "BRUTE %d" % r.misses
	return "LBY"
