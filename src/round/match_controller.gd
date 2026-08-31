class_name MatchController
extends Node3D
## 5v5 MM competitive loop on de_mirage.

var world: MapWorld
var players: Array[Player] = []
var bots: Array[BotAI] = []
var local_player: Player
var hud: GameHUD
var bomb_node: Node3D
var _qa_frames := 0
var _qa_stair_y0 := 0.0
var _qa_bot0 := Vector3.ZERO
var _qa_wall0 := Vector3.ZERO


func _ready() -> void:
	randomize()
	world = MapWorld.new()
	add_child(world)
	_spawn_players()
	var layer := CanvasLayer.new()
	layer.layer = 20
	hud = preload("res://src/ui/game_hud.gd").new()
	layer.add_child(hud)
	add_child(layer)
	hud.bind(self)
	_make_bomb()
	Match.reset_match()
	Match.round_reset.connect(_on_round_reset)
	Match.phase_changed.connect(_on_phase)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_physics_process(true)


func _make_bomb() -> void:
	bomb_node = Node3D.new()
	bomb_node.visible = false
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.12, 0.34)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.18, 0.12)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.08, 0.04)
	mi.material_override = mat
	bomb_node.add_child(mi)
	add_child(bomb_node)


func _spawn_players() -> void:
	var local_is_t := Match.local_team != Match.Team.CT
	Match.local_team = Match.Team.T if local_is_t else Match.Team.CT
	for i in 10:
		var p := Player.new()
		var t_side := i < 5
		p.team = Match.Team.T if t_side else Match.Team.CT
		p.is_local = (local_is_t and i == 0) or ((not local_is_t) and i == 5)
		p.is_bot = not p.is_local
		p.player_name = "you" if p.is_local else ("T%d" % i if t_side else "CT%d" % (i - 4))
		p.money = Match.START_MONEY
		add_child(p)
		players.append(p)
		if p.is_local:
			local_player = p
		else:
			var ai := BotAI.new()
			ai.setup(p, i)
			bots.append(ai)
	_place_spawns(true)
	for p in players:
		p.autobuy()


func _place_spawns(give_bomb: bool) -> void:
	var ti := 0
	var ci := 0
	var bomber: Player = null
	for p in players:
		var slot := 0
		if p.team == Match.Team.T:
			slot = ti
			ti += 1
		else:
			slot = ci
			ci += 1
		var sp: Dictionary = world.spawn_for(p.team, slot)
		var o: Array = sp.origin
		var origin := world.snap_spawn(Vector3(o[0], o[1], o[2]))
		var yaw := float(sp.angles[1]) if sp.angles.size() > 1 else 0.0
		var c4 := false
		if give_bomb and p.team == Match.Team.T and bomber == null:
			c4 = true
			bomber = p
		p.reset_round(origin, yaw, c4)
	if local_player:
		local_player.cam.current = true


func _physics_process(delta: float) -> void:
	Perf.begin_physics()
	match Match.phase:
		Match.Phase.WARMUP:
			Match.warmup_left -= delta
			if Match.warmup_left <= 0.0:
				Match.begin_round()
		Match.Phase.FREEZE:
			Match.freeze_left -= delta
			Match.buy_left -= delta
			if Match.freeze_left <= 0.0:
				Sfx.play2d("res://assets/sounds/sfx/round_start.wav", -8)
				Match.go_live()
		Match.Phase.LIVE:
			Match.round_left -= delta
			Match.buy_left -= delta
			_check_elim()
			if Match.round_left <= 0.0 and not Match.bomb_planted:
				Match.end_round(Match.Team.CT, "time")
		Match.Phase.BOMB:
			Match.bomb_left -= delta
			Match.bomb_update.emit(true, Match.bomb_left, Match.bomb_site)
			if Match.bomb_left <= 0.0:
				Sfx.play("res://assets/sounds/weapons/c4_explode1.wav", Match.bomb_pos, -2)
				Match.explode()
			elif int(Match.bomb_left * 2.0) != int((Match.bomb_left + delta) * 2.0):
				Sfx.play("res://assets/sounds/weapons/c4_beep1.wav", Match.bomb_pos, -6)
			_check_elim()
		Match.Phase.ROUND_END:
			Match.round_left -= delta
			if Match.round_left <= 0.0:
				if Match.should_swap_now():
					_swap_sides()
				Match.begin_round()
		Match.Phase.MATCH_END:
			pass
	for ai in bots:
		ai.tick(delta, world, players)
	_update_resolve()
	_sync_bomb()
	_qa_frames += 1
	_qa_tick()


