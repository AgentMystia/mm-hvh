class_name PlayerModel
extends Node3D
## Readable CS player dummy: head, torso, arms, legs, gun.
## Real / fake / LBY still yaw independently for 2018 AA.

var player: Player
var rig_vis: Node3D
var rig_fake: Node3D
var rig_lby: Node3D
var rig_xqz: Node3D
var _xqz_mat: ShaderMaterial
var _vis_mat: ShaderMaterial


func setup(p: Player) -> void:
	player = p
	_xqz_mat = _shd("res://assets/shaders/chams_xqz.gdshader")
	_vis_mat = _shd("res://assets/shaders/chams_vis.gdshader")
	rig_vis = _humanoid(true, true, false)
	rig_fake = _humanoid(true, true, false)
	rig_lby = _humanoid(true, false, true)
	rig_xqz = _humanoid(false, false, false)
	add_child(rig_vis)
	add_child(rig_fake)
	add_child(rig_lby)
	add_child(rig_xqz)


func _shd(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m


func _mi(mesh: Mesh, pos: Vector3, kind: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.set_meta("kind", kind)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	n.material_override = mat
	return n


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _sph(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 6
	return m


func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 1
	return m


func _humanoid(with_legs: bool, with_gun: bool, legs_only := false) -> Node3D:
	var root := Node3D.new()
	if with_legs:
		root.add_child(_mi(_box(Vector3(0.28, 0.16, 0.16)), Vector3(0, 0.92, 0), "pants"))
		for s in [-1.0, 1.0]:
			var thigh := _mi(_cyl(0.065, 0.38), Vector3(0.09 * s, 0.68, 0), "pants")
			root.add_child(thigh)
			var calf := _mi(_cyl(0.05, 0.36), Vector3(0.09 * s, 0.32, 0.01), "pants")
			root.add_child(calf)
			var foot := _mi(_box(Vector3(0.10, 0.07, 0.22)), Vector3(0.09 * s, 0.045, 0.04), "boot")
			root.add_child(foot)
	if legs_only:
		return root
	var stomach := _mi(_box(Vector3(0.30, 0.22, 0.16)), Vector3(0, 1.08, 0.01), "shirt")
	stomach.name = "stomach"
	root.add_child(stomach)
	var chest := _mi(_box(Vector3(0.36, 0.30, 0.18)), Vector3(0, 1.32, 0.02), "shirt")
	chest.name = "chest"
	root.add_child(chest)
	var neck := _mi(_cyl(0.045, 0.10), Vector3(0, 1.50, 0.02), "skin")
	root.add_child(neck)
	var head := _mi(_sph(0.115), Vector3(0, 1.64, 0.02), "skin")
	head.name = "head"
	root.add_child(head)
	var helm := _mi(_sph(0.122), Vector3(0, 1.66, 0.01), "helm")
	helm.name = "helm"
	root.add_child(helm)
	for s in [-1.0, 1.0]:
		var shoulder := _mi(_sph(0.055), Vector3(0.20 * s, 1.40, 0.02), "shirt")
		root.add_child(shoulder)
		var upper := _mi(_cyl(0.042, 0.28), Vector3(0.24 * s, 1.22, 0.04), "shirt")
		upper.rotation_degrees = Vector3(18.0, 0.0, -22.0 * s)
		root.add_child(upper)
		var fore := _mi(_cyl(0.036, 0.26), Vector3(0.28 * s, 1.00, 0.14), "skin")
		fore.rotation_degrees = Vector3(72.0, 0.0, -8.0 * s)
		root.add_child(fore)
	if with_gun:
		var gun := Node3D.new()
		gun.name = "gun"
		gun.position = Vector3(0.18, 1.12, -0.08)
		gun.add_child(_mi(_box(Vector3(0.05, 0.09, 0.28)), Vector3(0, 0.02, -0.04), "gun"))
		gun.add_child(_mi(_box(Vector3(0.028, 0.028, 0.38)), Vector3(0, 0.04, -0.32), "gun"))
		gun.add_child(_mi(_box(Vector3(0.04, 0.12, 0.07)), Vector3(0, -0.07, 0.02), "gun"))
		gun.add_child(_mi(_box(Vector3(0.04, 0.07, 0.14)), Vector3(0, 0.01, 0.16), "gun"))
		root.add_child(gun)
	return root


func _pal() -> Dictionary:
	var t := player.team == Match.Team.T
	return {
		"skin": Color(0.86, 0.68, 0.52),
		"shirt": Color(0.62, 0.42, 0.20) if t else Color(0.22, 0.34, 0.40),
		"pants": Color(0.42, 0.36, 0.22) if t else Color(0.14, 0.18, 0.22),
		"boot": Color(0.18, 0.14, 0.10),
		"gun": Color(0.10, 0.10, 0.11),
		"helm": Color(0.55, 0.38, 0.18) if t else Color(0.16, 0.22, 0.26),
	}


func tick() -> void:
	if player == null:
		return
	visible = player.alive
	if not player.alive:
		return
	var local := player.is_local
	var tp := bool(Cheat.t("visuals/thirdperson", true))
	if local and not tp:
		visible = false
		return
	visible = true
	scale.y = lerpf(1.0, 0.72, player.duck_amt)
	if local:
		_tick_local()
	else:
		_tick_enemy()


func _tick_enemy() -> void:
	var use_res := bool(Cheat.t("visuals/chams_resolved", true))
	var vis_yaw := player.resolved_yaw if use_res else player.aa.fake_yaw
	_pose(rig_vis, vis_yaw, player.aa.real_pitch)
	rig_vis.visible = true
	rig_lby.visible = false
	var chams := bool(Cheat.t("visuals/chams", true))
	if chams:
		_paint_chams(rig_vis, _col("visuals/chams_col", Color(0.2, 0.85, 0.35, 1)), false, false)
	else:
		_paint_team(rig_vis)
	rig_fake.visible = bool(Cheat.t("visuals/chams_fake", true))
	if rig_fake.visible:
		_pose(rig_fake, player.aa.fake_yaw, player.aa.real_pitch * 0.25)
		_paint_chams(rig_fake, _col("visuals/chams_fake_col", Color(0.25, 0.45, 1, 0.35)), true, false)
	rig_xqz.visible = bool(Cheat.t("visuals/chams_xqz", true))
	if rig_xqz.visible:
		_pose(rig_xqz, vis_yaw, player.aa.real_pitch * 0.35)
		_paint_chams(rig_xqz, _col("visuals/chams_xqz_col", Color(0.85, 0.25, 0.55, 1)), true, true)


func _tick_local() -> void:
	var chams := bool(Cheat.t("visuals/local_chams", true))
	# Solid team dummy at real yaw — this is the readable player.
	rig_vis.visible = (not chams) or bool(Cheat.t("visuals/local_real", true))
	_pose(rig_vis, player.aa.real_yaw, player.aa.real_pitch)
	_paint_team(rig_vis)
	rig_fake.visible = chams and bool(Cheat.t("visuals/local_fake", true))
	if rig_fake.visible:
		_pose(rig_fake, player.aa.fake_yaw, player.aa.real_pitch)
		_paint_chams(rig_fake, _col("visuals/local_fake_col", Color(0.25, 0.5, 1, 0.28)), true, false)
	rig_lby.visible = chams and bool(Cheat.t("visuals/local_lby", true))
	if rig_lby.visible:
		_pose(rig_lby, player.aa.lby, 0.0)
		_paint_chams(rig_lby, _col("visuals/local_lby_col", Color(1.0, 0.85, 0.15, 0.55)), true, false)
	rig_xqz.visible = false


func _pose(rig: Node3D, yaw: float, pitch: float) -> void:
	rig.rotation = Vector3(0.0, deg_to_rad(yaw), 0.0)
	var p := pitch
	if p > 90.0:
		p = 89.0
	var head := rig.get_node_or_null("head")
	var helm := rig.get_node_or_null("helm")
	var look := Net.look_dir(p, 0.0)
	if head:
		head.position = Vector3(0, 1.64, 0.02) + look * 0.10
		head.rotation = Vector3(deg_to_rad(p) * 0.85, 0.0, 0.0)
	if helm:
		helm.position = Vector3(0, 1.66, 0.01) + look * 0.10
		helm.rotation = Vector3(deg_to_rad(p) * 0.85, 0.0, 0.0)
		helm.visible = player.team == Match.Team.CT or player.helmet


func _col(path: String, fallback: Color) -> Color:
	var v = Cheat.t(path, null)
	if typeof(v) == TYPE_ARRAY and v.size() >= 3:
		return Color(v[0], v[1], v[2], v[3] if v.size() > 3 else 1.0)
	return fallback


func _paint_team(rig: Node3D) -> void:
	var pal: Dictionary = _pal()
	_walk_mesh(rig, func(mi: MeshInstance3D) -> void:
		var kind := str(mi.get_meta("kind", "shirt"))
		_std(mi, pal.get(kind, pal["shirt"]))
		if kind == "helm":
			mi.visible = player.team == Match.Team.CT or player.helmet
	)


func _paint_chams(rig: Node3D, c: Color, transparent: bool, through: bool) -> void:
	_walk_mesh(rig, func(mi: MeshInstance3D) -> void:
		_apply(mi, c, transparent, through)
	)


func _walk_mesh(n: Node, fn: Callable) -> void:
	if n is MeshInstance3D:
		fn.call(n)
	for c in n.get_children():
		_walk_mesh(c, fn)


func _apply(mi: MeshInstance3D, c: Color, _transparent: bool, through := false) -> void:
	var sm: ShaderMaterial
	if mi.material_override is ShaderMaterial:
		sm = mi.material_override as ShaderMaterial
	else:
		sm = (_xqz_mat if through else _vis_mat).duplicate() as ShaderMaterial
		mi.material_override = sm
	sm.set_shader_parameter("albedo", Vector4(c.r, c.g, c.b, c.a))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _std(mi: MeshInstance3D, c: Color) -> void:
	var mat: StandardMaterial3D
	if mi.material_override is StandardMaterial3D:
		mat = mi.material_override as StandardMaterial3D
	else:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mi.material_override = mat
	mat.albedo_color = c
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
