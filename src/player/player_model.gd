class_name PlayerModel
extends Node3D
## CS:GO 2018 dummy. Pitch-down 89 folds the spine so the head sits below the shoulders.

var player: Player
var rig_vis: Node3D
var rig_fake: Node3D
var rig_lby: Node3D
var rig_xqz: Node3D
var _xqz_mat: ShaderMaterial
var _vis_mat: ShaderMaterial
var axis_real: Node3D
var axis_fake: Node3D
var axis_lby: Node3D


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
	axis_real = _yaw_axis(Color(1.0, 0.22, 0.16), 1.85, 0.48)
	axis_fake = _yaw_axis(Color(0.22, 0.48, 1.0), 1.45, 0.40)
	axis_lby = _yaw_axis(Color(1.0, 0.86, 0.14), 1.10, 0.32)
	axis_real.name = "axis_real"
	axis_fake.name = "axis_fake"
	axis_lby.name = "axis_lby"
	add_child(axis_real)
	add_child(axis_fake)
	add_child(axis_lby)


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
		root.add_child(_mi(_box(Vector3(0.30, 0.14, 0.18)), Vector3(0, 0.90, 0.01), "pants"))
		for s in [-1.0, 1.0]:
			root.add_child(_mi(_cyl(0.068, 0.40), Vector3(0.10 * s, 0.66, 0.01), "pants"))
			root.add_child(_mi(_cyl(0.052, 0.36), Vector3(0.10 * s, 0.30, 0.02), "pants"))
			root.add_child(_mi(_box(Vector3(0.11, 0.07, 0.24)), Vector3(0.10 * s, 0.045, 0.05), "boot"))
		var knife := _mi(_box(Vector3(0.03, 0.22, 0.05)), Vector3(0.18, 0.52, 0.04), "gun")
		knife.name = "knife"
		root.add_child(knife)
	if legs_only:
		return root
	var spine := Node3D.new()
	spine.name = "spine"
	spine.position = Vector3(0, 0.96, 0)
	root.add_child(spine)
	var stomach := _mi(_box(Vector3(0.32, 0.22, 0.18)), Vector3(0, 0.10, 0.03), "shirt")
	stomach.name = "stomach"
	spine.add_child(stomach)
	var chest := _mi(_box(Vector3(0.40, 0.28, 0.20)), Vector3(0, 0.30, 0.05), "shirt")
	chest.name = "chest"
	spine.add_child(chest)
	var neck := _mi(_cyl(0.046, 0.10), Vector3(0, 0.46, 0.00), "skin")
	spine.add_child(neck)
	# Head sits forward of the neck so a 89° spine fold drops it *below* the shoulders.
	var head := _mi(_sph(0.118), Vector3(0, 0.58, -0.10), "skin")
	head.name = "head"
	spine.add_child(head)
	var helm := _mi(_sph(0.125), Vector3(0, 0.60, -0.09), "helm")
	helm.name = "helm"
	spine.add_child(helm)
	for s in [-1.0, 1.0]:
		var shoulder := _mi(_sph(0.062), Vector3(0.22 * s, 0.36, 0.06), "shirt")
		if s < 0.0:
			shoulder.name = "shoulder_l"
		else:
			shoulder.name = "shoulder_r"
		spine.add_child(shoulder)
		var upper := _mi(_cyl(0.044, 0.30), Vector3(0.26 * s, 0.18, 0.02), "shirt")
		upper.rotation_degrees = Vector3(28.0, 0.0, -18.0 * s)
		spine.add_child(upper)
		var fore := _mi(_cyl(0.038, 0.28), Vector3(0.28 * s, -0.02, -0.12), "skin")
		fore.rotation_degrees = Vector3(78.0, 0.0, -6.0 * s)
		spine.add_child(fore)
	if with_gun:
		# AWP along the left of the torso — hunched 89 it lies parallel to the ground.
		var awp := Node3D.new()
		awp.name = "gun"
		awp.position = Vector3(-0.18, 0.14, 0.03)
		awp.add_child(_mi(_box(Vector3(0.045, 0.98, 0.055)), Vector3(0, 0.14, 0.0), "gun"))
		awp.add_child(_mi(_box(Vector3(0.08, 0.16, 0.10)), Vector3(0.0, 0.22, 0.06), "gun"))
		awp.add_child(_mi(_box(Vector3(0.055, 0.12, 0.055)), Vector3(0.0, 0.52, 0.09), "gun"))
		spine.add_child(awp)
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
	var sy := lerpf(1.0, 0.78, player.duck_amt)
	rig_vis.scale.y = sy
	rig_fake.scale.y = sy
	rig_lby.scale.y = sy
	rig_xqz.scale.y = sy
	scale = Vector3.ONE
	if local:
		_tick_local()
	else:
		_tick_enemy()
	_tick_axes()


