class_name BotAI
extends RefCounted
## MM HvH bot: always hunt living enemies, plant/defuse only when clear, rage without AFK.

const PRESETS := [
	{"enable": true, "pitch": 1, "yaw": 1, "yaw_base": 1, "jitter": true, "jitter_range": 18, "fake": 2, "fake_limit": 58, "lby": 4, "lby_delta": 118, "freestanding": true, "fakelag": true, "fakelag_amt": 14},
	{"enable": true, "pitch": 1, "yaw": 2, "yaw_base": 0, "jitter": false, "fake": 3, "fake_limit": 58, "lby": 1, "lby_delta": 120, "freestanding": false, "fakelag": true, "fakelag_amt": 10},
	{"enable": true, "pitch": 1, "yaw": 3, "yaw_base": 1, "jitter": true, "jitter_type": 2, "jitter_range": 28, "fake": 2, "lby": 2, "lby_delta": 90, "freestanding": true, "fakelag": true, "fakelag_amt": 16},
	{"enable": true, "pitch": 1, "yaw": 4, "yaw_base": 1, "jitter": true, "fake": 4, "lby": 5, "lby_delta": 140, "freestanding": true, "fakelag": true, "fakelag_amt": 12},
	{"enable": true, "pitch": 1, "yaw": 5, "yaw_base": 1, "jitter": true, "jitter_range": 8, "fake": 1, "fake_limit": 48, "lby": 3, "lby_delta": 110, "freestanding": false, "fakelag": true, "fakelag_amt": 8},
	{"enable": true, "pitch": 1, "yaw": 6, "yaw_base": 1, "jitter": false, "fake": 2, "lby": 4, "lby_delta": 116, "freestanding": true, "fakelag": true, "fakelag_amt": 15},
]

var player: Player
var goal := Vector3.ZERO
var retarget := 0.0
var style := 0
var route: Array = []
var route_i := 0
var _stuck := 0.0
var _last_xz := Vector3.ZERO
var _hunt: Player = null


func setup(p: Player, idx: int) -> void:
	player = p
	style = idx % PRESETS.size()
	p.aa.src = PRESETS[style].duplicate()
	p.player_name = _name(idx, p.team)
	retarget = 0.04 * float(idx)


func _name(i: int, team: int) -> String:
	var tnames := ["LBY breaker", "spinbot", "jitter", "desync", "lowdelta", "distort", "skeet", "onetap", "fatality", "gamesense"]
	var prefix := "T" if team == Match.Team.T else "CT"
	return "%s %s" % [prefix, tnames[i % tnames.size()]]


func tick(delta: float, world: MapWorld, all: Array) -> void:
	if player == null or not player.alive:
		if player:
			player.bot_wish = Vector3.ZERO
			player.bot_jump = false
			player.bot_use = false
			player.want_autostop = false
		return
	_hunt = _nearest_enemy(all)
	retarget -= delta
	if retarget <= 0.0:
		_pick_goal(world)
		_rebuild_route(world)
		retarget = randf_range(0.28, 0.55)
	_move_along_route(delta, world)
	_unstick(delta, world)
	player.bot_use = _should_use(world)
	if player.weapon_id == "c4" and not player.bot_use:
		player.equip(str(player.inv.get(1, player.inv.get(2, "glock"))))
	if player.clip <= 0:
		PlayerCombat.reload_weapon(player)
		if player.clip <= 0 and player.inv.has(2):
			player.equip(str(player.inv[2]))
	if Match.in_play():
		_shoot()


func _nearest_enemy(all: Array) -> Player:
	var best: Player = null
	var bd := 1e9
	for p in all:
		if p == null or p == player or not p.alive or p.team == player.team:
			continue
		var d: float = p.global_position.distance_squared_to(player.global_position)
		if d < bd:
			bd = d
			best = p
	return best


func _move_along_route(delta: float, world: MapWorld) -> void:
	var wp := _waypoint()
	if _hunt != null and player.global_position.distance_to(_hunt.global_position) < 14.0:
		wp = _hunt.global_position
	var to := wp - player.global_position
	var climb := to.y
	to.y = 0.0
	var dist := to.length()
	while dist < 0.55 and route_i < route.size() - 1:
		route_i += 1
		wp = _waypoint()
		to = wp - player.global_position
		climb = to.y
		to.y = 0.0
		dist = to.length()
	var wish := Vector3.ZERO
	if dist > 0.10:
		wish = to.normalized()
	elif _hunt != null:
		var side := Net.right_vec(player.view_yaw)
		if (Engine.get_physics_frames() + style) % 40 < 20:
			side = -side
		wish = side
	player.bot_wish = wish
	player.bot_jump = climb > 0.28 and dist < 1.8
	if wish.length_squared() > 0.01:
		player.view_yaw = rad_to_deg(atan2(-wish.x, -wish.z))