func _qa_tick() -> void:
	if DisplayServer.get_name() != "headless":
		return
	if local_player == null or world == null:
		return
	if _qa_frames == 12:
		print("QA t=%d y=%.3f floor=%s pitch=%.1f gun=%s menu=%s" % [_qa_frames, local_player.global_position.y, str(local_player.grounded), local_player.aa.real_pitch, local_player.weapon_id, str(Cheat.menu_open)])
		var b := Net.view_basis(local_player.view_pitch, local_player.view_yaw)
		var ld := Net.look_dir(local_player.view_pitch, local_player.view_yaw)
		print("QA look_dot=%.3f vfov=%.1f roll=%.5f step=%.1fHU" % [(-b.z).dot(ld), local_player.cam.fov, b.x.y, Net.STEP / Net.HU])
		var nareas := 0
		if world.nav != null:
			nareas = world.nav.areas.size()
		print("QA nav=%d" % nareas)
		var a_site := Vector3(-11.176, -4.267, 55.067)
		if world.nav != null and bool(world.nav.loaded):
			var hops: Array = world.nav.path(local_player.global_position, a_site)
			print("QA path_t_to_a hops=%d" % hops.size())
		# T-spawn 18 HU treads: walk +Z up the staircase south of spawn.
		local_player.global_position = Vector3(32.07, -5.70, -8.20)
		local_player.velocity = Vector3.ZERO
		local_player.qa_wish = Vector3(0.0, 0.0, 1.0)
		local_player.qa_steps = 0
		_qa_stair_y0 = local_player.global_position.y
		if not bots.is_empty() and bots[0].player:
			_qa_bot0 = bots[0].player.global_position
			print("QA bot0 route=%d" % bots[0].route.size())
		var space := local_player.get_world_3d().direct_space_state
		if space:
			_qa_sweep(space, "tspawn", Vector3(34.95, -2.03, 7.72))
			_qa_sweep(space, "palace", Vector3(20.96, -0.20, 51.75))
			_qa_sweep(space, "connector", Vector3(-17.14, -4.80, 21.59))
			_qa_sweep(space, "mid", Vector3(0.00, -3.20, 15.56))
			# Horizontal traces at eye height so we measure walls, not the floor brush.
			_qa_wall(space, "palace_window", Vector3(20.96, -0.20, 51.75), Vector3(8.00, -0.20, 53.50), 2.5, 115.0)
			_qa_wall(space, "connector", Vector3(-17.14, -4.80, 21.59), Vector3(-6.99, -4.80, 16.51), 2.0, 86.0)
			_qa_wall(space, "a_site_wall", Vector3(-13.02, -0.20, 38.42), Vector3(-8.00, -0.20, 38.42), 2.5, 115.0)
			_qa_wall(space, "tspawn_house", Vector3(28.26, -3.80, 16.19), Vector3(22.00, -3.80, 16.19), 2.0, 86.0)
			_qa_wall(space, "open_air", Vector3(32.07, -3.20, -8.20), Vector3(32.07, -0.20, -8.20), 2.5, 115.0)
		if local_player.model:
			print(local_player.model.qa_pose_line())
			print("QA axes R=%.0f F=%.0f LBY=%.0f visible=%s" % [local_player.aa.real_yaw, local_player.aa.fake_yaw, local_player.aa.lby, str(local_player.model.axis_real != null and local_player.model.axis_real.visible)])
		var hunting := 0
		for ai in bots:
			if ai._hunt != null:
				hunting += 1
		print("QA bots hunting=%d/%d" % [hunting, bots.size()])
	if _qa_frames == 24:
		_qa_stair_y0 = local_player.global_position.y
		print("QA stair start y=%.3f floor=%s pos=%.2f,%.2f,%.2f" % [_qa_stair_y0, str(local_player.grounded), local_player.global_position.x, local_player.global_position.y, local_player.global_position.z])
	if _qa_frames == 50 or _qa_frames == 120:
		print("QA stair mid t=%d y=%.3f dy=%.3f steps=%d floor=%s pos=%.2f,%.2f,%.2f" % [_qa_frames, local_player.global_position.y, local_player.global_position.y - _qa_stair_y0, local_player.qa_steps, str(local_player.grounded), local_player.global_position.x, local_player.global_position.y, local_player.global_position.z])
	if _qa_frames == 80:
		if (local_player.global_position.y - _qa_stair_y0) > 1.45:
			local_player.qa_wish = Vector3.ZERO
			local_player.velocity = Vector3.ZERO
		print("QA stair hold y=%.3f dy=%.3f steps=%d floor=%s" % [local_player.global_position.y, local_player.global_position.y - _qa_stair_y0, local_player.qa_steps, str(local_player.grounded)])
	if _qa_frames == 220:
		if local_player.qa_wish.length_squared() > 0.0001 and (local_player.global_position.y - _qa_stair_y0) > 1.2:
			local_player.qa_wish = Vector3.ZERO
			local_player.velocity = Vector3.ZERO
		var dy := local_player.global_position.y - _qa_stair_y0
		print("QA stair end y=%.3f dy=%.3f (%.1f HU) steps=%d floor=%s pos=%.2f,%.2f,%.2f" % [local_player.global_position.y, dy, dy / Net.HU, local_player.qa_steps, str(local_player.grounded), local_player.global_position.x, local_player.global_position.y, local_player.global_position.z])
		if not bots.is_empty() and bots[0].player:
			var bp: Vector3 = bots[0].player.global_position
			print("QA bot0 moved=%.2f route_i=%d/%d pos=%.2f,%.2f,%.2f" % [_qa_bot0.distance_to(bp), bots[0].route_i, bots[0].route.size(), bp.x, bp.y, bp.z])
	if _qa_frames == 222:
		local_player.qa_wish = Vector3.ZERO
		local_player.velocity = Vector3.ZERO
		var space2 := local_player.get_world_3d().direct_space_state
		var from := Vector3(28.26, -3.80, 16.19)
		var hit: Dictionary = {}
		if space2:
			var q := PhysicsRayQueryParameters3D.create(from, Vector3(22.00, -3.80, 16.19))
			q.collision_mask = 1
			hit = space2.intersect_ray(q)
		if hit:
			var n: Vector3 = hit.normal
			var hn := Vector3(n.x, 0.0, n.z)
			if hn.length_squared() < 0.0001:
				hn = Vector3(1.0, 0.0, 0.0)
			hn = hn.normalized()
			local_player.global_position = hit.position + hn * 0.50 + Vector3(0.0, 0.04, 0.0)
			_qa_drop_to_floor(local_player)
			local_player.qa_wish = Vector3(-hn.z, 0.0, hn.x)
		else:
			local_player.global_position = Vector3(32.07, -5.70, -8.20)
			local_player.qa_wish = Vector3(0.0, 0.0, 1.0)
		_qa_wall0 = local_player.global_position
		print("QA wallslide start pos=%.2f,%.2f,%.2f wish=%.2f,%.2f" % [_qa_wall0.x, _qa_wall0.y, _qa_wall0.z, local_player.qa_wish.x, local_player.qa_wish.z])
	if _qa_frames == 255:
		var wdx := Vector2(local_player.global_position.x - _qa_wall0.x, local_player.global_position.z - _qa_wall0.z).length()
		print("QA wallslide dxz=%.3f dy=%.3f floor=%s velxz=%.3f pos=%.2f,%.2f,%.2f" % [wdx, local_player.global_position.y - _qa_wall0.y, str(local_player.grounded), Vector2(local_player.velocity.x, local_player.velocity.z).length(), local_player.global_position.x, local_player.global_position.y, local_player.global_position.z])
		local_player.qa_wish = Vector3.ZERO
	if _qa_frames == 258:
		# Head-on into T-house: must stop, stay on floor, not launch or NaN.
		var space3 := local_player.get_world_3d().direct_space_state
		var from2 := Vector3(28.26, -3.80, 16.19)
		var hit2: Dictionary = {}
		if space3:
			var q2 := PhysicsRayQueryParameters3D.create(from2, Vector3(22.00, -3.80, 16.19))
			q2.collision_mask = 1
			hit2 = space3.intersect_ray(q2)
		if hit2:
			var n2: Vector3 = hit2.normal
			var hn2 := Vector3(n2.x, 0.0, n2.z)
			if hn2.length_squared() < 0.0001:
				hn2 = Vector3(1.0, 0.0, 0.0)
			hn2 = hn2.normalized()
			local_player.global_position = hit2.position + hn2 * 0.45 + Vector3(0.0, 0.04, 0.0)
			_qa_drop_to_floor(local_player)
			local_player.velocity = Vector3.ZERO
			local_player.qa_wish = -hn2
		else:
			local_player.global_position = Vector3(28.26, -3.76, 16.19)
			local_player.qa_wish = Vector3(-1.0, 0.0, 0.0)
		_qa_wall0 = local_player.global_position
		print("QA headon start pos=%.2f,%.2f,%.2f wish=%.2f,%.2f" % [_qa_wall0.x, _qa_wall0.y, _qa_wall0.z, local_player.qa_wish.x, local_player.qa_wish.z])
	if _qa_frames == 290:
		var hdx := Vector2(local_player.global_position.x - _qa_wall0.x, local_player.global_position.z - _qa_wall0.z).length()
		var hdy: float = local_player.global_position.y - _qa_wall0.y
		print("QA headon dxz=%.3f dy=%.3f floor=%s finite=%s velxz=%.3f pos=%.2f,%.2f,%.2f" % [hdx, hdy, str(local_player.grounded), str(Net.finite3(local_player.global_position) and Net.finite3(local_player.velocity)), Vector2(local_player.velocity.x, local_player.velocity.z).length(), local_player.global_position.x, local_player.global_position.y, local_player.global_position.z])
		local_player.qa_wish = Vector3.ZERO
	if _qa_frames == 292:
		var bad := 0
		var low := 0
		for p in players:
			if p == null or not p.alive:
				continue
			if not Net.finite3(p.global_position) or not Net.finite3(p.velocity):
				bad += 1
			if p.global_position.y < -12.0:
				low += 1
		print("QA sanity bad=%d low=%d players=%d local_y=%.3f" % [bad, low, players.size(), local_player.global_position.y])


