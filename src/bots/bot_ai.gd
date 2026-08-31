class_name BotAI
extends RefCounted
## MM HvH bot: hold a site, shoot only with LOS, never spray or charge.

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
var _see := false
var _site := 0


func setup(p: Player, idx: int) -> void:
	player = p
	style = idx % PRESETS.size()
	_site = idx % 2
	p.aa.src = PRESETS[style].duplicate()
	p.player_name = _name(idx, p.team)
	retarget = 0.05 * float(idx)


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
	if (Engine.get_physics_frames() + style) % 2 == 0:
		_see = _los(_hunt)
	if player.clip <= 0:
		PlayerCombat.reload_weapon(player)
		if player.clip <= 0 and player.inv.has(2):
			player.equip(str(player.inv[2]))
	player.bot_use = false
	player.want_autostop = false
	if _see and _hunt != null and Match.in_play():
		_hold_and_shoot()
		return
	retarget -= delta
	if retarget <= 0.0:
		_pick_goal(world)
		_rebuild_route(world)
		retarget = randf_range(0.9, 1.6)
	_walk_route()
	_unstick(delta, world)
	player.bot_use = _should_use(world)
	if player.weapon_id == "c4" and not player.bot_use:
		player.equip(str(player.inv.get(1, player.inv.get(2, "glock"))))


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


func _los(target: Player) -> bool:
	if target == null or not is_instance_valid(target) or not target.alive:
		return false
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	if space == null:
		return false
	var to: Vector3 = target.eye()
	var boxes: Array = target.hitboxes_at_yaw(target.aa.real_yaw, target.aa.real_pitch)
	if boxes.size() > 1:
		to = boxes[1].pos
	elif not boxes.is_empty():
		to = boxes[0].pos
	return Hitscan.los(space, player.eye(), to, [player.get_rid()])


func _hold_and_shoot() -> void:
	var d: float = player.global_position.distance_to(_hunt.global_position)
	var away: Vector3 = player.global_position - _hunt.global_position
	away.y = 0.0
	# Peek-shoot: stop to fire. Only back up if they are in our face.
	if d < 3.2 and away.length_squared() > 0.01:
		player.bot_wish = away.normalized()
		player.want_autostop = false
	else:
		player.bot_wish = Vector3.ZERO
		player.want_autostop = true
	player.bot_jump = false
	var to: Vector3 = _hunt.eye() - player.eye()
	if to.length_squared() > 0.0001:
		player.view_yaw = rad_to_deg(atan2(-to.x, -to.z))
	if player.weapon_id == "c4" or player.weapon_id == "knife":
		return
	var w := Weapons.get_w(player.weapon_id)
	if bool(w.get("revolver", false)):
		player._cock_revolver()
	if bool(w.get("zoom", false)) and not player.scoped:
		player.scoped = true
		return
	var spd: float = Vector2(player.velocity.x, player.velocity.z).length()
	if spd > Net.hu(40.0):
		return
	if not player.is_on_floor():
		return
	if player.time < player.next_attack or player.clip <= 0:
		return
	if bool(w.get("revolver", false)) and not player.revolver_ready:
		return
	var aim: Vector3 = _hunt.eye()
	var boxes: Array = _hunt.hitboxes_at_yaw(_hunt.aa.real_yaw, _hunt.aa.real_pitch)
	if not boxes.is_empty():
		aim = boxes[0].pos
	var dir: Vector3 = aim - player.eye()
	if dir.length_squared() < 0.0001:
		return
	player._fire(dir.normalized(), true)


func _walk_route() -> void:
	var wp := _waypoint()
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
	if dist > 0.35:
		wish = to.normalized()
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
	if _stuck < 0.40:
		return
	_stuck = 0.0
	player.bot_jump = true
	route_i = mini(route_i + 2, maxi(route.size() - 1, 0))
	if world != null and world.nav != null and bool(world.nav.loaded):
		goal = world.nav.nearby_center(player.global_position, 2.0, 10.0)
		_rebuild_route(world)


func _should_use(_world: MapWorld) -> bool:
	if _see:
		return false
	if player.team == Match.Team.T and player.holding_bomb:
		var site := player._on_site()
		if site != "":
			if player.weapon_id != "c4":
				player.equip("c4")
			return true
	if player.team == Match.Team.CT and Match.bomb_planted:
		if player.global_position.distance_to(Match.bomb_pos) < 1.15:
			return true
	return false


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


func _site_center(world: MapWorld, which: int) -> Vector3:
	if world == null or world.sites.is_empty():
		return player.spawn_origin
	var s: Dictionary = world.sites[which % world.sites.size()]
	var c: Array = s.center
	return Vector3(float(c[0]), float(c[1]), float(c[2]))


func _pick_goal(world: MapWorld) -> void:
	if player.holding_bomb:
		goal = _site_center(world, _site)
		return
	if player.team == Match.Team.CT and Match.bomb_planted:
		goal = Match.bomb_pos
		return
	goal = _site_center(world, _site) + Vector3(randf_range(-1.8, 1.8), 0.0, randf_range(-1.8, 1.8))