func _tick_enemy() -> void:
	var use_res := bool(Cheat.t("visuals/chams_resolved", true))
	var vis_yaw := player.resolved_yaw if use_res else player.aa.fake_yaw
	_pose(rig_vis, vis_yaw, player.aa.real_pitch)
	rig_vis.visible = true
	rig_lby.visible = false
	var chams := bool(Cheat.t("visuals/chams", true))
	if chams:
		_paint_chams(rig_vis, _col("visuals/chams_col", Color(0.2, 0.55, 1.0, 1)), false, false)
	else:
		_paint_team(rig_vis)
	rig_fake.visible = bool(Cheat.t("visuals/chams_fake", true))
	if rig_fake.visible:
		_pose(rig_fake, player.aa.fake_yaw, player.aa.real_pitch * 0.15)
		_paint_chams(rig_fake, _col("visuals/chams_fake_col", Color(0.25, 0.45, 1, 0.18)), true, false)
	rig_xqz.visible = bool(Cheat.t("visuals/chams_xqz", true))
	if rig_xqz.visible:
		_pose(rig_xqz, vis_yaw, player.aa.real_pitch)
		_paint_chams(rig_xqz, _col("visuals/chams_xqz_col", Color(0.85, 0.25, 0.55, 1)), true, true)


func _tick_local() -> void:
	var chams := bool(Cheat.t("visuals/local_chams", true))
	rig_vis.visible = (not chams) or bool(Cheat.t("visuals/local_real", true))
	_pose(rig_vis, player.aa.real_yaw, player.aa.real_pitch)
	if chams:
		_paint_chams(rig_vis, _col("visuals/chams_col", Color(0.2, 0.55, 1.0, 1)), false, false)
	else:
		_paint_team(rig_vis)
	rig_fake.visible = chams and bool(Cheat.t("visuals/local_fake", true))
	if rig_fake.visible:
		_pose(rig_fake, player.aa.fake_yaw, player.aa.real_pitch * 0.15)
		_paint_chams(rig_fake, _col("visuals/local_fake_col", Color(0.25, 0.5, 1, 0.16)), true, false)
	rig_lby.visible = chams and bool(Cheat.t("visuals/local_lby", true))
	if rig_lby.visible:
		_pose(rig_lby, player.aa.lby, 0.0)
		_paint_chams(rig_lby, _col("visuals/local_lby_col", Color(1.0, 0.85, 0.15, 0.55)), true, false)
	rig_xqz.visible = false


func _vis_pitch(pitch: float) -> float:
	if pitch > 90.0:
		return 89.0
	return clampf(pitch, -89.0, 89.0)


func _pose(rig: Node3D, yaw: float, pitch: float) -> void:
	rig.rotation = Vector3(0.0, deg_to_rad(yaw), 0.0)
	var p := _vis_pitch(pitch)
	var spine := rig.get_node_or_null("spine") as Node3D
	if spine == null:
		return
	# Fold the whole upper body at the pelvis. 89 down → torso parallel to the floor.
	spine.rotation = Vector3(-deg_to_rad(p) * 0.98, 0.0, 0.0)
	var head := spine.get_node_or_null("head") as Node3D
	var helm := spine.get_node_or_null("helm") as Node3D
	var extra := -deg_to_rad(p) * 0.22
	if head:
		head.rotation = Vector3(extra, 0.0, 0.0)
	if helm:
		helm.rotation = Vector3(extra, 0.0, 0.0)
		helm.visible = player.team == Match.Team.CT or player.helmet


func _yaw_axis(col: Color, length: float, y: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, y, 0.0)
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.04, length)
	bar.mesh = box
	bar.position = Vector3(0.0, 0.0, -length * 0.5)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.material_override = _axis_mat(col)
	pivot.add_child(bar)
	var tip := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.045
	sph.height = 0.09
	sph.radial_segments = 8
	sph.rings = 4
	tip.mesh = sph
	tip.position = Vector3(0.0, 0.0, -length)
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tip.material_override = _axis_mat(col)
	pivot.add_child(tip)
	return pivot


func _axis_mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.albedo_color = col
	mat.no_depth_test = true
	mat.render_priority = 20
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _tick_axes() -> void:
	var show := bool(Cheat.t("visuals/aa_arrows", true))
	if axis_real:
		axis_real.visible = show
	if axis_fake:
		axis_fake.visible = show
	if axis_lby:
		axis_lby.visible = show
	if not show:
		return
	_aim_axis(axis_real, player.aa.real_yaw)
	_aim_axis(axis_fake, player.aa.fake_yaw)
	_aim_axis(axis_lby, player.aa.lby)


func _aim_axis(pivot: Node3D, yaw: float) -> void:
	if pivot == null or player == null:
		return
	var fwd := Net.yaw_vec(yaw)
	var origin: Vector3 = player.global_position + Vector3(0.0, pivot.position.y, 0.0)
	var to: Vector3 = origin + fwd * 2.0
	if origin.distance_squared_to(to) < 0.0001:
		return
	if pivot.is_inside_tree():
		pivot.look_at(to, Vector3.UP)


func qa_pose_line() -> String:
	if rig_vis == null or player == null:
		return "QA pose missing"
	_pose(rig_vis, player.aa.real_yaw, player.aa.real_pitch)
	var spine := rig_vis.get_node_or_null("spine") as Node3D
	if spine == null:
		return "QA pose nodes missing"
	var head := spine.get_node_or_null("head") as Node3D
	var sh := spine.get_node_or_null("shoulder_l") as Node3D
	if head == null or sh == null:
		return "QA pose nodes missing"
	var hy: float = head.global_position.y
	var sy: float = sh.global_position.y
	return "QA pose pitch=%.1f spine_x=%.1f head_y=%.3f shoulder_y=%.3f head_below=%s" % [
		player.aa.real_pitch, rad_to_deg(spine.rotation.x), hy, sy, str(hy < sy - 0.02)
	]


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
