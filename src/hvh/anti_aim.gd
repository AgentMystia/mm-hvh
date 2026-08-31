class_name AntiAim
extends RefCounted
## 2018-flavour anti-aim: pitch, yaw, fake, LBY breaker, freestanding, manual.

enum Pitch { OFF, DOWN, UP, ZERO, FAKE_DOWN, RANDOM }
enum Yaw { OFF, BACK, SPIN, JITTER, SIDEWAYS, LOW_DELTA, DISTORTION }
enum Fake { OFF, STATIC, OPPOSITE, JITTER, LBY }
enum LbyMode { OFF, OPPOSITE, SWAY, PREDICT, BREAK, EXPERIMENTAL }

var real_pitch := 0.0
var real_yaw := 0.0
var fake_yaw := 0.0
var lby := 0.0
var view_yaw := 0.0
var moving := false
var on_ground := true
var lby_timer := 1.1
var broke_this_tick := false
var spin_acc := 0.0
var jitter_flip := false
var choke := 0
var desync_delta := 58.0
var last_lby_flick_at := -999.0
var _time := 0.0
var _fs_yaw := 0.0
var _fs_frame := -99
## If set, read AA from this dict instead of the local cheat menu (used by bots).
var src: Dictionary = {}


func _g(key: String, default: Variant = null) -> Variant:
	if src.has(key):
		return src[key]
	return Cheat.t("aa/" + key, default)

func reset() -> void:
	lby_timer = 1.1
	spin_acc = 0.0
	choke = 0


func tick(dt: float, view: Vector3, vel: Vector3, origin: Vector3, enemies: Array, walls: World3D) -> void:
	_time += dt
	view_yaw = view.y
	var spd := Vector2(vel.x, vel.z).length()
	moving = spd > Net.hu(1.1) and on_ground
	broke_this_tick = false
	if not bool(_g("enable", true)):
		real_yaw = view.y
		fake_yaw = view.y
		real_pitch = view.x
		lby = view.y
		return
	real_pitch = _pitch(view.x)
	var base := _base(view.y, origin, enemies)
	var yaw_mode := int(_g("yaw", 1))
	real_yaw = _yaw(base, yaw_mode)
	real_yaw = Net.ang_norm(real_yaw + float(_g("yaw_add", 0)))
	if bool(_g("jitter", true)) and yaw_mode != Yaw.JITTER:
		real_yaw = Net.ang_norm(real_yaw + _jitter())
	var man := int(_g("manual", 0))
	if man == 1:
		real_yaw = Net.ang_norm(view.y + 90.0)
	elif man == 2:
		real_yaw = Net.ang_norm(view.y - 90.0)
	elif man == 3:
		real_yaw = Net.ang_norm(view.y + 180.0)
	if bool(_g("freestanding", true)):
		var pf := Engine.get_physics_frames()
		if pf - _fs_frame >= 8:
			_fs_yaw = _freestand(origin, view.y, walls, real_yaw)
			_fs_frame = pf
		real_yaw = _fs_yaw
	_lby(dt)
	fake_yaw = _fake(real_yaw)
	desync_delta = Net.ang_delta(fake_yaw, real_yaw)


func _pitch(view_p: float) -> float:
	match int(_g("pitch", 1)):
		Pitch.DOWN:
			return 89.0
		Pitch.UP:
			return -89.0
		Pitch.ZERO:
			return 0.0
		Pitch.FAKE_DOWN:
			return 180.0  # untrusted 2018 flavour (visual only)
		Pitch.RANDOM:
			return 89.0 if Engine.get_physics_frames() % 2 == 0 else -89.0
		_:
			return view_p


func _base(view_y: float, origin: Vector3, enemies: Array) -> float:
	match int(_g("yaw_base", 1)):
		1:
			var t = _closest(origin, enemies)
			if t != null:
				var to: Vector3 = (t as Node3D).global_position - origin
				return rad_to_deg(atan2(-to.x, -to.z))
			return view_y
		2:
			return 0.0
		_:
			return view_y