func _qa_drop_to_floor(p: Player) -> void:
	var space := p.get_world_3d().direct_space_state
	if space == null:
		return
	var o: Vector3 = p.global_position
	var q := PhysicsRayQueryParameters3D.create(o + Vector3(0.0, 0.5, 0.0), o + Vector3(0.0, -4.0, 0.0))
	q.collision_mask = 1
	q.exclude = [p.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if hit and hit.has("position"):
		p.global_position.y = float(hit.position.y) + 0.004
		p.velocity = Vector3.ZERO
		p.grounded = true
		p.move_ok = p.global_position


func _qa_sweep(space: PhysicsDirectSpaceState3D, tag: String, origin: Vector3) -> void:
	var bang := 0
	var solid := 0
	var miss := 0
	var samples: Array = []
	for i in 24:
		var a := float(i) * 15.0
		var rad := deg_to_rad(a)
		var d := Vector3(-sin(rad), 0.0, -cos(rad))
		var r: Dictionary = Hitscan.fire_bullet(space, origin, origin + d * 6.0, [], 2.5, 115.0)
		var th: Array = r.get("thick", [])
		if int(r.walls) == 0:
			miss += 1
		elif bool(r.reached):
			bang += 1
			if samples.size() < 6:
				samples.append(th)
		else:
			solid += 1
			if samples.size() < 8:
				samples.append(th)
	print("QA sweep %s miss=%d bang=%d solid=%d thick=%s" % [tag, miss, bang, solid, str(samples)])


func _qa_wall(space: PhysicsDirectSpaceState3D, label: String, frm: Vector3, too: Vector3, pen: float, dmg0: float) -> void:
	var q := PhysicsRayQueryParameters3D.create(frm, too)
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	var enter := "none"
	if hit:
		enter = "dist=%.2fm nY=%.2f" % [frm.distance_to(hit.position), float(hit.normal.y)]
	var r: Dictionary = Hitscan.fire_bullet(space, frm, too, [], pen, dmg0)
	print("QA wall %s enter=%s dmg=%.1f walls=%d reached=%s thick=%s" % [label, enter, float(r.dmg), int(r.walls), str(r.reached), str(r.get("thick", []))])


func _update_resolve() -> void:
	if local_player == null:
		return
	for p in players:
		if p == local_player or not p.alive:
			continue
		local_player.resolver.observe(p, Net.TICK)
		p.resolved_yaw = local_player.resolver.resolve(p)
		p.resolved_label = local_player.resolver.label(p)


func _sync_bomb() -> void:
	if bomb_node == null:
		return
	if Match.bomb_planted:
		bomb_node.visible = true
		bomb_node.global_position = Match.bomb_pos + Vector3(0, 0.08, 0)
	else:
		bomb_node.visible = false


func _on_round_reset() -> void:
	_place_spawns(true)
	for p in players:
		if p.alive:
			p.autobuy()


func _on_phase(ph: int) -> void:
	if ph == Match.Phase.ROUND_END:
		Match.payout(Match.last_winner, Match.last_reason, players)
		if Match.last_winner == Match.local_team:
			Sfx.play2d("res://assets/sounds/sfx/round_win.wav", -8)
		else:
			Sfx.play2d("res://assets/sounds/sfx/round_lose.wav", -8)
	if ph == Match.Phase.MATCH_END:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _check_elim() -> void:
	var t_alive := 0
	var ct_alive := 0
	for p in players:
		if p.alive:
			if p.team == Match.Team.T:
				t_alive += 1
			else:
				ct_alive += 1
	if t_alive == 0 and not Match.bomb_planted:
		Match.end_round(Match.Team.CT, "elim")
	elif ct_alive == 0:
		Match.end_round(Match.Team.T, "elim")


func _swap_sides() -> void:
	for p in players:
		p.team = Match.Team.CT if p.team == Match.Team.T else Match.Team.T
		p.money = Match.START_MONEY
	Match.local_team = Match.Team.CT if Match.local_team == Match.Team.T else Match.Team.T
	var tmp := Match.t_score
	Match.t_score = Match.ct_score
	Match.ct_score = tmp
	var lb := Match.loss_bonus_t
	Match.loss_bonus_t = Match.loss_bonus_ct
	Match.loss_bonus_ct = lb
	Match.side_swapped.emit()
	Match.score_changed.emit()
