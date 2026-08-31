class_name Player
extends CharacterBody3D
## CS:GO 2018 MM player: Source move, AA, LBY, R8 auto-revolver, plant/defuse.

const TEAM_T := 2
const TEAM_CT := 3
const _Fps := preload("res://src/player/player_fps.gd")
const _Combat := preload("res://src/player/player_combat.gd")
const _Move := preload("res://src/player/player_move.gd")
const _Buy := preload("res://src/player/player_buy.gd")

@export var is_bot := false
@export var is_local := false
@export var team := TEAM_T
@export var player_name := "player"

var health := 100
var armor := 0
var helmet := false
var kit := false
var money := 800
var alive := true
var ducking := false
var duck_amt := 0.0
var scoped := false
var weapon_id := "glock"
var clip := 20
var reserve := 120
var inv: Dictionary = {}
var view_pitch := 0.0
var view_yaw := 0.0
var next_attack := 0.0
var shots_fired := 0
var aa := AntiAim.new()
var resolver := Resolver.new()
var rage: Ragebot
var model: PlayerModel
var cam: Camera3D
var yaw_helper: Node3D
var resolved_yaw := 0.0
var resolved_label := "LBY"
var lag_origin := Vector3.ZERO
var choke := 0
var shot_this_tick := false
var revolver_ready := false
var revolver_ready_at := 0.0
var cocking := false
var planting := false
var plant_left := 0.0
var defusing := false
var defuse_left := 0.0
var kills := 0
var deaths := 0
var damage_dealt := 0
var last_place := ""
var want_autostop := false
var flash := 0.0
var on_ground_was := true
var stamina := 0.0
var hull: CollisionShape3D
var time := 0.0
var foot_cd := 0.0
var last_hurt_from: Player = null
var spawn_origin := Vector3.ZERO
var spawn_yaw := 0.0
var holding_bomb := false
var last_rage: Dictionary = {}
var tracers: Array = []
var bot_wish := Vector3.ZERO
var bot_duck := false
var bot_jump := false
var bot_fire := false
var qa_wish := Vector3.ZERO
var qa_steps := 0
var _origin_prev := Vector3.ZERO
var _origin_curr := Vector3.ZERO
var _cam_fov := 90.0
var viewmodel: MeshInstance3D


func _ready() -> void:
	rage = Ragebot.new(resolver)
	collision_layer = 2
	collision_mask = 1
	floor_stop_on_slope = true
	floor_block_on_wall = false
	floor_max_angle = deg_to_rad(45.573)
	# 8 HU snap rides wall lips; Source sticks with a short ground trace.
	floor_snap_length = Net.hu(2.0)
	safe_margin = 0.001
	max_slides = 4 if OS.has_feature("web") else 6
	# 0° slides around every trimesh corner ("wall suction").
	wall_min_slide_angle = deg_to_rad(15.0)
	set_process(true)
	var hs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(Net.PLAYER_HULL_W, Net.PLAYER_HULL_H, Net.PLAYER_HULL_W)
	hs.shape = box
	hs.position = Vector3(0, Net.PLAYER_HULL_H * 0.5, 0)
	add_child(hs)
	hull = hs
	yaw_helper = Node3D.new()
	add_child(yaw_helper)
	model = PlayerModel.new()
	add_child(model)
	model.setup(self)
	cam = Camera3D.new()
	cam.fov = 90
	cam.near = 0.06
	cam.far = 180 if OS.has_feature("web") else 400
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.top_level = true
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	yaw_helper.add_child(cam)
	cam.position = Vector3(0, Net.EYE_STAND, 0)
	viewmodel = MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.055, 0.07, 0.42)
	viewmodel.mesh = vm
	var vm_mat := StandardMaterial3D.new()
	vm_mat.albedo_color = Color(0.08, 0.08, 0.09)
	vm_mat.roughness = 0.45
	viewmodel.material_override = vm_mat
	viewmodel.position = Vector3(0.16, -0.14, -0.32)
	viewmodel.rotation_degrees = Vector3(4.0, 2.0, 0.0)
	cam.add_child(viewmodel)
	if not is_local:
		cam.current = false
	lag_origin = global_position
	_origin_prev = global_position
	_origin_curr = global_position
	resolved_yaw = view_yaw
	add_to_group("players")


func eye() -> Vector3:
	var h := lerpf(Net.EYE_STAND, Net.EYE_DUCK, duck_amt)
	return global_position + Vector3(0, h, 0)


func head_pos() -> Vector3:
	return eye()


func revolver_cock_frac() -> float:
	var w := Weapons.get_w(weapon_id)
	if not bool(w.get("revolver", false)):
		return 1.0
	if revolver_ready:
		return 1.0
	if not cocking:
		return 0.0
	var cock := float(w.get("cock", 0.207))
	if cock <= 0.001:
		return 1.0
	return clampf(1.0 - (revolver_ready_at - time) / cock, 0.0, 1.0)


