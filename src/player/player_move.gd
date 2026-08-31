class_name PlayerMove
extends RefCounted
## Source wish movement. Stair step-up is PlayerFps.try_step (sv_stepsize 18 HU).

const _Fps := preload("res://src/player/player_fps.gd")


static func step(p, delta: float) -> void:
	var wish := Vector3.ZERO
	if p.is_local and not Cheat.menu_open and not Cheat.buy_open and not p.is_bot:
		var f := Input.get_axis("move_back", "move_forward")
		var s := Input.get_axis("move_left", "move_right")
		var fwd := Net.yaw_vec(p.view_yaw)
		var rgt := Net.right_vec(p.view_yaw)
		wish = (fwd * f + rgt * s)
		if wish.length() > 1:
			wish = wish.normalized()
		p.ducking = Input.is_action_pressed("duck") or bool(Cheat.t("aa/fakeduck", false))
		if Match.in_play():
			if bool(Cheat.t("misc/bhop", true)):
				if Input.is_action_pressed("jump") and p.is_on_floor():
					p.velocity.y = Net.JUMP_IMPULSE
			elif Input.is_action_just_pressed("jump") and p.is_on_floor():
				p.velocity.y = Net.JUMP_IMPULSE
	if p.is_bot:
		wish = p.bot_wish
		p.ducking = p.bot_duck
		if p.bot_jump and p.is_on_floor() and Match.in_play():
			p.velocity.y = Net.JUMP_IMPULSE
	if p.qa_wish.length_squared() > 0.0001:
		wish = p.qa_wish.normalized()
	# Bots never freeze on autostop — that was the AFK lock after they spotted someone.
	if not p.is_bot:
		if p.want_autostop or (p.is_local and bool(Cheat.t("rage/autostop", true)) and p.last_rage.get("shoot", false)):
			wish = Vector3.ZERO
			p.velocity.x *= 0.4
			p.velocity.z *= 0.4
	if bool(Cheat.t("aa/slowwalk", false)):
		wish *= float(Cheat.t("aa/slowwalk_spd", 80)) / 250.0
	p.duck_amt = move_toward(p.duck_amt, 1.0 if p.ducking else 0.0, delta / 0.2)
	var w := Weapons.get_w(p.weapon_id)
	var maxsp := Net.hu(float(w.move))
	if p.scoped and w.has("scoped_speed"):
		maxsp = Net.hu(float(w.scoped_speed))
	if p.duck_amt > 0.5:
		maxsp *= 0.34
	if Match.phase == Match.Phase.FREEZE or Match.phase == Match.Phase.ROUND_END or Match.phase == Match.Phase.MATCH_END:
		wish = Vector3.ZERO
		p.velocity.x = 0.0
		p.velocity.z = 0.0
		if p.velocity.y > 0.0:
			p.velocity.y = 0.0
	if p.is_local and bool(Cheat.t("misc/autostrafe", 0)) and not p.is_on_floor():
		wish = autostrafe(p)
	if p.is_on_floor():
		friction(p, delta)
		accelerate(p, wish, maxsp, Net.ACCELERATE, delta)
	else:
		accelerate(p, wish, minf(maxsp, Net.AIR_CAP), Net.AIRACCELERATE, delta)
		p.velocity.y -= Net.GRAVITY * delta
	var hull_h: float = lerpf(Net.PLAYER_HULL_H, Net.PLAYER_DUCK_H, p.duck_amt)
	var box: BoxShape3D = p.hull.shape as BoxShape3D
	if box != null:
		box.size = Vector3(Net.PLAYER_HULL_W, hull_h, Net.PLAYER_HULL_W)
	p.hull.position.y = hull_h * 0.5
	var saved_pos: Vector3 = p.global_position
	var saved_vel: Vector3 = p.velocity
	var was_floor: bool = p.is_on_floor()
	p.move_and_slide()
	_stop_edge_lift(p, saved_pos, saved_vel, was_floor)
	_Fps.try_step(p, saved_pos, saved_vel)
	_unstuck_along_wall(p, wish, saved_pos, maxsp)


static func _stop_edge_lift(p, saved_pos: Vector3, saved_vel: Vector3, was_floor: bool) -> void:
	# Trimesh edges give normals with +Y; move_and_slide then rides the wall.
	if not was_floor:
		return
	if saved_vel.y > Net.hu(80.0):
		return
	var into_wall := 0.0
	var hv := Vector3(saved_vel.x, 0.0, saved_vel.z)
	var hvn := hv.normalized() if hv.length_squared() > 0.0001 else Vector3.ZERO
	for i in p.get_slide_collision_count():
		var n: Vector3 = p.get_slide_collision(i).get_normal()
		if n.y >= 0.45:
			continue
		var hn := Vector3(n.x, 0.0, n.z)
		if hn.length_squared() > 0.0001 and hvn.length_squared() > 0.0001:
			into_wall = maxf(into_wall, -hvn.dot(hn.normalized()))
	if p.velocity.y > 0.0:
		p.velocity.y = 0.0
	# Walking into a riser — leave height for try_step. Along-wall lift is suction.
	if into_wall >= 0.32:
		return
	var dy: float = p.global_position.y - saved_pos.y
	if dy > 0.006:
		p.global_position.y = saved_pos.y


static func _unstuck_along_wall(p, wish: Vector3, saved_pos: Vector3, maxsp: float) -> void:
	# Hugging a wall with W/A/D used to zero velocity (min slide angle). Slide tangent instead.
	if p.qa_wish.length_squared() > 0.0001:
		return
	if not p.is_on_floor():
		return
	if p.get_slide_collision_count() <= 0:
		return
	if wish.length_squared() < 0.01:
		return
	var dxz := Vector2(p.global_position.x - saved_pos.x, p.global_position.z - saved_pos.z)
	if dxz.length() > 0.012:
		return
	var nsum := Vector3.ZERO
	for i in p.get_slide_collision_count():
		var n: Vector3 = p.get_slide_collision(i).get_normal()
		if n.y >= 0.55:
			continue
		var hn := Vector3(n.x, 0.0, n.z)
		if hn.length_squared() > 0.0001:
			nsum += hn
	if nsum.length_squared() < 0.0001:
		nsum = Vector3(-wish.x, 0.0, -wish.z)
	var n := nsum.normalized()
	p.global_position += n * 0.03
	var tangent := Vector3(-n.z, 0.0, n.x)
	if wish.dot(tangent) < 0.0:
		tangent = -tangent
	if absf(wish.dot(tangent)) < 0.08:
		tangent = Vector3(-wish.z, 0.0, wish.x)
		if tangent.length_squared() < 0.0001:
			return
		tangent = tangent.normalized()
	var spd: float = maxf(maxsp * 0.82, Net.hu(80.0))
	p.velocity.x = tangent.x * spd
	p.velocity.z = tangent.z * spd
	p.velocity.y = minf(p.velocity.y, 0.0)
	p.move_and_slide()


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
