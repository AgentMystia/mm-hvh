class_name Player
extends CharacterBody3D
## CS:GO 2018 MM player: Source move, AA, LBY, R8 auto-revolver, plant/defuse.

const TEAM_T := 2
const TEAM_CT := 3

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


func _ready() -> void:
	rage = Ragebot.new(resolver)
	collision_layer = 2
	collision_mask = 1
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(46)
	floor_snap_length = 0.12
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
	cam.near = 0.05
	cam.far = 400
	yaw_helper.add_child(cam)
	cam.position = Vector3(0, Net.EYE_STAND, 0)
	if not is_local:
		cam.current = false
	lag_origin = global_position
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
	money = clampi(money + amt, 0, Match.MAX_MONEY)
	Match.money_changed.emit()


func reset_round(origin: Vector3, yaw: float, give_c4: bool) -> void:
	alive = true
	health = 100
	planting = false
	defusing = false
	scoped = false
	shots_fired = 0
	velocity = Vector3.ZERO
	global_position = origin
	spawn_origin = origin
	view_yaw = yaw
	spawn_yaw = yaw
	lag_origin = origin
	visible = true
	cocking = false
	revolver_ready = false
	holding_bomb = give_c4
	if Match.is_pistol_round() or Match.total_rounds <= 1:
		armor = 0
		helmet = false
		kit = false
		inv.clear()
		equip(Weapons.default_pistol(team), true)
		money = Match.OT_MONEY if Match.overtime else Match.START_MONEY
	else:
		if not inv.has(2):
			equip(Weapons.default_pistol(team), true)
		if inv.has(1):
			equip(inv[1], false)
		else:
			equip(Weapons.default_pistol(team), true)
	if give_c4:
		inv[5] = "c4"
	aa.reset()
	model.visible = true


func equip(id: String, refill := false) -> void:
	var w := Weapons.get_w(id)
	weapon_id = id
	inv[int(w.slot)] = id
	if refill or clip <= 0:
		clip = int(w.clip)
		reserve = int(w.ammo)
	shots_fired = 0
	scoped = false
	cocking = false
	revolver_ready = false


func can_buy() -> bool:
	return alive and Match.is_buy_time()


func buy(id: String) -> bool:
	if not can_buy():
		return false
	if id == "kevlar":
		if money < 650 or armor >= 100:
			return false
		add_money(-650)
		armor = 100
		return true
	if id == "helmet":
		var cost := 1000 if armor < 100 else 350
		if helmet or money < cost:
			return false
		add_money(-cost)
		armor = 100
		helmet = true
		return true
	if id == "kit":
		if team != TEAM_CT or kit or money < 400:
			return false
		add_money(-400)
		kit = true
		return true
	var w := Weapons.get_w(id)
	if Match.is_pistol_round() and w.get("type") == "sniper":
		return false
	if w.has("team") and int(w.team) != 0 and int(w.team) != team:
		return false
	if money < int(w.price):
		return false
	add_money(-int(w.price))
	equip(id, true)
	Sfx.play2d("res://assets/sounds/sfx/buy.wav", -6)
	return true


func autobuy() -> void:
	if not bool(Cheat.t("misc/autobuy", true)) and not is_bot:
		return
	if not can_buy():
		return
	if bool(Cheat.t("misc/autobuy_armor", true)) or is_bot:
		if money >= 1000 and not helmet:
			buy("helmet")
		elif money >= 650 and armor < 100:
			buy("kevlar")
		if team == TEAM_CT and not kit and money >= 400 and not Match.is_pistol_round():
			buy("kit")
	if Match.is_pistol_round():
		var pid := str(Cheat.t("misc/autobuy_pistol", "r8"))
		if is_bot:
			pid = ["r8", "deagle", "elite"][absi(player_name.hash()) % 3]
		if not buy(pid):
			if not buy("deagle"):
				buy("elite")
		return
	var sn := str(Cheat.t("misc/autobuy_sniper", "awp"))
	if is_bot:
		sn = ["awp", "ssg08", "auto"][absi(player_name.hash()) % 3]
	if sn == "auto":
		sn = "g3sg1" if team == TEAM_T else "scar20"
	if not buy(sn):
		if not buy("awp"):
			if not buy("ssg08"):
				if not buy("r8"):
					buy("deagle")