func add_money(amt: int) -> void:
	_Buy.add_money(self, amt)


func reset_round(origin: Vector3, yaw: float, give_c4: bool) -> void:
	_Buy.reset_round(self, origin, yaw, give_c4)


func equip(id: String, refill := false) -> void:
	_Buy.equip(self, id, refill)


func can_buy() -> bool:
	return _Buy.can_buy(self)


func buy(id: String) -> bool:
	return _Buy.buy(self, id)


func autobuy() -> void:
	_Buy.autobuy(self)


func _click_is_menu_chrome(mp: Vector2) -> bool:
	var vp := get_viewport().get_visible_rect().size
	if mp.x > vp.x - 110.0 and mp.y > vp.y - 90.0:
		return true
	if mp.y < 36.0 and mp.x > vp.x - 420.0:
		return true
	return false


func _input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not Cheat.menu_open and not Cheat.buy_open:
		if not _click_is_menu_chrome(event.position):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not alive or Cheat.menu_open or Cheat.buy_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_Fps.apply_mouse(self, event)
	if event.is_action_pressed("slot1") and inv.has(1):
		equip(inv[1])
	elif event.is_action_pressed("slot2") and inv.has(2):
		equip(inv[2])
	elif event.is_action_pressed("slot3"):
		equip("knife")
	elif event.is_action_pressed("slot5") and holding_bomb:
		equip("c4")
	elif event.is_action_pressed("thirdperson"):
		Cheat.s("visuals/thirdperson", not bool(Cheat.t("visuals/thirdperson", true)))
	if event.is_action_pressed("aa_left"):
		Cheat.s("aa/manual", 1 if int(Cheat.t("aa/manual", 0)) != 1 else 0)
	if event.is_action_pressed("aa_right"):
		Cheat.s("aa/manual", 2 if int(Cheat.t("aa/manual", 0)) != 2 else 0)
	if event.is_action_pressed("aa_back"):
		Cheat.s("aa/manual", 3 if int(Cheat.t("aa/manual", 0)) != 3 else 0)


func _physics_process(delta: float) -> void:
	time += delta
	shot_this_tick = false
	if not alive:
		velocity = Vector3.ZERO
		return
	var enemies := _enemies()
	aa.on_ground = is_on_floor()
	aa.tick(delta, Vector3(view_pitch, view_yaw, 0), velocity, global_position, enemies, get_world_3d())
	_fakelag()
	_revolver(delta)
	want_autostop = false
	if not is_bot and is_local and Match.in_play():
		last_rage = rage.run(self, enemies, get_world_3d().direct_space_state, time)
		want_autostop = bool(last_rage.get("autostop", false))
		if bool(last_rage.get("scope", false)) and not scoped:
			scoped = true
		if bool(last_rage.get("cock", false)):
			_cock_revolver()
		if bool(last_rage.get("shoot", false)):
			_fire(last_rage.dir, true)
	_move(delta)
	if is_local:
		_origin_prev = _origin_curr
		_origin_curr = global_position
	_use(delta)
	_Combat.attack_manual(self)
	if model:
		model.tick()
	_footsteps(delta)


func _process(dt: float) -> void:
	if is_local:
		_Fps.camera(self, dt)


func _enemies() -> Array:
	var a: Array = []
	for p in get_tree().get_nodes_in_group("players"):
		if p != self:
			a.append(p)
	return a


func _fakelag() -> void:
	if not bool(Cheat.t("aa/fakelag", true)):
		lag_origin = global_position
		choke = 0
		return
	var amt := int(Cheat.t("aa/fakelag_amt", 14)) + randi_range(0, int(Cheat.t("aa/fakelag_var", 2)))
	amt = clampi(amt, 1, 16)
	choke += 1
	if choke >= amt or shot_this_tick:
		lag_origin = global_position
		choke = 0


func _revolver(delta: float) -> void:
	var w := Weapons.get_w(weapon_id)
	if not bool(w.get("revolver", false)):
		revolver_ready = true
		cocking = false
		return
	if cocking:
		revolver_ready = time >= revolver_ready_at
	else:
		revolver_ready = false


func _cock_revolver() -> void:
	var w := Weapons.get_w(weapon_id)
	if not bool(w.get("revolver", false)):
		return
	if not cocking:
		cocking = true
		revolver_ready = false
		revolver_ready_at = time + float(w.get("cock", 0.207))
		Sfx.play("res://assets/sounds/weapons/revolver_cock.wav", global_position, -4)


func _fire(dir: Vector3, silent: bool, r8_alt := false) -> void:
	_Combat.fire(self, dir, silent, r8_alt)


