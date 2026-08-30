class_name MapWorld
extends Node3D
## Loads converted CS:GO de_mirage (VBSP v21) plus bomb sites, spawns, cover props.

var ents: Dictionary = {}
var t_spawns: Array = []
var ct_spawns: Array = []
var sites: Array = []
var radar_tex: Texture2D
var sun: DirectionalLight3D
var env: WorldEnvironment


func _ready() -> void:
	add_to_group("map_world")
	_load_ents()
	_mesh()
	_collision()
	_props()
	_sites()
	_env()


func _load_ents() -> void:
	var f := FileAccess.open("res://assets/maps/de_mirage/entities.json", FileAccess.READ)
	if f == null:
		push_error("missing entities.json")
		return
	ents = JSON.parse_string(f.get_as_text())
	t_spawns = ents.get("t_spawns", [])
	ct_spawns = ents.get("ct_spawns", [])
	sites = ents.get("bomb_sites", [])
	if ResourceLoader.exists("res://assets/maps/de_mirage/radar.png"):
		radar_tex = load("res://assets/maps/de_mirage/radar.png")


func _mesh() -> void:
	var loaded := false
	if ResourceLoader.exists("res://assets/maps/de_mirage/de_mirage.glb"):
		var packed = load("res://assets/maps/de_mirage/de_mirage.glb")
		if packed is PackedScene:
			var inst := (packed as PackedScene).instantiate()
			inst.name = "MirageMesh"
			add_child(inst)
			loaded = true
	if not loaded:
		_mesh_from_obj()
	_collision_mesh()


func _mesh_from_obj() -> void:
	if not ResourceLoader.exists("res://assets/maps/de_mirage/collision.obj"):
		_fallback_ground()
		return
	var mi := MeshInstance3D.new()
	mi.name = "MirageMesh"
	var mesh = load("res://assets/maps/de_mirage/collision.obj")
	if mesh is Mesh:
		mi.mesh = mesh
	elif mesh is PackedScene:
		add_child((mesh as PackedScene).instantiate())
		return
	else:
		_fallback_ground()
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.62, 0.48)
	mat.roughness = 0.9
	mi.material_override = mat
	add_child(mi)
	_make_trimesh(mi)


func _make_trimesh(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.create_trimesh_collision()
		# StaticBody children: layer 1
		for c in mi.get_children():
			if c is StaticBody3D:
				(c as StaticBody3D).collision_layer = 1
				(c as StaticBody3D).collision_mask = 0
	for c in n.get_children():
		_make_trimesh(c)


func _collision() -> void:
	pass


func _collision_mesh() -> void:
	if not ResourceLoader.exists("res://assets/maps/de_mirage/collision.obj"):
		return
	var mi := MeshInstance3D.new()
	mi.name = "MirageCollision"
	mi.visible = false
	var mesh = load("res://assets/maps/de_mirage/collision.obj")
	if mesh is Mesh:
		mi.mesh = mesh
		add_child(mi)
		mi.create_trimesh_collision()
		for c in mi.get_children():
			if c is StaticBody3D:
				(c as StaticBody3D).collision_layer = 1
				(c as StaticBody3D).collision_mask = 0


func _fallback_ground() -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(80, 1, 80)
	mi.mesh = box
	add_child(mi)
	mi.create_trimesh_collision()


func _props() -> void:
	var list: Array = ents.get("props", [])
	var n := 0
	for p in list:
		var o: Array = p.origin
		if absf(float(o[1])) > 12.0 or absf(float(o[0])) > 90.0 or absf(float(o[2])) > 90.0:
			continue
		n += 1
		if n > 180:
			break
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		var sz: Array = p.get("size", [0.6, 0.8, 0.6])
		sh.size = Vector3(sz[0], sz[1], sz[2])
		cs.shape = sh
		cs.position = Vector3(0, sz[1] * 0.5, 0)
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sh.size
		mi.mesh = bm
		mi.position = cs.position
		var mat := StandardMaterial3D.new()
		var nm := str(p.get("name", "")).to_lower()
		if "van" in nm or "truck" in nm:
			mat.albedo_color = Color(0.35, 0.38, 0.22)
		elif "wood" in nm or "crate" in nm:
			mat.albedo_color = Color(0.45, 0.32, 0.18)
		else:
			mat.albedo_color = Color(0.5, 0.46, 0.38)
		mi.material_override = mat
		body.add_child(mi)
		body.position = Vector3(o[0], o[1], o[2])
		body.rotation_degrees = Vector3(p.get("pitch", 0), p.get("yaw", 0), p.get("roll", 0))
		add_child(body)


func _sites() -> void:
	for s in sites:
		var a := Area3D.new()
		a.name = "Site" + str(s.get("name", "?"))
		a.collision_layer = 16
		a.collision_mask = 0
		a.monitoring = false
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var mn: Array = s.mins
		var mx: Array = s.maxs
		var size := Vector3(absf(mx[0] - mn[0]), maxf(absf(mx[1] - mn[1]), 1.6), absf(mx[2] - mn[2]))
		box.size = size
		cs.shape = box
		a.add_child(cs)
		var c: Array = s.center
		a.position = Vector3(c[0], c[1] + size.y * 0.35, c[2])
		a.set_meta("site", str(s.get("name", "A")))
		add_child(a)
		# plant marker
		var mark := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.55
		cyl.bottom_radius = 0.55
		cyl.height = 0.04
		mark.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.15, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.05, 0.02)
		mark.material_override = mat
		mark.position = Vector3(c[0], c[1] + 0.05, c[2])
		add_child(mark)


