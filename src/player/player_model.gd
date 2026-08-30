class_name PlayerModel
extends Node3D
## CS:GO-style player: legs at LBY, fake-yaw body, real-yaw ghost (local TP).
## Enemies render at resolver true-yaw (chams/skeleton follow resolve).

var player: Player
var legs: MeshInstance3D
var body_fake: MeshInstance3D
var body_real: MeshInstance3D
var head_fake: MeshInstance3D
var head_real: MeshInstance3D
var xqz: MeshInstance3D
var weapon_mesh: MeshInstance3D
var _xqz_mat: ShaderMaterial
var _vis_mat: ShaderMaterial
var _fake_mat: ShaderMaterial
var _real_mat: ShaderMaterial
var _lby_mat: ShaderMaterial


func setup(p: Player) -> void:
	player = p
	_xqz_mat = _shd("res://assets/shaders/chams_xqz.gdshader")
	_vis_mat = _shd("res://assets/shaders/chams_vis.gdshader")
	_fake_mat = _shd("res://assets/shaders/chams_vis.gdshader")
	_real_mat = _shd("res://assets/shaders/chams_vis.gdshader")
	_lby_mat = _shd("res://assets/shaders/chams_vis.gdshader")
	legs = _part(Vector3(0.32, 0.7, 0.22), Vector3(0, 0.35, 0))
	body_fake = _part(Vector3(0.38, 0.55, 0.22), Vector3(0, 1.05, 0))
	head_fake = _part(Vector3(0.22, 0.22, 0.22), Vector3(0, 1.52, 0), true)
	body_real = _part(Vector3(0.36, 0.52, 0.20), Vector3(0, 1.05, 0))
	head_real = _part(Vector3(0.20, 0.20, 0.20), Vector3(0, 1.52, 0), true)
	xqz = _part(Vector3(0.42, 1.55, 0.26), Vector3(0, 0.85, 0))
	weapon_mesh = _gun()
	body_fake.add_child(weapon_mesh)
	add_child(legs)
	add_child(body_fake)
	add_child(head_fake)
	add_child(body_real)
	add_child(head_real)
	add_child(xqz)


func _shd(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m


func _part(size: Vector3, pos: Vector3, sphere := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if sphere:
		var s := SphereMesh.new()
		s.radius = size.x * 0.5
		s.height = size.y
		s.radial_segments = 10
		s.rings = 6
		mi.mesh = s
	else:
		var b := BoxMesh.new()
		b.size = size
		mi.mesh = b
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mi.material_override = mat
	return mi


func _gun() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.06, 0.08, 0.55)
	mi.mesh = b
	mi.position = Vector3(0.18, 0.05, -0.28)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.12)
	mi.material_override = mat
	return mi


func _team_color() -> Color:
	return Color(0.72, 0.52, 0.22) if player.team == Match.Team.T else Color(0.35, 0.48, 0.38)