func _yaw(base: float, mode: int) -> float:
	match mode:
		Yaw.BACK:
			return Net.ang_norm(base + 180.0)
		Yaw.SPIN:
			spin_acc = Net.ang_norm(spin_acc + 28.0)
			return spin_acc
		Yaw.JITTER:
			jitter_flip = not jitter_flip
			var r := float(_g("jitter_range", 12))
			return Net.ang_norm(base + 180.0 + (r if jitter_flip else -r))
		Yaw.SIDEWAYS:
			return Net.ang_norm(base + (90.0 if Engine.get_physics_frames() % 64 < 32 else -90.0))
		Yaw.LOW_DELTA:
			return Net.ang_norm(base + 180.0 + 22.0 * (1 if jitter_flip else -1))
		Yaw.DISTORTION:
			return Net.ang_norm(base + 180.0 + sin(_time * 9.0) * 38.0)
		_:
			return base


func _jitter() -> float:
	var r := float(_g("jitter_range", 12))
	match int(_g("jitter_type", 0)):
		1:
			jitter_flip = not jitter_flip
			return r * 0.5 * (1 if jitter_flip else -1)
		2:
			return randf_range(-r, r)
		_:
			jitter_flip = not jitter_flip
			return r if jitter_flip else 0.0


func _fake(real: float) -> float:
	var lim := float(_g("fake_limit", 58))
	match int(_g("fake", 2)):
		Fake.STATIC:
			return Net.ang_norm(real + lim)
		Fake.OPPOSITE:
			return Net.ang_norm(real + (lim if desync_delta >= 0 else -lim))
		Fake.JITTER:
			return Net.ang_norm(real + (lim if Engine.get_physics_frames() % 2 == 0 else -lim))
		Fake.LBY:
			return lby
		_:
			return real


func _lby(dt: float) -> void:
	var mode := int(_g("lby", 1))
	var delta := float(_g("lby_delta", 116))
	if moving:
		lby = real_yaw
		lby_timer = 0.22
		return
	if not on_ground:
		return
	lby_timer -= dt
	if mode == LbyMode.OFF:
		if lby_timer <= 0.0:
			lby = real_yaw
			lby_timer = 1.1
		return
	# Standing: first update 0.22s after stop, then 1.1s. Breaker flicks REAL to LBY.
	if lby_timer <= 0.0:
		broke_this_tick = true
		last_lby_flick_at = _time
		match mode:
			LbyMode.OPPOSITE:
				lby = Net.ang_norm(real_yaw + (delta if absf(Net.ang_delta(real_yaw, lby)) > 0 else -delta))
				real_yaw = lby  # flick real onto LBY this tick
			LbyMode.SWAY:
				lby = Net.ang_norm(lby + (delta if Engine.get_physics_frames() % 2 == 0 else -delta))
				real_yaw = lby
			LbyMode.PREDICT:
				lby = Net.ang_norm(real_yaw + delta)
				real_yaw = lby
			LbyMode.BREAK, LbyMode.EXPERIMENTAL:
				var side := 1.0 if sin(_time * 0.7) >= 0.0 else -1.0
				lby = Net.ang_norm(view_yaw + 180.0 + side * delta)
				real_yaw = lby
			_:
				lby = real_yaw
		lby_timer = 1.1
	elif mode == LbyMode.BREAK or mode == LbyMode.EXPERIMENTAL:
		# Hold real away from LBY between flicks so LBY resolvers miss.
		var side := 1.0 if sin(_time * 0.7) >= 0.0 else -1.0
		real_yaw = Net.ang_norm(lby + side * maxf(delta, 60.0))


func _freestand(origin: Vector3, view_y: float, world: World3D, current: float) -> float:
	if world == null:
		return current
	var space := world.direct_space_state
	if space == null:
		return current
	var eye := origin + Vector3(0, Net.EYE_STAND, 0)
	var best := current
	var best_frac := -1.0
	for off in [90.0, -90.0, 180.0, 0.0]:
		if not Perf.take_ray():
			break
		var yaw := Net.ang_norm(view_y + off)
		var dir := Net.yaw_vec(yaw)
		var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * 48.0)
		q.collision_mask = 1
		var hit := space.intersect_ray(q)
		var frac := 1.0
		if hit:
			frac = eye.distance_to(hit.position) / 48.0
		# Prefer the side with MORE wall (head hide) — classic 2018 freestanding.
		if 1.0 - frac > best_frac:
			best_frac = 1.0 - frac
			best = Net.ang_norm(view_y + 180.0 + off)
	return best


func _closest(origin: Vector3, enemies: Array):
	var best = null
	var bd := 1e9
	for e in enemies:
		if e == null or not is_instance_valid(e) or not e.alive:
			continue
		var d: float = origin.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best
