class_name PlayerMove
extends RefCounted
## Source CGameMovement: wish, friction, ClipVelocity, StepMove (18 HU).
## TryPlayerMove clips original velocity against planes and keeps leftover
## time along the wall. Never teleports the hull into solid (Jolt/WASM abort).

const _MARGIN := 0.008
const _BUMPS := 5
const _FLOOR_Y := 0.7
const _MAX_TICK_DISP := 4.0


static func step(p, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or delta > 0.25:
		delta = Net.TICK
	_categorize(p)
	var wish := _wish(p)
	var jumped := _jump(p)
	if jumped:
		p.grounded = false
	if p.want_autostop:
		wish = Vector3.ZERO
		p.velocity.x *= 0.35
		p.velocity.z *= 0.35
	if bool(Cheat.t("aa/slowwalk", false)):
		wish *= float(Cheat.t("aa/slowwalk_spd", 80)) / 250.0
	p.duck_amt = move_toward(p.duck_amt, 1.0 if p.ducking else 0.0, delta / 0.2)
	var w := Weapons.get_w(p.weapon_id)
	var maxsp := Net.hu(float(w.move))
	if p.scoped and w.has("scoped_speed"):
		maxsp = Net.hu(float(w.scoped_speed))
	if p.duck_amt > 0.5:
		maxsp *= 0.34
	var frozen := Match.phase == Match.Phase.FREEZE or Match.phase == Match.Phase.ROUND_END or Match.phase == Match.Phase.MATCH_END
	if frozen and p.qa_wish.length_squared() < 0.0001:
		wish = Vector3.ZERO
		p.velocity.x = 0.0
		p.velocity.z = 0.0
		if p.velocity.y > 0.0:
			p.velocity.y = 0.0
		jumped = false
	if p.is_local and bool(Cheat.t("misc/autostrafe", 0)) and not p.grounded:
		wish = autostrafe(p)
	if p.grounded and not jumped:
		friction(p, delta)
		accelerate(p, wish, maxsp, Net.ACCELERATE, delta)
		p.velocity.y = minf(p.velocity.y, 0.0)
	else:
		accelerate(p, wish, minf(maxsp, Net.AIR_CAP), Net.AIRACCELERATE, delta)
		p.velocity.y -= Net.GRAVITY * delta
	p.velocity = _clamp_vel(p.velocity, maxsp)
	_apply_hull(p)
	var saved_pos: Vector3 = p.global_position
	var saved_vel: Vector3 = p.velocity
	_fly_move(p, delta)
	if not jumped and p.global_position.y > saved_pos.y + Net.hu(20.0):
		p.global_position.y = saved_pos.y
		p.velocity.y = minf(p.velocity.y, 0.0)
	var dxz: float = Vector2(p.global_position.x - saved_pos.x, p.global_position.z - saved_pos.z).length()
	var expected := Vector2(saved_vel.x, saved_vel.z).length() * delta
	var blocked := expected > 0.008 and dxz < expected * 0.4
	var stepped := false
	if blocked and not jumped:
		stepped = _probe_step(p, wish, saved_vel)
		if not stepped:
			stepped = _step_move(p, saved_pos, saved_vel, delta)
	if stepped:
		p.grounded = true
		_stay_ground(p)
	else:
		_categorize(p)
		if not jumped and p.grounded:
			_stay_ground(p)
	_nudge_if_stuck(p, wish, saved_pos, maxsp)
	_recover(p, saved_pos)
	if Net.finite3(p.global_position) and p.grounded and p.global_position.y > -18.0:
		p.move_ok = p.global_position


static func _wish(p) -> Vector3:
	var wish := Vector3.ZERO
	if p.is_local and not Cheat.menu_open and not Cheat.buy_open and not p.is_bot:
		var f := Input.get_axis("move_back", "move_forward")
		var s := Input.get_axis("move_left", "move_right")
		var fwd := Net.yaw_vec(p.view_yaw)
		var rgt := Net.right_vec(p.view_yaw)
		wish = (fwd * f + rgt * s)
		if wish.length() > 1.0:
			wish = wish.normalized()
		p.ducking = Input.is_action_pressed("duck") or bool(Cheat.t("aa/fakeduck", false))
	if p.is_bot:
		wish = p.bot_wish
		p.ducking = p.bot_duck
	if p.qa_wish.length_squared() > 0.0001:
		wish = p.qa_wish.normalized()
	return wish


static func _jump(p) -> bool:
	if not Match.in_play() or not p.grounded:
		return false
	if p.is_bot:
		if p.bot_jump:
			p.velocity.y = Net.JUMP_IMPULSE
			return true
		return false
	if p.is_local and not Cheat.menu_open and not Cheat.buy_open and not p.is_bot:
		if bool(Cheat.t("misc/bhop", true)):
			if Input.is_action_pressed("jump"):
				p.velocity.y = Net.JUMP_IMPULSE
				return true
		elif Input.is_action_just_pressed("jump"):
			p.velocity.y = Net.JUMP_IMPULSE
			return true
	return false


static func _apply_hull(p) -> void:
	var cap: CapsuleShape3D = p.hull.shape as CapsuleShape3D
	if cap == null:
		return
	var want: float = Net.PLAYER_DUCK_H if p.duck_amt > 0.5 else Net.PLAYER_HULL_H
	if absf(cap.height - want) < 0.001:
		return
	if want > cap.height + 0.001:
		var rise := Vector3(0.0, want - cap.height + 0.02, 0.0)
		if p.test_move(p.global_transform, rise):
			p.ducking = true
			p.duck_amt = 1.0
			return
	cap.height = want
	cap.radius = Net.PLAYER_HULL_W * 0.5
	p.hull.position.y = want * 0.5


## Flatten trimesh edge normals so a wall lip cannot become a ramp.
static func _plane(n: Vector3) -> Vector3:
	if not Net.finite3(n) or n.length_squared() < 0.0001:
		return Vector3.UP
	n = n.normalized()
	if n.y >= _FLOOR_Y or n.y <= -_FLOOR_Y:
		return n
	var flat := Vector3(n.x, 0.0, n.z)
	if flat.length_squared() < 0.0001:
		return n
	return flat.normalized()


static func _clip(vel: Vector3, n: Vector3) -> Vector3:
	var backoff := vel.dot(n)
	if backoff >= 0.0:
		return vel
	# 1.001: Quake overbounce — sit off the plane so the next trace can slide.
	return vel - n * (backoff * 1.001)


static func _clip_against(original: Vector3, planes: Array[Vector3]) -> Vector3:
	var n := planes.size()
	if n == 0:
		return original
	var i := 0
	while i < n:
		var new_vel := _clip(original, planes[i])
		var j := 0
		var into := false
		while j < n:
			if j != i and new_vel.dot(planes[j]) < 0.0:
				into = true
				break
			j += 1
		if not into:
			return new_vel
		i += 1
	if n != 2:
		return Vector3(0.0, minf(original.y, 0.0), 0.0)
	var dir := planes[0].cross(planes[1])
	if dir.length_squared() < 0.0001:
		return Vector3(0.0, minf(original.y, 0.0), 0.0)
	dir = dir.normalized()
	return dir * dir.dot(original)


static func _collide(p, motion: Vector3) -> KinematicCollision3D:
	if not Net.finite3(p.global_position) or not Net.finite3(motion):
		return null
	if motion.length_squared() < 1e-14:
		return null
	var before: Vector3 = p.global_position
	var col: KinematicCollision3D = p.move_and_collide(motion, false, _MARGIN, false, 1)
	if not Net.finite3(p.global_position):
		p.global_position = before
		p.velocity = Vector3.ZERO
		return null
	if p.global_position.distance_squared_to(before) > _MAX_TICK_DISP * _MAX_TICK_DISP:
		p.global_position = before
		p.velocity = Vector3.ZERO
		return null
	return col


## Source TryPlayerMove: clip the *original* velocity, keep leftover time along the wall.
static func _fly_move(p, dt: float) -> bool:
	var time_left := dt
	var hit_wall := false
	var primal: Vector3 = p.velocity
	var original: Vector3 = p.velocity
	var planes: Array[Vector3] = []
	var unstuck := false
	for _bump in _BUMPS:
		if time_left <= 0.0004:
			break
		var vel: Vector3 = p.velocity
		if not Net.finite3(vel):
			p.velocity = Vector3.ZERO
			break
		if vel.length_squared() < 1e-12:
			break
		var motion := vel * time_left
		var before: Vector3 = p.global_position
		var col: KinematicCollision3D = _collide(p, motion)
		if col == null:
			break
		var traveled: Vector3 = p.global_position - before
		if not Net.finite3(traveled):
			p.global_position = before
			break
		var tlen: float = traveled.length()
		var mlen := maxf(motion.length(), 1e-8)
		var frac := clampf(tlen / mlen, 0.0, 1.0)
		if frac > 0.0:
			original = p.velocity
			planes.clear()
		if frac >= 0.999:
			break
		var n := _plane(col.get_normal())
		if n.y >= _FLOOR_Y:
			if p.velocity.y < 0.0:
				p.velocity.y = 0.0
			if original.y < 0.0:
				original.y = 0.0
			# Floor is not a clip plane — trimesh lips would eat wish.
			if frac < 0.0001:
				time_left = maxf(time_left - 0.0002, 0.0)
			else:
				time_left *= (1.0 - frac)
			continue
		if n.y <= -_FLOOR_Y:
			if p.velocity.y > 0.0:
				p.velocity.y = 0.0
			time_left *= (1.0 - frac) if frac > 0.0001 else 0.5
			continue
		hit_wall = true
		if frac < 0.0001:
			if not unstuck:
				_collide(p, n * 0.002)
				unstuck = true
			time_left = maxf(time_left - 0.00015, 0.0)
		else:
			time_left *= (1.0 - frac)
		var dup := false
		for pl in planes:
			if pl.dot(n) > 0.99:
				dup = true
				break
		if not dup:
			if planes.size() >= 5:
				p.velocity.x = 0.0
				p.velocity.z = 0.0
				break
			planes.append(n)
		p.velocity = _clip_against(original, planes)
		_keep_tangent(p, original, n)
		if Vector2(p.velocity.x, p.velocity.z).length_squared() < 1e-10:
			break
		if p.velocity.dot(primal) < -0.001:
			p.velocity.x = 0.0
			p.velocity.z = 0.0
			break
	return hit_wall


static func _keep_tangent(p, original: Vector3, n: Vector3) -> void:
	var o2 := Vector2(original.x, original.z)
	var n2 := Vector2(n.x, n.z)
	if o2.length_squared() < 0.0001 or n2.length_squared() < 0.0001:
		return
	n2 = n2.normalized()
	var tang: Vector2 = o2 - n2 * o2.dot(n2)
	if tang.length() < o2.length() * 0.12:
		return
	tang = tang.normalized() * o2.length()
	p.velocity.x = tang.x
	p.velocity.z = tang.y


static func _probe_step(p, wish: Vector3, saved_vel: Vector3) -> bool:
	# Trace down in front of the hull, then climb with collide (never embed).
	var dir := Vector3(wish.x, 0.0, wish.z)
	if dir.length_squared() < 0.0001:
		dir = Vector3(saved_vel.x, 0.0, saved_vel.z)
	if dir.length_squared() < 0.0001:
		return false
	dir = dir.normalized()
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	if space == null:
		return false
	var origin: Vector3 = p.global_position
	var saved_vel2: Vector3 = p.velocity
	for dist_hu in [10.0, 16.0, 22.0, 28.0]:
		var dist: float = Net.hu(dist_hu)
		var feet := origin + dir * dist
		var from := feet + Vector3(0.0, Net.STEP + 0.05, 0.0)
		var to := feet + Vector3(0.0, -Net.hu(1.0), 0.0)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = 1
		q.exclude = [p.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty() or not hit.has("position"):
			continue
		var n: Vector3 = hit.get("normal", Vector3.UP)
		if not Net.finite3(n) or n.y < _FLOOR_Y:
			continue
		var ny: float = float(hit.position.y)
		var dy: float = ny - origin.y
		if dy < Net.hu(7.0) or dy > Net.STEP + 0.02:
			continue
		if _climb(p, origin, dir, dist, dy, saved_vel):
			return true
		p.global_position = origin
		p.velocity = saved_vel2
	p.global_position = origin
	p.velocity = saved_vel2
	return false


static func _climb(p, origin: Vector3, dir: Vector3, dist: float, dy: float, saved_vel: Vector3) -> bool:
	p.global_position = origin
	p.velocity = Vector3.ZERO
	_collide(p, Vector3(0.0, dy + 0.008, 0.0))
	if p.global_position.y < origin.y + Net.hu(6.0):
		return false
	p.velocity = Vector3(saved_vel.x, 0.0, saved_vel.z)
	_collide(p, dir * dist)
	_collide(p, Vector3(0.0, -Net.hu(4.0), 0.0))
	if not Net.finite3(p.global_position):
		return false
	if p.global_position.y < origin.y + Net.hu(6.0):
		return false
	if p.global_position.y > origin.y + Net.STEP + 0.08:
		return false
	var fwd: float = (p.global_position.x - origin.x) * dir.x + (p.global_position.z - origin.z) * dir.z
	if fwd < dist * 0.30:
		return false
	p.velocity = Vector3(saved_vel.x, 0.0, saved_vel.z)
	p.qa_steps += 1
	p.grounded = true
	return true


static func _step_move(p, start_pos: Vector3, start_vel: Vector3, dt: float) -> bool:
	if Vector2(start_vel.x, start_vel.z).length_squared() < 0.002:
		return false
	var down_pos: Vector3 = p.global_position
	var down_vel: Vector3 = p.velocity
	var down_xz: float = Vector2(down_pos.x - start_pos.x, down_pos.z - start_pos.z).length_squared()
	var heights: Array[float] = [Net.hu(8.0), Net.hu(12.0), Net.hu(16.0), Net.STEP]
	for lift in heights:
		p.global_position = start_pos
		p.velocity = Vector3.ZERO
		_collide(p, Vector3(0.0, lift, 0.0))
		if p.global_position.y < start_pos.y + lift * 0.55:
			continue
		p.velocity = Vector3(start_vel.x, 0.0, start_vel.z)
		_fly_move(p, dt)
		_collide(p, Vector3(0.0, -lift - 0.08, 0.0))
		var up_pos: Vector3 = p.global_position
		if not Net.finite3(up_pos):
			continue
		var up_xz: float = Vector2(up_pos.x - start_pos.x, up_pos.z - start_pos.z).length_squared()
		var dy: float = up_pos.y - start_pos.y
		if up_xz > down_xz + 0.00004 and dy >= Net.hu(7.0) and dy <= Net.STEP + 0.08:
			p.velocity.y = minf(p.velocity.y, 0.0)
			p.qa_steps += 1
			p.grounded = true
			return true
	p.global_position = down_pos
	p.velocity = down_vel
	return false


static func _categorize(p) -> void:
	p.grounded = false
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	if space == null:
		return
	var from: Vector3 = p.global_position + Vector3(0.0, 0.04, 0.0)
	# 4 HU — must stay below the 8 HU stair tread or we pull the player back down.
	var to: Vector3 = p.global_position + Vector3(0.0, -Net.hu(4.0), 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.exclude = [p.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty() and hit.has("position"):
		var n: Vector3 = hit.get("normal", Vector3.UP)
		if Net.finite3(n) and n.y >= _FLOOR_Y:
			p.grounded = true
			if p.velocity.y <= Net.hu(40.0):
				var gy: float = float(hit.position.y)
				if absf(p.global_position.y - gy) < Net.hu(4.0):
					p.global_position.y = gy + 0.002
					if p.velocity.y < 0.0:
						p.velocity.y = 0.0
			return
	# Ray can miss a stair lip; a short downward collide still finds the tread.
	var before: Vector3 = p.global_position
	var col: KinematicCollision3D = p.move_and_collide(Vector3(0.0, -Net.hu(3.5), 0.0), true, _MARGIN, true, 1)
	if col == null:
		return
	if not Net.finite3(p.global_position):
		p.global_position = before
		return
	var cn: Vector3 = col.get_normal()
	if Net.finite3(cn) and cn.y >= _FLOOR_Y:
		p.grounded = true
		if p.velocity.y < 0.0:
			p.velocity.y = 0.0


static func _stay_ground(p) -> void:
	# Source StayOnGround: trace ~2 HU, not a stair-height snap.
	if p.velocity.y > 0.02:
		return
	var before: Vector3 = p.global_position
	p.move_and_collide(Vector3(0.0, -Net.hu(2.0) - 0.003, 0.0), false, _MARGIN, false, 1)
	if not Net.finite3(p.global_position) or p.global_position.distance_squared_to(before) > 0.25:
		p.global_position = before
		return
	if p.velocity.y < 0.0:
		p.velocity.y = 0.0


static func _nudge_if_stuck(p, wish: Vector3, saved_pos: Vector3, maxsp: float) -> void:
	if p.qa_wish.length_squared() > 0.0001:
		p.move_stuck = 0
		return
	if not p.grounded or wish.length_squared() < 0.25:
		p.move_stuck = 0
		return
	var dxz: float = Vector2(p.global_position.x - saved_pos.x, p.global_position.z - saved_pos.z).length()
	if dxz > 0.002:
		p.move_stuck = 0
		return
	p.move_stuck += 1
	if p.move_stuck < 12:
		return
	p.move_stuck = 0
	var tangent := Vector3(-wish.z, 0.0, wish.x)
	if tangent.length_squared() < 0.0001:
		return
	tangent = tangent.normalized()
	_collide(p, tangent * 0.02)
	p.velocity.x = tangent.x * maxsp * 0.35
	p.velocity.z = tangent.z * maxsp * 0.35
	p.velocity.y = minf(p.velocity.y, 0.0)


static func _clamp_vel(v: Vector3, maxsp: float) -> Vector3:
	v = Net.sanitize3(v)
	var xz := Vector2(v.x, v.z)
	var cap := maxsp * 1.35
	if xz.length() > cap:
		xz = xz.normalized() * cap
		v.x = xz.x
		v.z = xz.y
	v.y = clampf(v.y, -Net.hu(3500.0), Net.JUMP_IMPULSE * 1.5)
	return v


static func _recover(p, saved_pos: Vector3) -> void:
	if not Net.finite3(p.global_position) or not Net.finite3(p.velocity) or p.global_position.y < -18.0:
		if Net.finite3(p.move_ok) and p.move_ok.y > -18.0:
			p.global_position = p.move_ok
		else:
			p.global_position = p.spawn_origin
		p.velocity = Vector3.ZERO
		p.move_stuck = 0
		p.grounded = true
		return
	if p.global_position.distance_squared_to(saved_pos) > _MAX_TICK_DISP * _MAX_TICK_DISP:
		p.global_position = saved_pos
		p.velocity = Vector3.ZERO
		p.grounded = true


static func autostrafe(p) -> Vector3:
	var spd := Vector2(p.velocity.x, p.velocity.z).length()
	if spd < 0.01:
		return Net.yaw_vec(p.view_yaw)
	var wish_ang := atan2(-p.velocity.x, -p.velocity.z) + (0.3 if Input.get_axis("move_left", "move_right") >= 0 else -0.3)
	return Vector3(-sin(wish_ang), 0, -cos(wish_ang))


static func friction(p, delta: float) -> void:
	var spd := Vector2(p.velocity.x, p.velocity.z).length()
	if spd < 0.01:
		return
	var drop := 0.0
	var control := Net.STOP_SPEED if spd < Net.STOP_SPEED else spd
	drop += control * Net.FRICTION * delta
	var ns := maxf(spd - drop, 0)
	if ns != spd:
		var f := ns / spd
		p.velocity.x *= f
		p.velocity.z *= f


static func accelerate(p, wish: Vector3, wishspd: float, accel: float, delta: float) -> void:
	if wish.length() < 0.01:
		return
	wish = wish.normalized()
	var curs: float = p.velocity.dot(wish)
	var add: float = wishspd - curs
	if add <= 0:
		return
	var acc := accel * wishspd * delta
	if acc > add:
		acc = add
	p.velocity += wish * acc