func _input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseButton and event.pressed and not Cheat.menu_open and not Cheat.buy_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not alive or Cheat.menu_open or Cheat.buy_open:
		return
	if event is InputEventMouseMotion:
		var sens := 0.022 * 2.2
		view_yaw = Net.ang_norm(view_yaw - event.relative.x * sens)
		view_pitch = clampf(view_pitch - event.relative.y * sens, -89.0, 89.0)
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
	_use(delta)
	_attack_manual()
	_camera()
	if model:
		model.tick()
	_footsteps(delta)


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
		if time >= revolver_ready_at:
			revolver_ready = true
		else:
			revolver_ready = false
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


func _attack_manual() -> void:
	if is_bot or Cheat.menu_open or Cheat.buy_open or not is_local:
		return
	if not Match.in_play() and Match.phase != Match.Phase.FREEZE:
		return
	var w := Weapons.get_w(weapon_id)
	if bool(w.get("revolver", false)) and bool(Cheat.t("rage/auto_revolver", true)) and bool(Cheat.t("rage/enable", true)):
		return  # ragebot owns the R8
	if Input.is_action_just_pressed("altfire") and bool(w.get("zoom", false)):
		scoped = not scoped
		Sfx.play2d("res://assets/sounds/sfx/scope.wav", -8)
	if Input.is_action_pressed("fire"):
		if bool(w.get("revolver", false)):
			_cock_revolver()
			if revolver_ready:
				_fire(-yaw_helper.global_transform.basis.z, false)
				cocking = false
				revolver_ready = false
		else:
			_fire(-yaw_helper.global_transform.basis.z, false)
	else:
		if bool(w.get("revolver", false)):
			cocking = false
			revolver_ready = false
	if Input.is_action_pressed("altfire") and bool(w.get("revolver", false)):
		# R8 fan-fire (inaccurate).
		var tmp_ready := revolver_ready
		revolver_ready = true
		_fire(-yaw_helper.global_transform.basis.z, false, true)
		revolver_ready = tmp_ready
	if Input.is_action_pressed("reload"):
		_reload()


func _reload() -> void:
	var w := Weapons.get_w(weapon_id)
	if clip >= int(w.clip) or reserve <= 0:
		return
	var need := int(w.clip) - clip
	var take := mini(need, reserve)
	clip += take
	reserve -= take
	next_attack = time + 2.2
	shots_fired = 0


func _fire(dir: Vector3, silent: bool, r8_alt := false) -> void:
	if not alive or time < next_attack:
		return
	if Match.phase == Match.Phase.FREEZE or Match.phase == Match.Phase.WARMUP:
		return
	var w := Weapons.get_w(weapon_id)
	if weapon_id == "knife":
		_knife(dir)
		return
	if weapon_id == "c4":
		return
	if clip <= 0:
		Sfx.play(str(w.snd).replace("ak47-1", "dryfire_rifle") if false else "res://assets/sounds/weapons/dryfire_rifle.wav", global_position, -4)
		return
	if bool(w.get("revolver", false)) and not r8_alt and not revolver_ready:
		return
	clip -= 1
	shot_this_tick = true
	aa.broke_this_tick = false
	var cycle := float(w.cycle)
	if r8_alt:
		cycle = float(w.get("alt_cycle", 0.166))
	next_attack = time + cycle
	var spread := float(w.spread)
	if r8_alt:
		spread = float(w.get("alt_spread", 3.2))
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd > 0.3:
		spread += 1.6
	if not is_on_floor():
		spread += 4.0
	if bool(w.get("zoom", false)) and not scoped:
		spread += 10.0
	var rec: Array = w.recoil
	if shots_fired < rec.size():
		var r: Vector2 = rec[shots_fired]
		if not silent:
			view_pitch = clampf(view_pitch + r.x * 0.35, -89, 89)
			view_yaw = Net.ang_norm(view_yaw + r.y * 0.35)
	shots_fired += 1
	# Inaccuracy cone
	dir = _spread_dir(dir, spread)
	Sfx.play(str(w.snd), global_position, -2)
	var from := eye()
	var to := from + dir * 180.0
	var space := get_world_3d().direct_space_state
	var walls := Hitscan.walls_to(space, from, to, [get_rid()])
	if not bool(walls.reached) and not bool(Cheat.t("rage/autowall", true)):
		_tracer(from, to)
		return
	var walln: int = int(walls.walls)
	var hit_someone := false
	for p in _enemies():
		if not p.alive or p.team == team:
			continue
		var boxes: Array = p.hitboxes_at_yaw(p.aa.real_yaw)
		var hit: Dictionary = Hitscan.closest_hitbox(from, to, boxes)
		if hit.is_empty():
			continue
		var dmg := Weapons.damage_vs(w, str(hit.group), p.armor > 0, p.helmet, from.distance_to(hit.hit))
		if walln > 0:
			dmg = int(dmg * (0.62 if walln == 1 else 0.3))
		if dmg <= 0:
			continue
		p.take_damage(dmg, str(hit.group), self, w)
		hit_someone = true
		if p.health <= 0:
			resolver.hit(p)
		break
	if not hit_someone and last_rage.get("target", null) != null:
		var t = last_rage.target
		if t and is_instance_valid(t):
			resolver.miss(t)
	_tracer(from, to if not hit_someone else from + dir * from.distance_to(to) * 0.5)
	cocking = false
	revolver_ready = false