func _tracer(from: Vector3, to: Vector3) -> void:
	if not bool(Cheat.t("visuals/tracers", true)):
		return
	tracers.append({"a": from, "b": to, "t": 0.25})


func take_damage(dmg: int, group: String, attacker: Player, w: Dictionary) -> void:
	if not alive:
		return
	if group == "head" and helmet:
		helmet = false
	elif armor > 0 and group != "leg":
		armor = maxi(0, armor - int(dmg * 0.5))
	health -= dmg
	if attacker:
		attacker.damage_dealt += dmg
		last_hurt_from = attacker
	if bool(Cheat.t("misc/hitsound", true)) and attacker and attacker.is_local:
		Sfx.play2d("res://assets/sounds/sfx/headshot.wav" if group == "head" else "res://assets/sounds/sfx/hit.wav", -4)
	if health <= 0:
		_die(attacker, w, group == "head")


func _die(attacker: Player, w: Dictionary, hs: bool) -> void:
	alive = false
	health = 0
	deaths += 1
	holding_bomb = false
	if attacker and attacker != self:
		attacker.kills += 1
		attacker.add_money(int(w.get("kill", 300)))
		Match.kill_feed.emit(attacker.player_name, player_name, str(w.get("display", w.id)), hs)
	else:
		Match.kill_feed.emit("World", player_name, "suicide", false)
	Sfx.play("res://assets/sounds/sfx/death.wav", global_position, -6)
	model.visible = false


func hitboxes_at_yaw(yaw: float, pitch: float = 0.0) -> Array:
	var f := Net.yaw_vec(yaw)
	var rgt := Net.right_vec(yaw)
	var look := Net.look_dir(pitch, yaw)
	var h := lerpf(Net.PLAYER_HULL_H, Net.PLAYER_DUCK_H, duck_amt)
	var eh := lerpf(Net.EYE_STAND, Net.EYE_DUCK, duck_amt)
	var o := global_position
	# Down pitch 89 drops / drives the head along aim — 2018 AA visual + hitbox.
	var head := o + Vector3(0, eh, 0) + look * 0.12
	return [
		{"group": "head", "pos": head, "radius": Net.HEAD_R},
		{"group": "chest", "pos": o + Vector3(0, h * 0.68, 0) + f * 0.03, "radius": 0.16},
		{"group": "stomach", "pos": o + Vector3(0, h * 0.48, 0), "radius": 0.15},
		{"group": "pelvis", "pos": o + Vector3(0, h * 0.32, 0), "radius": 0.14},
		{"group": "arms", "pos": o + Vector3(0, h * 0.62, 0) + rgt * 0.22, "radius": 0.08},
		{"group": "arms", "pos": o + Vector3(0, h * 0.62, 0) - rgt * 0.22, "radius": 0.08},
		{"group": "legs", "pos": o + Vector3(0, h * 0.18, 0) + rgt * 0.08, "radius": 0.09},
		{"group": "legs", "pos": o + Vector3(0, h * 0.18, 0) - rgt * 0.08, "radius": 0.09},
	]


func _move(delta: float) -> void:
	_Move.step(self, delta)


func _use(delta: float) -> void:
	if weapon_id == "c4" and holding_bomb and team == TEAM_T:
		var site := _on_site()
		if site != "" and (is_bot or (is_local and Input.is_action_pressed("use"))):
			if not planting:
				planting = true
				plant_left = 3.2
			plant_left -= delta
			if plant_left <= 0.0:
				planting = false
				holding_bomb = false
				equip(inv.get(1, inv.get(2, "glock")))
				Match.plant(site, global_position, self)
				Sfx.play("res://assets/sounds/sfx/bomb_plant.wav", global_position)
		else:
			planting = false
	else:
		planting = false
	if team == TEAM_CT and Match.bomb_planted and global_position.distance_to(Match.bomb_pos) < 1.2:
		if is_bot or (is_local and Input.is_action_pressed("use")):
			if not defusing:
				defusing = true
				defuse_left = 5.0 if kit else 10.0
				Match.defusing = true
			defuse_left -= delta
			if defuse_left <= 0.0:
				defusing = false
				Match.defuse_done()
		else:
			defusing = false
	else:
		if defusing:
			defusing = false
			Match.defusing = false


func _on_site() -> String:
	var world = get_tree().get_first_node_in_group("map_world")
	if world and world.has_method("site_at"):
		return world.site_at(global_position)
	return ""


func _footsteps(delta: float) -> void:
	foot_cd -= delta
	var spd := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and spd > 1.2 and foot_cd <= 0.0:
		foot_cd = 0.38
		Sfx.play("res://assets/sounds/sfx/foot%d.wav" % (randi_range(1, 4)), global_position, -14)
	var kept: Array = []
	for tr in tracers:
		tr.t -= delta
		if tr.t > 0.0:
			kept.append(tr)
	tracers = kept
