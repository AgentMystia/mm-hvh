class_name PlayerCombat
extends RefCounted
## Hitscan fire, knife, damage, 2018 autowall via Hitscan.fire_bullet.


static func fire(p, dir: Vector3, silent: bool, r8_alt := false) -> void:
	if not p.alive or p.time < p.next_attack:
		return
	if Match.phase == Match.Phase.FREEZE or Match.phase == Match.Phase.WARMUP:
		return
	var w := Weapons.get_w(p.weapon_id)
	if p.weapon_id == "knife":
		knife(p, dir)
		return
	if p.weapon_id == "c4":
		return
	if p.clip <= 0:
		Sfx.play("res://assets/sounds/weapons/dryfire_rifle.wav", p.global_position, -4)
		return
	if bool(w.get("revolver", false)) and not r8_alt and not p.revolver_ready:
		return
	p.clip -= 1
	p.shot_this_tick = true
	p.aa.broke_this_tick = false
	var cycle := float(w.cycle)
	if r8_alt:
		cycle = float(w.get("alt_cycle", 0.166))
	p.next_attack = p.time + cycle
	var spread := float(w.spread)
	if r8_alt:
		spread = float(w.get("alt_spread", 3.2))
	var spd := Vector2(p.velocity.x, p.velocity.z).length()
	if spd > 0.3:
		spread += 1.6
	if not p.is_on_floor():
		spread += 4.0
	if bool(w.get("zoom", false)) and not p.scoped:
		spread += 10.0
	var rec: Array = w.recoil
	if p.shots_fired < rec.size():
		var r: Vector2 = rec[p.shots_fired]
		if not silent:
			p.view_pitch = clampf(p.view_pitch + r.x * 0.35, -89, 89)
			p.view_yaw = Net.ang_norm(p.view_yaw + r.y * 0.35)
	p.shots_fired += 1
	dir = spread_dir(dir, spread)
	Sfx.play(str(w.snd), p.global_position, -2)
	var from: Vector3 = p.eye()
	var to: Vector3 = from + dir * 180.0
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var pen := float(w.get("pen", 1.0))
	if not bool(Cheat.t("rage/autowall", true)):
		pen = 0.05
	var hit_someone := false
	for e in p._enemies():
		if not e.alive or e.team == p.team:
			continue
		var boxes: Array = e.hitboxes_at_yaw(e.aa.real_yaw, e.aa.real_pitch)
		var hit: Dictionary = Hitscan.closest_hitbox(from, to, boxes)
		if hit.is_empty():
			continue
		var base := float(Weapons.damage_vs(w, str(hit.group), e.armor > 0, e.helmet, from.distance_to(hit.hit)))
		var shot: Dictionary = Hitscan.fire_bullet(space, from, hit.hit, [p.get_rid()], pen, base)
		if not bool(shot.reached) or float(shot.dmg) < 1.0:
			continue
		e.take_damage(int(shot.dmg), str(hit.group), p, w)
		hit_someone = true
		if e.health <= 0:
			p.resolver.hit(e)
			break
	if not hit_someone and p.last_rage.get("target", null) != null:
		var t = p.last_rage.target
		if t and is_instance_valid(t):
			p.resolver.miss(t)
	p._tracer(from, to if not hit_someone else from + dir * from.distance_to(to) * 0.5)
	p.cocking = false
	p.revolver_ready = false


static func knife(p, _dir: Vector3) -> void:
	p.next_attack = p.time + 0.4
	Sfx.play("res://assets/sounds/weapons/knife_slash1.wav", p.global_position, -4)
	for e in p._enemies():
		if e.alive and e.team != p.team and e.global_position.distance_to(p.global_position) < 1.8:
			e.take_damage(65, "chest", p, Weapons.get_w("knife"))
			return


static func spread_dir(dir: Vector3, spread_deg: float) -> Vector3:
	var rx := deg_to_rad(randf_range(-spread_deg, spread_deg) * 0.15)
	var ry := deg_to_rad(randf_range(-spread_deg, spread_deg) * 0.15)
	var basis := Net.look_basis(dir)
	return (basis * Vector3(sin(ry), sin(rx), -1)).normalized()


static func attack_manual(p) -> void:
	if p.is_bot or Cheat.menu_open or Cheat.buy_open or not p.is_local:
		return
	if not Match.in_play() and Match.phase != Match.Phase.FREEZE:
		return
	var w := Weapons.get_w(p.weapon_id)
	if bool(w.get("revolver", false)) and bool(Cheat.t("rage/auto_revolver", true)) and bool(Cheat.t("rage/enable", true)):
		return
	if Input.is_action_just_pressed("altfire") and bool(w.get("zoom", false)):
		p.scoped = not p.scoped
		Sfx.play2d("res://assets/sounds/sfx/scope.wav", -8)
	if Input.is_action_pressed("fire"):
		if bool(w.get("revolver", false)):
			p._cock_revolver()
			if p.revolver_ready:
				p._fire(Net.look_dir(p.view_pitch, p.view_yaw), false)
				p.cocking = false
				p.revolver_ready = false
		else:
			p._fire(Net.look_dir(p.view_pitch, p.view_yaw), false)
	else:
		if bool(w.get("revolver", false)):
			p.cocking = false
			p.revolver_ready = false
	if Input.is_action_pressed("altfire") and bool(w.get("revolver", false)):
		var tmp_ready: bool = p.revolver_ready
		p.revolver_ready = true
		p._fire(Net.look_dir(p.view_pitch, p.view_yaw), false, true)
		p.revolver_ready = tmp_ready
	if Input.is_action_pressed("reload"):
		reload(p)


static func reload(p) -> void:
	var w := Weapons.get_w(p.weapon_id)
	if p.clip >= int(w.clip) or p.reserve <= 0:
		return
	var need: int = int(w.clip) - p.clip
	var take := mini(need, p.reserve)
	p.clip += take
	p.reserve -= take
	p.next_attack = p.time + 2.2
	p.shots_fired = 0
