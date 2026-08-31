class_name Ragebot
extends RefCounted
## 2018 MM HvH ragebot: hitchance, mindmg, autowall, multipoint, silent, autoscope,
## autostop, auto-revolver (cock R8 to m_flPostponeFireReadyTime then fire).

var resolver: Resolver
var last_shot_at := -999.0
var last_target: Node = null
var last_aim := Vector3.ZERO
var last_hc := 0.0
var last_dmg := 0
var shot_this_tick := false
var want_autostop := false
var want_scope := false
var cock_revolver := false


func _init(r: Resolver) -> void:
	resolver = r


func run(me: Player, enemies: Array, space: PhysicsDirectSpaceState3D, now: float) -> Dictionary:
	shot_this_tick = false
	want_autostop = false
	want_scope = false
	cock_revolver = false
	var out := {
		"shoot": false, "dir": Vector3.ZERO, "silent": false, "target": null,
		"hitbox": "head", "cock": false, "scope": false, "autostop": false,
		"resolved_yaw": 0.0,
	}
	if not bool(Cheat.t("rage/enable", true)):
		return out
	if me.weapon_id == "knife" or me.weapon_id == "c4":
		return out
	if me.clip <= 0:
		return out
	var w := Weapons.get_w(me.weapon_id)
	var is_r8: bool = bool(w.get("revolver", false))
	if is_r8 and bool(Cheat.t("rage/auto_revolver", true)):
		cock_revolver = true
		out.cock = true
	if me.next_attack > now and not (is_r8 and cock_revolver):
		return out
	var best: Dictionary = {}
	var best_score := -1.0
	for e in enemies:
		if e == null or not is_instance_valid(e) or not e.alive:
			continue
		if e.team == me.team:
			continue
		resolver.observe(e, Net.TICK)
		var ryaw := resolver.resolve(e)
		e.resolved_yaw = ryaw  # ESP/chams/skeleton follow this true-yaw guess
		e.resolved_label = resolver.label(e)
		var pts := _points(e, ryaw)
		for p in pts:
			var info := _trace(me.eye(), p.pos, space, me, e, p.group)
			if int(info.dmg) <= 0:
				continue
			var hc := _hitchance(me, p.pos, bool(info.spread_ok), w)
			var hc_need := float(Cheat.t("rage/hitchance", 55))
			if int(Cheat.t("rage/hitchance_ovr", 0)) > 0:
				hc_need = float(Cheat.t("rage/hitchance_ovr", 0))
			if hc < hc_need:
				continue
			var md := int(Cheat.t("rage/mindmg", 20))
			if int(Cheat.t("rage/mindmg_ovr", 0)) > 0:
				md = int(Cheat.t("rage/mindmg_ovr", 0))
			if int(info.dmg) < md and int(info.dmg) < e.health:
				continue
			if bool(Cheat.t("rage/baim_lethal", true)) and p.group == "head" and int(info.dmg) < e.health:
				pass
			var score := float(info.dmg) + hc * 0.25
			if p.group == "head" and not bool(Cheat.t("rage/prefer_body", false)):
				score += 50.0
			if score > best_score:
				best_score = score
				best = {
					"dir": (p.pos - me.eye()).normalized(),
					"target": e, "hitbox": p.group, "hc": hc,
					"dmg": info.dmg, "pos": p.pos, "yaw": ryaw,
				}
	if best.is_empty():
		return out
	last_target = best.target
	last_aim = best.pos
	last_hc = best.hc
	last_dmg = best.dmg
	out.dir = best.dir
	out.silent = bool(Cheat.t("rage/silent", true))
	out.target = best.target
	out.hitbox = best.hitbox
	out.resolved_yaw = best.yaw
	if bool(w.get("zoom", false)) and bool(Cheat.t("rage/autoscope", true)) and not me.scoped:
		out.scope = true
		want_scope = true
		# 2018 delay shot until scoped inaccuracy drops
		if bool(Cheat.t("rage/delay_shot", false)) or w.id == "awp" or w.id == "ssg08":
			if not me.scoped:
				return out
	if bool(Cheat.t("rage/autostop", true)):
		out.autostop = true
		want_autostop = true
	var can_fire := bool(Cheat.t("rage/autoshoot", true))
	if is_r8 and bool(Cheat.t("rage/auto_revolver", true)):
		# Hold cock every tick; only fire when postpone ready (2018 auto-revolver).
		can_fire = can_fire and me.revolver_ready
	if not me.is_on_floor() and not bool(Cheat.t("rage/shoot_jump", false)):
		if w.get("type") == "sniper" or is_r8:
			can_fire = false
	out.shoot = can_fire
	if out.shoot:
		shot_this_tick = true
		last_shot_at = now
	return out


