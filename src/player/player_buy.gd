class_name PlayerBuy
extends RefCounted
## MM buy: $800 pistol rounds, $16000 cap, autobuy pistol before kevlar.


static func add_money(p, amt: int) -> void:
	p.money = clampi(p.money + amt, 0, Match.MAX_MONEY)
	Match.money_changed.emit()


static func reset_round(p, origin: Vector3, yaw: float, give_c4: bool) -> void:
	p.alive = true
	p.health = 100
	p.planting = false
	p.defusing = false
	p.scoped = false
	p.shots_fired = 0
	p.velocity = Vector3.ZERO
	p.global_position = origin
	p.spawn_origin = origin
	p.move_ok = origin
	p.grounded = true
	p.move_stuck = 0
	p.view_yaw = yaw
	p.spawn_yaw = yaw
	p.lag_origin = origin
	p.visible = true
	p.cocking = false
	p.revolver_ready = false
	p.holding_bomb = give_c4
	if Match.is_pistol_round() or Match.total_rounds <= 1:
		p.armor = 0
		p.helmet = false
		p.kit = false
		p.inv.clear()
		equip(p, Weapons.default_pistol(p.team), true)
		p.money = Match.OT_MONEY if Match.overtime else Match.START_MONEY
	else:
		if not p.inv.has(2):
			equip(p, Weapons.default_pistol(p.team), true)
		if p.inv.has(1):
			equip(p, p.inv[1], false)
		else:
			equip(p, Weapons.default_pistol(p.team), true)
	if give_c4:
		p.inv[5] = "c4"
	p.aa.reset()
	p.model.visible = true
	p._origin_prev = origin
	p._origin_curr = origin


static func equip(p, id: String, refill := false) -> void:
	var w := Weapons.get_w(id)
	p.weapon_id = id
	p.inv[int(w.slot)] = id
	if refill or p.clip <= 0:
		p.clip = int(w.clip)
		p.reserve = int(w.ammo)
	p.shots_fired = 0
	p.scoped = false
	p.cocking = false
	p.revolver_ready = false


static func can_buy(p) -> bool:
	return p.alive and Match.is_buy_time()


static func buy(p, id: String) -> bool:
	if not can_buy(p):
		return false
	if id == "kevlar":
		if p.money < 650 or p.armor >= 100:
			return false
		add_money(p, -650)
		p.armor = 100
		return true
	if id == "helmet":
		var cost := 1000 if p.armor < 100 else 350
		if p.helmet or p.money < cost:
			return false
		add_money(p, -cost)
		p.armor = 100
		p.helmet = true
		return true
	if id == "kit":
		if int(p.team) != 3 or p.kit or p.money < 400:
			return false
		add_money(p, -400)
		p.kit = true
		return true
	var w := Weapons.get_w(id)
	if Match.is_pistol_round() and w.get("type") == "sniper":
		return false
	if w.has("team") and int(w.team) != 0 and int(w.team) != p.team:
		return false
	if p.money < int(w.price):
		return false
	add_money(p, -int(w.price))
	equip(p, id, true)
	Sfx.play2d("res://assets/sounds/sfx/buy.wav", -6)
	return true


static func autobuy(p) -> void:
	if not bool(Cheat.t("misc/autobuy", true)) and not p.is_bot:
		return
	if not can_buy(p):
		return
	# Pistol round is $800 — buy the pistol first or kevlar eats the R8.
	if Match.is_pistol_round():
		var pid := str(Cheat.t("misc/autobuy_pistol", "r8"))
		if p.is_bot:
			pid = ["r8", "deagle", "elite"][absi(p.player_name.hash()) % 3]
		if not buy(p, pid):
			if not buy(p, "deagle"):
				buy(p, "elite")
		autobuy_armor(p)
		return
	autobuy_armor(p)
	var sn := str(Cheat.t("misc/autobuy_sniper", "awp"))
	if p.is_bot:
		sn = ["awp", "ssg08", "auto"][absi(p.player_name.hash()) % 3]
	if sn == "auto":
		sn = "g3sg1" if int(p.team) == 2 else "scar20"
	if not buy(p, sn):
		if not buy(p, "awp"):
			if not buy(p, "ssg08"):
				if not buy(p, "r8"):
					buy(p, "deagle")


static func autobuy_armor(p) -> void:
	if not bool(Cheat.t("misc/autobuy_armor", true)) and not p.is_bot:
		return
	if p.money >= 1000 and not p.helmet:
		buy(p, "helmet")
	elif p.money >= 650 and p.armor < 100:
		buy(p, "kevlar")
	if int(p.team) == 3 and not p.kit and p.money >= 400 and not Match.is_pistol_round():
		buy(p, "kit")
