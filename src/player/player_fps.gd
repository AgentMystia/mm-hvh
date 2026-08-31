class_name PlayerFps
extends RefCounted
## CS:GO mouse look (m_yaw 0.022), roll-free camera, Source sv_stepsize 18 HU.


static func apply_mouse(p, event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var rel: Vector2 = event.screen_relative
	if rel.length_squared() < 0.000001:
		rel = event.relative
	# Pointer-lock can emit a huge first delta; ignore spikes (not smoothing).
	rel.x = clampf(rel.x, -320.0, 320.0)
	rel.y = clampf(rel.y, -320.0, 320.0)
	var sens := float(Cheat.t("misc/sens", 2.0))
	if p.scoped:
		sens *= float(Cheat.t("misc/zoom_sens", 1.0))
	var yaw_scale := float(Cheat.t("misc/m_yaw", 0.022)) * sens
	var pitch_scale := float(Cheat.t("misc/m_pitch", 0.022)) * sens
	# CS:GO m_rawinput 1 / m_filter 0: 1:1 counts. Mouse down = look down.
	p.view_yaw = Net.ang_norm(p.view_yaw - rel.x * yaw_scale)
	p.view_pitch = clampf(p.view_pitch + rel.y * pitch_scale, -89.0, 89.0)
	camera(p, 0.0)


static func view_origin(p) -> Vector3:
	var f := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	return p._origin_prev.lerp(p._origin_curr, f)


static func camera(p, dt: float) -> void:
	if not p.is_local or p.cam == null:
		return
	p.cam.current = true
	p.yaw_helper.rotation = Vector3(0.0, deg_to_rad(p.view_yaw), 0.0)
	var aspect := 16.0 / 9.0
	var vs: Vector2 = p.get_viewport().get_visible_rect().size
	if vs.y > 1.0:
		aspect = vs.x / vs.y
	var hfov := float(Cheat.t("visuals/fov", 110))
	if p.scoped:
		hfov = float(Weapons.get_w(p.weapon_id).get("zoom_fov", 40))
	var vfov := Net.hfov_to_vfov(hfov, aspect)
	if dt > 0.0:
		var k := 1.0 - exp(-18.0 * dt)
		p._cam_fov = lerpf(p._cam_fov, vfov, k)
	else:
		p._cam_fov = vfov
	p.cam.fov = p._cam_fov
	var eye_h := lerpf(Net.EYE_STAND, Net.EYE_DUCK, p.duck_amt)
	var origin := view_origin(p)
	var focus := origin + Vector3(0.0, eye_h, 0.0)
	var basis := Net.view_basis(p.view_pitch, p.view_yaw)
	var tp := bool(Cheat.t("visuals/thirdperson", true))
	if p.viewmodel:
		var w := Weapons.get_w(p.weapon_id)
		p.viewmodel.visible = (not tp) and p.alive
		if bool(w.get("zoom", false)) and p.scoped:
			p.viewmodel.visible = false
		p.viewmodel.position = Vector3(0.16, -0.14, -0.32)
		if p.weapon_id == "awp" or p.weapon_id == "ssg08" or p.weapon_id == "g3sg1" or p.weapon_id == "scar20":
			p.viewmodel.position = Vector3(0.14, -0.12, -0.38)
			p.viewmodel.scale = Vector3(1.0, 1.0, 1.35)
		elif bool(w.get("revolver", false)):
			p.viewmodel.position = Vector3(0.18, -0.12, -0.28)
			p.viewmodel.scale = Vector3(1.15, 1.2, 0.7)
		else:
			p.viewmodel.scale = Vector3.ONE
	if tp:
		# Rear-diagonal, raised — you see the pitch-down 89 dummy and the yaw axes.
		var dist := float(Cheat.t("visuals/tp_dist", 100)) * Net.HU
		var look := -basis.z
		var right := basis.x
		var desired := focus - look * dist + Vector3(0.0, 0.82, 0.0) + right * 0.72
		var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
		if space:
			var q := PhysicsRayQueryParameters3D.create(focus, desired)
			q.collision_mask = 1
			q.exclude = [p.get_rid()]
			var hit: Dictionary = space.intersect_ray(q)
			if hit:
				desired = hit.position + hit.normal * 0.08
		p.cam.global_transform = Transform3D(basis, desired)
	else:
		p.cam.global_transform = Transform3D(basis, focus)


static func try_step(p, saved_pos: Vector3, saved_vel: Vector3) -> void:
	# Source CGameMovement::StepMove — sv_stepsize 18 HU.
	if Vector2(saved_vel.x, saved_vel.z).length_squared() < 0.002:
		return
	var wall := false
	for i in p.get_slide_collision_count():
		if p.get_slide_collision(i).get_normal().y < 0.7:
			wall = true
			break
	if not wall:
		return
	var down_pos: Vector3 = p.global_position
	var down_vel: Vector3 = p.velocity
	var down_xz: float = Vector2(down_pos.x - saved_pos.x, down_pos.z - saved_pos.z).length_squared()
	p.global_position = saved_pos
	p.velocity = saved_vel
	var ceiling: KinematicCollision3D = p.move_and_collide(Vector3(0, Net.STEP, 0))
	if ceiling and ceiling.get_normal().y < -0.2:
		p.global_position = down_pos
		p.velocity = down_vel
		return
	p.move_and_slide()
	p.move_and_collide(Vector3(0, -Net.STEP - 0.08, 0))
	var up_pos: Vector3 = p.global_position
	var up_xz: float = Vector2(up_pos.x - saved_pos.x, up_pos.z - saved_pos.z).length_squared()
	var dy: float = up_pos.y - saved_pos.y
	# Same-height "better XZ" is unsticking from a wall edge, not a stair.
	if up_xz <= down_xz + 0.00004 or dy < Net.hu(2.0) or dy > Net.STEP + 0.05:
		p.global_position = down_pos
		p.velocity = down_vel
		return
	p.velocity.y = minf(p.velocity.y, 0.0)
	p.qa_steps += 1