func _points(e: Node, yaw: float) -> Array:
	var hb: Array = e.hitboxes_at_yaw(yaw, float(e.aa.real_pitch))
	var want: Dictionary = Cheat.t("rage/hitboxes", {"head": true, "chest": true, "stomach": true})
	var mp := bool(Cheat.t("rage/multipoint", true))
	var pts: Array = []
	for h in hb:
		if not bool(want.get(h.group, h.group == "head" or h.group == "chest")):
			continue
		pts.append(h)
		if mp:
			var r: float = h.radius
			pts.append({"pos": h.pos + Vector3(r * 0.55, 0, 0), "group": h.group, "radius": r})
			pts.append({"pos": h.pos + Vector3(-r * 0.55, 0, 0), "group": h.group, "radius": r})
			if h.group == "head":
				pts.append({"pos": h.pos + Vector3(0, r * 0.4, 0), "group": h.group, "radius": r})
	return pts


func _trace(from: Vector3, to: Vector3, space: PhysicsDirectSpaceState3D, me: Player, enemy: Node, group: String) -> Dictionary:
	var w := Weapons.get_w(me.weapon_id)
	var dist := from.distance_to(to)
	var base := float(Weapons.damage_vs(w, group, enemy.armor > 0, enemy.helmet, dist))
	var exclude: Array = [me.get_rid()]
	if not bool(Cheat.t("rage/autowall", true)):
		var vis := Hitscan.fire_bullet(space, from, to, exclude, 99.0, base)
		if int(vis.walls) > 0 or not bool(vis.reached):
			return {"dmg": 0, "spread_ok": false}
		return {"dmg": int(base), "spread_ok": true}
	var pen := float(w.get("pen", 1.0))
	var r := Hitscan.fire_bullet(space, from, to, exclude, pen, base)
	if not bool(r.reached) or float(r.dmg) < 1.0:
		return {"dmg": 0, "spread_ok": false}
	return {"dmg": int(r.dmg), "spread_ok": int(r.walls) == 0}


func _hitchance(me: Player, aim: Vector3, clean: bool, w: Dictionary) -> float:
	var inacc := float(w.spread)
	var spd: float = Vector2(me.velocity.x, me.velocity.z).length()
	if spd > 0.25:
		inacc += 2.1
	if not me.is_on_floor():
		inacc += 5.0
	if me.ducking:
		inacc *= 0.62
	if bool(w.get("zoom", false)) and not me.scoped:
		inacc += 12.0
	if bool(w.get("revolver", false)) and not me.revolver_ready:
		inacc += 2.0
	var dist: float = me.eye().distance_to(aim)
	var ang := rad_to_deg(atan2(Net.HEAD_R, maxf(dist, 0.01)))
	var hc := clampf(100.0 * (ang / maxf(inacc * 0.32, 0.04)), 0.0, 100.0)
	if not clean:
		hc *= 0.7
	if me.is_on_floor() and spd < 0.12:
		hc = minf(100.0, hc + 14.0)
	if bool(w.get("revolver", false)) and me.revolver_ready and spd < 0.12:
		hc = minf(100.0, hc + 8.0)
	return hc