func _env() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.62, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.64, 0.52)
	e.ambient_light_energy = 0.55
	e.fog_enabled = true
	e.fog_light_color = Color(0.62, 0.7, 0.78)
	e.fog_density = 0.004
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.shadow_enabled = true
	add_child(sun)
	_apply_night()
	Cheat.changed.connect(_apply_night)
	_safety_floor()


func _safety_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(140, 1.0, 140)
	cs.shape = box
	body.add_child(cs)
	body.position = Vector3(-10, -9.0, 25)
	add_child(body)


func _apply_night() -> void:
	if env == null:
		return
	var nm := bool(Cheat.t("visuals/nightmode", true))
	var amt := float(Cheat.t("visuals/night_amt", 40)) / 100.0
	if nm:
		env.environment.ambient_light_energy = lerpf(0.55, 0.12, amt)
		sun.light_energy = lerpf(1.15, 0.18, amt)
		env.environment.background_color = Color(0.45, 0.62, 0.82).lerp(Color(0.05, 0.06, 0.08), amt)
	else:
		env.environment.ambient_light_energy = 0.55
		sun.light_energy = 1.15
		env.environment.background_color = Color(0.45, 0.62, 0.82)


func site_at(pos: Vector3) -> String:
	for s in sites:
		var mn: Array = s.mins
		var mx: Array = s.maxs
		if pos.x >= mn[0] - 0.4 and pos.x <= mx[0] + 0.4 and pos.z >= mn[2] - 0.4 and pos.z <= mx[2] + 0.4:
			return str(s.get("name", "A"))
	return ""


func spawn_for(team: int, slot: int) -> Dictionary:
	var arr: Array = t_spawns if team == Match.Team.T else ct_spawns
	if arr.is_empty():
		return {"origin": [0, 1, 0], "angles": [0, 0, 0]}
	return arr[slot % arr.size()]


func world_to_radar(pos: Vector3) -> Vector2:
	var r: Dictionary = ents.get("radar", {})
	var mn: Array = r.get("min", [-64.0, -20.0])
	var mx: Array = r.get("max", [44.0, 70.0])
	var ux := clampf((pos.x - float(mn[0])) / maxf(float(mx[0]) - float(mn[0]), 0.001), 0.0, 1.0)
	var uz := clampf((pos.z - float(mn[1])) / maxf(float(mx[1]) - float(mn[1]), 0.001), 0.0, 1.0)
	return Vector2(ux, 1.0 - uz)
