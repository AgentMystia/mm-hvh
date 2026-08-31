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
	p.hull.shape.size = Vector3(Net.PLAYER_HULL_W, lerpf(Net.PLAYER_HULL_H, Net.PLAYER_DUCK_H, p.duck_amt), Net.PLAYER_HULL_W)
	p.hull.position.y = p.hull.shape.size.y * 0.5
	var saved_pos: Vector3 = p.global_position
	var saved_vel: Vector3 = p.velocity
	p.move_and_slide()
	_Fps.try_step(p, saved_pos, saved_vel)


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