func _knife(dir: Vector3) -> void:
	next_attack = time + 0.4
	Sfx.play("res://assets/sounds/weapons/knife_slash1.wav", global_position, -4)
	var from := eye()
	var to := from + dir * 1.6
	for p in _enemies():
		if p.alive and p.team != team and p.global_position.distance_to(global_position) < 1.8:
			p.take_damage(65, "chest", self, Weapons.get_w("knife"))
			return


func _spread_dir(dir: Vector3, spread_deg: float) -> Vector3:
	var rx := deg_to_rad(randf_range(-spread_deg, spread_deg) * 0.15)
	var ry := deg_to_rad(randf_range(-spread_deg, spread_deg) * 0.15)
	var basis := Net.look_basis(dir)
	return (basis * Vector3(sin(ry), sin(rx), -1)).normalized()


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


func hitboxes_at_yaw(yaw: float) -> Array:
	var f := Net.yaw_vec(yaw)
	var rgt := Vector3(f.z, 0, -f.x)
	var h := lerpf(Net.PLAYER_HULL_H, Net.PLAYER_DUCK_H, duck_amt)
	var eh := lerpf(Net.EYE_STAND, Net.EYE_DUCK, duck_amt)
	var o := global_position
	return [
		{"group": "head", "pos": o + Vector3(0, eh, 0) + f * 0.05, "radius": Net.HEAD_R},
		{"group": "chest", "pos": o + Vector3(0, h * 0.68, 0) + f * 0.03, "radius": 0.16},
		{"group": "stomach", "pos": o + Vector3(0, h * 0.48, 0), "radius": 0.15},
		{"group": "pelvis", "pos": o + Vector3(0, h * 0.32, 0), "radius": 0.14},
		{"group": "arms", "pos": o + Vector3(0, h * 0.62, 0) + rgt * 0.22, "radius": 0.08},
		{"group": "arms", "pos": o + Vector3(0, h * 0.62, 0) - rgt * 0.22, "radius": 0.08},
		{"group": "legs", "pos": o + Vector3(0, h * 0.18, 0) + rgt * 0.08, "radius": 0.09},
		{"group": "legs", "pos": o + Vector3(0, h * 0.18, 0) - rgt * 0.08, "radius": 0.09},
	]


