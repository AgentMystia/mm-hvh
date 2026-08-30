class_name BotAI
extends RefCounted
## MM HvH bot: site hold / exec, plant, defuse, own AA preset, ragebot.

const PRESETS := [
	{"enable": true, "pitch": 1, "yaw": 1, "yaw_base": 1, "jitter": true, "jitter_range": 18, "fake": 2, "fake_limit": 58, "lby": 4, "lby_delta": 118, "freestanding": true, "fakelag": true, "fakelag_amt": 14},
	{"enable": true, "pitch": 1, "yaw": 2, "yaw_base": 0, "jitter": false, "fake": 3, "fake_limit": 58, "lby": 1, "lby_delta": 120, "freestanding": false, "fakelag": true, "fakelag_amt": 10},
	{"enable": true, "pitch": 1, "yaw": 3, "yaw_base": 1, "jitter": true, "jitter_type": 2, "jitter_range": 28, "fake": 2, "lby": 2, "lby_delta": 90, "freestanding": true, "fakelag": true, "fakelag_amt": 16},
	{"enable": true, "pitch": 1, "yaw": 4, "yaw_base": 1, "jitter": true, "fake": 4, "lby": 5, "lby_delta": 140, "freestanding": true, "fakelag": true, "fakelag_amt": 12},
	{"enable": true, "pitch": 2, "yaw": 5, "yaw_base": 1, "jitter": true, "jitter_range": 8, "fake": 1, "fake_limit": 48, "lby": 3, "lby_delta": 110, "freestanding": false, "fakelag": true, "fakelag_amt": 8},
	{"enable": true, "pitch": 1, "yaw": 6, "yaw_base": 1, "jitter": false, "fake": 2, "lby": 4, "lby_delta": 116, "freestanding": true, "fakelag": true, "fakelag_amt": 15},
]

var player: Player
var goal := Vector3.ZERO
var hold := Vector3.ZERO
var retarget := 0.0
var style := 0


func setup(p: Player, idx: int) -> void:
	player = p
	style = idx % PRESETS.size()
	p.aa.src = PRESETS[style].duplicate()
	p.player_name = _name(idx, p.team)


func _name(i: int, team: int) -> String:
	var tnames := ["LBY breaker", "spinbot", "jitter", "desync", "lowdelta", "distort", "skeet", "onetap", "fatality", "gamesense"]
	var prefix := "T" if team == Match.Team.T else "CT"
	return "%s %s" % [prefix, tnames[i % tnames.size()]]


func tick(delta: float, world: MapWorld, all: Array) -> void:
	if player == null or not player.alive:
		player.bot_wish = Vector3.ZERO
		return
	retarget -= delta
	if retarget <= 0.0:
		_pick_goal(world, all)
		retarget = randf_range(0.6, 1.6)
	var to := goal - player.global_position
	to.y = 0
	var dist := to.length()
	var wish := Vector3.ZERO
	if dist > 0.55:
		wish = to.normalized()
		player.view_yaw = rad_to_deg(atan2(-wish.x, -wish.z))
	player.bot_wish = wish
	player.bot_jump = bool(Cheat.t("misc/bhop", true)) and dist > 2.0
	# rage
	if Match.in_play():
		var enemies: Array = []
		for p in all:
			if p != player:
				enemies.append(p)
		var r: Dictionary = player.rage.run(player, enemies, player.get_world_3d().direct_space_state, player.time)
		player.last_rage = r
		if bool(r.get("cock", false)):
			player._cock_revolver()
		if bool(r.get("scope", false)):
			player.scoped = true
		player.want_autostop = bool(r.get("autostop", false))
		if bool(r.get("shoot", false)):
			player._fire(r.dir, true)
		# look at target if raging
		if r.get("target", null) != null and is_instance_valid(r.target):
			var d: Vector3 = r.target.global_position - player.global_position
			player.view_yaw = rad_to_deg(atan2(-d.x, -d.z))
			player.view_pitch = 89.0 if int(player.aa._g("pitch", 1)) == 1 else player.view_pitch
	# plant / defuse handled in Player._use via is_bot


func _pick_goal(world: MapWorld, all: Array) -> void:
	# Hunt nearest living enemy, otherwise go site / spawn.
	var best: Player = null
	var bd := 1e9
	for p in all:
		if p == player or not p.alive or p.team == player.team:
			continue
		var d: float = p.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = p
	if best and bd < 55.0:
		goal = best.lag_origin
		return
	if player.team == Match.Team.T:
		if player.holding_bomb and world.sites.size() > 0:
			var s: Dictionary = world.sites[0] if randf() > 0.45 else world.sites[mini(1, world.sites.size() - 1)]
			var c: Array = s.center
			goal = Vector3(c[0], player.global_position.y, c[2])
			return
		if world.sites.size() > 0:
			var s2: Dictionary = world.sites[randi() % world.sites.size()]
			var c2: Array = s2.center
			goal = Vector3(c2[0], player.global_position.y, c2[2])
			return
	else:
		if Match.bomb_planted:
			goal = Match.bomb_pos
			return
		if world.sites.size() > 0:
			var hold_s: Dictionary = world.sites[player.get_instance_id() % world.sites.size()]
			var hc: Array = hold_s.center
			goal = Vector3(hc[0], player.global_position.y, hc[2]) + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
			return
	goal = player.spawn_origin