func _unstick(delta: float, world: MapWorld) -> void:
	var xz := Vector3(player.global_position.x, 0.0, player.global_position.z)
	if xz.distance_to(_last_xz) < 0.045 and player.bot_wish.length_squared() > 0.01:
		_stuck += delta
	else:
		_stuck = 0.0
	_last_xz = xz
	if _stuck < 0.32:
		return
	_stuck = 0.0
	player.bot_jump = true
	route_i = mini(route_i + 2, maxi(route.size() - 1, 0))
	if world != null and world.nav != null and bool(world.nav.loaded):
		goal = world.nav.nearby_center(player.global_position, 2.0, 12.0)
		if _hunt:
			goal = goal.lerp(_hunt.global_position, 0.45)
		_rebuild_route(world)


func _should_use(world: MapWorld) -> bool:
	var enemy_d := 1e9
	if _hunt:
		enemy_d = player.global_position.distance_to(_hunt.global_position)
	if player.team == Match.Team.T and player.holding_bomb:
		var site := player._on_site()
		if site != "" and enemy_d > 16.0:
			if player.weapon_id != "c4":
				player.equip("c4")
			return true
	if player.team == Match.Team.CT and Match.bomb_planted:
		if player.global_position.distance_to(Match.bomb_pos) < 1.15 and enemy_d > 10.0:
			return true
	return false


func _shoot() -> void:
	player.want_autostop = false
	if _hunt == null or not is_instance_valid(_hunt) or not _hunt.alive:
		return
	if player.weapon_id == "c4" or player.weapon_id == "knife":
		return
	var w := Weapons.get_w(player.weapon_id)
	var aim: Vector3 = _hunt.head_pos()
	var boxes: Array = _hunt.hitboxes_at_yaw(_hunt.aa.real_yaw, _hunt.aa.real_pitch)
	if not boxes.is_empty():
		aim = boxes[0].pos
	var from: Vector3 = player.eye()
	var dir := (aim - from)
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	player.view_yaw = rad_to_deg(atan2(-dir.x, -dir.z))
	if bool(w.get("revolver", false)):
		player._cock_revolver()
	if bool(w.get("zoom", false)) and not player.scoped:
		player.scoped = true
	# Ignore hitchance / autostop so remaining bots still frag after the local player dies.
	if player.time >= player.next_attack and player.clip > 0:
		if bool(w.get("revolver", false)) and not player.revolver_ready:
			return
		player._fire(dir, true)


func _waypoint() -> Vector3:
	if route_i >= 0 and route_i < route.size():
		return route[route_i]
	return goal


func _rebuild_route(world: MapWorld) -> void:
	route_i = 0
	if world != null and world.nav != null and bool(world.nav.loaded):
		route = world.nav.path(player.global_position, goal)
	else:
		route = [goal]
	if route.is_empty():
		route = [goal]


func _pick_goal(world: MapWorld) -> void:
	if _hunt:
		goal = _hunt.global_position
		return
	if player.team == Match.Team.T:
		if player.holding_bomb and world.sites.size() > 0:
			var s: Dictionary = world.sites[0] if randf() > 0.45 else world.sites[mini(1, world.sites.size() - 1)]
			var c: Array = s.center
			goal = Vector3(c[0], float(c[1]), c[2])
			return
		if world.sites.size() > 0:
			var s2: Dictionary = world.sites[randi() % world.sites.size()]
			var c2: Array = s2.center
			goal = Vector3(c2[0], float(c2[1]), c2[2])
			return
	else:
		if Match.bomb_planted:
			goal = Match.bomb_pos
			return
		if world.sites.size() > 0:
			var hold_s: Dictionary = world.sites[player.get_instance_id() % world.sites.size()]
			var hc: Array = hold_s.center
			goal = Vector3(hc[0], float(hc[1]), hc[2]) + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
			return
	goal = player.spawn_origin