func tick() -> void:
	if player == null:
		return
	visible = player.alive
	if not player.alive:
		return
	var local := player.is_local
	var tp := bool(Cheat.t("visuals/thirdperson", true))
	var show_local := local and tp
	# Hide first-person body for local unless thirdperson.
	if local and not tp:
		visible = false
		return
	visible = true
	var duck := player.duck_amt
	scale.y = lerpf(1.0, 0.72, duck)
	var team_c := _team_color()
	# Enemy: main body at RESOLVED true yaw (what ragebot shoots).
	# Optional fake ghost at networked fake yaw.
	if not local:
		var use_res := bool(Cheat.t("visuals/chams_resolved", true))
		var vis_yaw := player.resolved_yaw if use_res else player.aa.fake_yaw
		_pose_on(body_fake, vis_yaw, player.aa.real_pitch * 0.4)
		_pose_on(head_fake, vis_yaw, player.aa.real_pitch)
		_pose_on(legs, player.aa.lby, 0.0)
		_pose_on(xqz, vis_yaw, player.aa.real_pitch * 0.35)
		body_real.visible = bool(Cheat.t("visuals/chams_fake", true))
		head_real.visible = body_real.visible
		if body_real.visible:
			_pose_on(body_real, player.aa.fake_yaw, player.aa.real_pitch * 0.25)
			_pose_on(head_real, player.aa.fake_yaw, player.aa.real_pitch)
			_apply(body_real, _col("visuals/chams_fake_col", Color(0.25, 0.45, 1, 0.35)), true)
			_apply(head_real, _col("visuals/chams_fake_col", Color(0.25, 0.45, 1, 0.35)), true)
		var vis_c := _col("visuals/chams_col", Color(0.2, 0.85, 0.35, 1))
		var xqz_c := _col("visuals/chams_xqz_col", Color(0.85, 0.25, 0.55, 1))
		if bool(Cheat.t("visuals/chams", true)):
			_apply(body_fake, vis_c, false)
			_apply(head_fake, vis_c, false)
			_apply(legs, vis_c, false)
		else:
			_std(body_fake, team_c)
			_std(head_fake, team_c.lightened(0.1))
			_std(legs, team_c.darkened(0.15))
		xqz.visible = bool(Cheat.t("visuals/chams_xqz", true))
		if xqz.visible:
			_apply(xqz, xqz_c, true, true)
		return
	# Local thirdperson: Real / Fake / LBY layers (2018 AA debug).
	if not show_local:
		return
	_pose_on(body_fake, player.aa.fake_yaw, player.aa.real_pitch * 0.4)
	_pose_on(head_fake, player.aa.fake_yaw, player.aa.real_pitch)
	_pose_on(body_real, player.aa.real_yaw, player.aa.real_pitch * 0.45)
	_pose_on(head_real, player.aa.real_yaw, player.aa.real_pitch)
	_pose_on(legs, player.aa.lby, 0.0)
	xqz.visible = false
	body_fake.visible = bool(Cheat.t("visuals/local_fake", true)) and bool(Cheat.t("visuals/local_chams", true))
	head_fake.visible = body_fake.visible
	body_real.visible = bool(Cheat.t("visuals/local_real", true)) and bool(Cheat.t("visuals/local_chams", true))
	head_real.visible = body_real.visible
	legs.visible = bool(Cheat.t("visuals/local_lby", true)) and bool(Cheat.t("visuals/local_chams", true))
	if body_fake.visible:
		_apply(body_fake, _col("visuals/local_fake_col", Color(0.2, 0.45, 1, 0.45)), true)
		_apply(head_fake, _col("visuals/local_fake_col", Color(0.2, 0.45, 1, 0.45)), true)
	if body_real.visible:
		_apply(body_real, _col("visuals/local_real_col", Color(1.0, 0.2, 0.2, 0.55)), true)
		_apply(head_real, _col("visuals/local_real_col", Color(1.0, 0.2, 0.2, 0.55)), true)
	if legs.visible:
		_apply(legs, _col("visuals/local_lby_col", Color(1.0, 0.85, 0.15, 0.7)), true)
	if not bool(Cheat.t("visuals/local_chams", true)):
		_std(body_fake, team_c)
		_std(head_fake, team_c)
		_std(legs, team_c.darkened(0.2))
		body_fake.visible = true
		head_fake.visible = true
		legs.visible = true
		body_real.visible = false
		head_real.visible = false


func _pose_on(n: Node3D, yaw: float, pitch: float) -> void:
	# Godot YXZ: +X looks down, matching Source pitch.
	var p := pitch
	if p > 90.0:
		p = 89.0  # fake-down still reads as looking at the dirt
	n.rotation = Vector3(deg_to_rad(p), deg_to_rad(yaw), 0.0)


func _yaw_on(n: Node3D, yaw: float) -> void:
	_pose_on(n, yaw, 0.0)


func _col(path: String, fallback: Color) -> Color:
	var v = Cheat.t(path, null)
	if typeof(v) == TYPE_ARRAY and v.size() >= 3:
		return Color(v[0], v[1], v[2], v[3] if v.size() > 3 else 1.0)
	return fallback


func _apply(mi: MeshInstance3D, c: Color, transparent: bool, through := false) -> void:
	var sm: ShaderMaterial
	if mi.material_override is ShaderMaterial:
		sm = mi.material_override as ShaderMaterial
	else:
		sm = (_xqz_mat if through else _vis_mat).duplicate() as ShaderMaterial
		mi.material_override = sm
	sm.set_shader_parameter("albedo", Vector4(c.r, c.g, c.b, c.a))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if transparent else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _std(mi: MeshInstance3D, c: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.85
	mi.material_override = mat