func _move(delta: float) -> void:
	var wish := Vector3.ZERO
	if is_local and not Cheat.menu_open and not Cheat.buy_open and not is_bot:
		var f := Input.get_axis("move_back", "move_forward")
		var s := Input.get_axis("move_left", "move_right")
		var fwd := Net.yaw_vec(view_yaw)
		var rgt := Vector3(fwd.z, 0, -fwd.x)
		wish = (fwd * f + rgt * s)
		if wish.length() > 1:
			wish = wish.normalized()
		ducking = Input.is_action_pressed("duck") or bool(Cheat.t("aa/fakeduck", false))
		if bool(Cheat.t("misc/bhop", true)):
			if Input.is_action_pressed("jump") and is_on_floor():
				velocity.y = Net.JUMP_IMPULSE
		elif Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = Net.JUMP_IMPULSE
	# bot wish is set externally via bot_wish
	if is_bot:
		wish = bot_wish
		ducking = bot_duck
		if bot_jump and is_on_floor():
			velocity.y = Net.JUMP_IMPULSE
	if want_autostop or (is_local and bool(Cheat.t("rage/autostop", true)) and last_rage.get("shoot", false)):
		wish = Vector3.ZERO
		velocity.x *= 0.4
		velocity.z *= 0.4
	if bool(Cheat.t("aa/slowwalk", false)):
		wish *= float(Cheat.t("aa/slowwalk_spd", 80)) / 250.0
	duck_amt = move_toward(duck_amt, 1.0 if ducking else 0.0, delta / 0.2)
	var w := Weapons.get_w(weapon_id)
	var maxsp := Net.hu(float(w.move))
	if scoped and w.has("scoped_speed"):
		maxsp = Net.hu(float(w.scoped_speed))
	if duck_amt > 0.5:
		maxsp *= 0.34
	if Match.phase == Match.Phase.FREEZE or Match.phase == Match.Phase.WARMUP or Match.phase == Match.Phase.ROUND_END or Match.phase == Match.Phase.MATCH_END:
		wish = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0
	if is_local and bool(Cheat.t("misc/autostrafe", 0)) and not is_on_floor():
		wish = _autostrafe()
	if is_on_floor():
		_friction(delta)
		_accelerate(wish, maxsp, Net.ACCELERATE, delta)
	else:
		_accelerate(wish, minf(maxsp, Net.AIR_CAP), Net.AIRACCELERATE, delta)
		velocity.y -= Net.GRAVITY * delta
	hull.shape.size = Vector3(Net.PLAYER_HULL_W, lerpf(Net.PLAYER_HULL_H, Net.PLAYER_DUCK_H, duck_amt), Net.PLAYER_HULL_W)
	hull.position.y = hull.shape.size.y * 0.5
	move_and_slide()


var bot_wish := Vector3.ZERO
var bot_duck := false
var bot_jump := false
var bot_fire := false


func _autostrafe() -> Vector3:
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd < 0.01:
		return Net.yaw_vec(view_yaw)
	var wish_ang := atan2(-velocity.x, -velocity.z) + (0.3 if Input.get_axis("move_left", "move_right") >= 0 else -0.3)
	return Vector3(-sin(wish_ang), 0, -cos(wish_ang))


func _friction(delta: float) -> void:
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd < 0.01:
		return
	var drop := 0.0
	var control := Net.STOP_SPEED if spd < Net.STOP_SPEED else spd
	drop += control * Net.FRICTION * delta
	var ns := maxf(spd - drop, 0)
	if ns != spd:
		var f := ns / spd
		velocity.x *= f
		velocity.z *= f


func _accelerate(wish: Vector3, wishspd: float, accel: float, delta: float) -> void:
	if wish.length() < 0.01:
		return
	wish = wish.normalized()
	var curs := velocity.dot(wish)
	var add := wishspd - curs
	if add <= 0:
		return
	var acc := accel * wishspd * delta
	if acc > add:
		acc = add
	velocity += wish * acc


func _camera() -> void:
	if not is_local:
		return
	cam.current = true
	var fov := float(Cheat.t("visuals/fov", 110))
	if scoped:
		fov = float(Weapons.get_w(weapon_id).get("zoom_fov", 40))
	cam.fov = fov
	var eye_h := lerpf(Net.EYE_STAND, Net.EYE_DUCK, duck_amt)
	var fwd := Net.yaw_vec(view_yaw)
	var look := fwd * cos(deg_to_rad(view_pitch)) + Vector3(0, -sin(deg_to_rad(view_pitch)), 0)
	if look.length_squared() < 0.0001:
		look = fwd
	look = look.normalized()
	var up := Vector3.UP
	if absf(look.dot(up)) > 0.995:
		up = Vector3.RIGHT
	var tp := bool(Cheat.t("visuals/thirdperson", true))
	if tp:
		var dist := float(Cheat.t("visuals/tp_dist", 120)) * Net.HU
		var focus := global_position + Vector3(0, eye_h, 0)
		cam.global_position = focus - look * dist + Vector3(0, 0.18, 0)
		var target := focus + look * 2.0
		if cam.global_position.distance_to(target) > 0.05:
			cam.look_at(target, up)
	else:
		yaw_helper.rotation = Vector3.ZERO
		cam.position = Vector3(0, eye_h, 0)
		var target2 := cam.global_position + look * 4.0
		if cam.global_position.distance_to(target2) > 0.05:
			cam.look_at(target2, up)


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
