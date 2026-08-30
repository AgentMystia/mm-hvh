extends Node
## CS:GO 2018 weapon tables (damage, armor ratio, RPM, spread, recoil).

var db: Dictionary = {}

func _ready() -> void:
	_reg("knife", {"slot": 3, "price": 0, "damage": 40, "hs": 1.0, "armor": 0.85, "rpm": 0, "clip": 0, "ammo": 0, "move": 250, "spread": 0.0, "range_mod": 1.0, "pen": 1.0, "type": "knife", "snd": "res://assets/sounds/weapons/knife_slash1.wav", "cycle": 0.4, "recoil": [], "kill": 1500, "display": "KNIFE"})
	_reg("glock", {"slot": 2, "price": 0, "damage": 28, "hs": 4.0, "armor": 0.47, "rpm": 400, "clip": 20, "ammo": 120, "move": 240, "spread": 0.5, "range_mod": 0.85, "pen": 1.0, "type": "pistol", "snd": "res://assets/sounds/weapons/glock18-2.wav", "cycle": 0.15, "recoil": _pistol_recoil(8), "kill": 300, "display": "GLOCK-18", "team": 2})
	_reg("usp", {"slot": 2, "price": 0, "damage": 35, "hs": 4.0, "armor": 0.505, "rpm": 352, "clip": 12, "ammo": 24, "move": 240, "spread": 0.4, "range_mod": 0.91, "pen": 1.0, "type": "pistol", "snd": "res://assets/sounds/weapons/usp1.wav", "cycle": 0.17, "recoil": _pistol_recoil(6), "kill": 300, "display": "USP-S", "team": 3})
	_reg("elite", {"slot": 2, "price": 400, "damage": 38, "hs": 4.0, "armor": 0.475, "rpm": 750, "clip": 30, "ammo": 120, "move": 240, "spread": 0.55, "range_mod": 0.79, "pen": 1.0, "type": "pistol", "snd": "res://assets/sounds/weapons/glock18-2.wav", "cycle": 0.08, "recoil": _pistol_recoil(12), "kill": 300, "display": "DUAL BERETTAS", "dual": true})
	_reg("p250", {"slot": 2, "price": 300, "damage": 38, "hs": 4.0, "armor": 0.642, "rpm": 400, "clip": 13, "ammo": 26, "move": 240, "spread": 0.5, "range_mod": 0.9, "pen": 1.0, "type": "pistol", "snd": "res://assets/sounds/weapons/usp1.wav", "cycle": 0.15, "recoil": _pistol_recoil(7), "kill": 300, "display": "P250"})
	_reg("tec9", {"slot": 2, "price": 500, "damage": 33, "hs": 4.0, "armor": 0.603, "rpm": 500, "clip": 18, "ammo": 90, "move": 240, "spread": 0.6, "range_mod": 0.79, "pen": 1.0, "type": "pistol", "snd": "res://assets/sounds/weapons/glock18-2.wav", "cycle": 0.12, "recoil": _pistol_recoil(9), "kill": 300, "display": "TEC-9", "team": 2})
	_reg("deagle", {"slot": 2, "price": 700, "damage": 63, "hs": 4.0, "armor": 0.812, "rpm": 267, "clip": 7, "ammo": 35, "move": 230, "spread": 0.81, "range_mod": 0.81, "pen": 2.0, "type": "pistol", "snd": "res://assets/sounds/weapons/deagle-1.wav", "cycle": 0.225, "recoil": _deagle_recoil(), "kill": 300, "display": "DESERT EAGLE"})
	_reg("r8", {"slot": 2, "price": 800, "damage": 86, "hs": 4.0, "armor": 0.939, "rpm": 120, "clip": 8, "ammo": 8, "move": 220, "spread": 0.52, "range_mod": 0.81, "pen": 2.0, "type": "pistol", "snd": "res://assets/sounds/weapons/deagle-1.wav", "cycle": 0.4, "recoil": [Vector2(-3.2, 0.1)], "kill": 300, "display": "R8 REVOLVER", "revolver": true, "cock": 0.207, "alt_cycle": 0.166, "alt_spread": 3.2})
	_reg("ak47", {"slot": 1, "price": 2700, "damage": 36, "hs": 4.0, "armor": 0.778, "rpm": 600, "clip": 30, "ammo": 90, "move": 215, "spread": 0.6, "range_mod": 0.98, "pen": 2.0, "type": "rifle", "snd": "res://assets/sounds/weapons/ak47-1.wav", "cycle": 0.1, "recoil": _ak_recoil(), "kill": 300, "display": "AK-47", "team": 2})
	_reg("m4a4", {"slot": 1, "price": 3100, "damage": 33, "hs": 4.0, "armor": 0.7, "rpm": 666, "clip": 30, "ammo": 90, "move": 225, "spread": 0.5, "range_mod": 0.97, "pen": 2.0, "type": "rifle", "snd": "res://assets/sounds/weapons/m4a1-1.wav", "cycle": 0.09, "recoil": _m4_recoil(), "kill": 300, "display": "M4A4", "team": 3})
	_reg("awp", {"slot": 1, "price": 4750, "damage": 115, "hs": 1.0, "armor": 0.97, "rpm": 41, "clip": 10, "ammo": 30, "move": 200, "spread": 0.08, "range_mod": 0.99, "pen": 2.5, "type": "sniper", "snd": "res://assets/sounds/weapons/awp1.wav", "cycle": 1.455, "recoil": [Vector2(4.0, 0.0)], "zoom": true, "zoom_fov": 40, "scoped_speed": 100, "kill": 100, "display": "AWP"})
	_reg("ssg08", {"slot": 1, "price": 1700, "damage": 88, "hs": 1.0, "armor": 0.98, "rpm": 48, "clip": 10, "ammo": 90, "move": 230, "spread": 0.1, "range_mod": 0.98, "pen": 2.5, "type": "sniper", "snd": "res://assets/sounds/weapons/scout_fire-1.wav", "cycle": 1.25, "recoil": [Vector2(3.0, 0.0)], "zoom": true, "zoom_fov": 40, "scoped_speed": 230, "kill": 300, "display": "SSG 08"})
	_reg("g3sg1", {"slot": 1, "price": 5000, "damage": 80, "hs": 1.0, "armor": 0.825, "rpm": 240, "clip": 20, "ammo": 90, "move": 215, "spread": 0.3, "range_mod": 0.98, "pen": 2.5, "type": "sniper", "snd": "res://assets/sounds/weapons/g3sg1-1.wav", "cycle": 0.25, "recoil": _auto_recoil(), "zoom": true, "zoom_fov": 40, "scoped_speed": 150, "kill": 300, "display": "G3SG1", "team": 2})
	_reg("scar20", {"slot": 1, "price": 5000, "damage": 80, "hs": 1.0, "armor": 0.825, "rpm": 240, "clip": 20, "ammo": 90, "move": 215, "spread": 0.3, "range_mod": 0.98, "pen": 2.5, "type": "sniper", "snd": "res://assets/sounds/weapons/g3sg1-1.wav", "cycle": 0.25, "recoil": _auto_recoil(), "zoom": true, "zoom_fov": 40, "scoped_speed": 150, "kill": 300, "display": "SCAR-20", "team": 3})
	_reg("c4", {"slot": 5, "price": 0, "damage": 500, "hs": 1.0, "armor": 1.0, "rpm": 0, "clip": 1, "ammo": 0, "move": 250, "spread": 0.0, "range_mod": 1.0, "pen": 0.0, "type": "c4", "snd": "res://assets/sounds/sfx/bomb_plant.wav", "cycle": 3.2, "recoil": [], "kill": 0, "display": "C4"})


func mm_buy_list(team: int, pistol_round: bool) -> Array:
	var pistols := ["elite", "deagle", "r8"]
	if pistol_round:
		return pistols.duplicate()
	var snipers: Array = ["ssg08", "awp"]
	snipers.append("g3sg1" if team == 2 else "scar20")
	return pistols + snipers


func default_pistol(team: int) -> String:
	return "glock" if team == 2 else "usp"


func get_w(id: String) -> Dictionary:
	if db.has(id):
		return db[id]
	return db["glock"]


func _reg(id: String, d: Dictionary) -> void:
	d["id"] = id
	if not d.has("display"):
		d["display"] = id.to_upper()
	db[id] = d


func _ak_recoil() -> Array:
	# Classic AK spray (pitch, yaw) degrees — 2018 pattern
	return [
		Vector2(0.0, 0.0), Vector2(-1.8, 0.2), Vector2(-3.5, -0.4), Vector2(-5.0, 0.6),
		Vector2(-6.4, -0.8), Vector2(-7.6, 1.4), Vector2(-8.6, -1.8), Vector2(-9.4, 2.2),
		Vector2(-10.0, -2.6), Vector2(-10.4, 3.2), Vector2(-10.6, -3.8), Vector2(-10.7, 4.0),
		Vector2(-10.6, -3.2), Vector2(-10.4, 2.4), Vector2(-10.1, -1.6), Vector2(-9.8, 0.8),
		Vector2(-9.5, -2.8), Vector2(-9.2, 3.6), Vector2(-9.0, -4.0), Vector2(-8.8, 3.2),
		Vector2(-8.6, -2.2), Vector2(-8.5, 1.4), Vector2(-8.4, -0.6), Vector2(-8.3, 2.0),
		Vector2(-8.2, -3.0), Vector2(-8.1, 3.4), Vector2(-8.0, -2.4), Vector2(-8.0, 1.0),
		Vector2(-7.9, -1.2), Vector2(-7.9, 0.4)
	]


func _m4_recoil() -> Array:
	var a: Array = []
	for i in 30:
		a.append(Vector2(-i * 0.28, sin(i * 0.7) * min(i, 10) * 0.18))
	return a


func _pistol_recoil(n: int) -> Array:
	var a: Array = []
	for i in n:
		a.append(Vector2(-0.8 - i * 0.35, (1 if i % 2 == 0 else -1) * 0.4))
	return a


func _deagle_recoil() -> Array:
	return [Vector2(-4.2, 0.2), Vector2(-5.5, -0.8), Vector2(-6.0, 1.2), Vector2(-6.2, -1.0), Vector2(-6.3, 0.6), Vector2(-6.3, -0.4), Vector2(-6.2, 0.2)]


func _auto_recoil() -> Array:
	var a: Array = []
	for i in 20:
		a.append(Vector2(-1.2 - i * 0.15, sin(i * 0.9) * 0.5))
	return a


func _smg_recoil() -> Array:
	var a: Array = []
	for i in 30:
		a.append(Vector2(-0.4 - i * 0.12, sin(i * 1.1) * 0.7))
	return a


func hitgroup_mul(group: String, w: Dictionary) -> float:
	match group:
		"head":
			return float(w.get("hs", 4.0))
		"stomach":
			return 1.25
		"leg", "legs":
			return 0.75
		_:
			return 1.0


func damage_vs(w: Dictionary, group: String, armored: bool, helmet: bool, dist: float) -> int:
	var dmg := float(w.damage) * pow(float(w.range_mod), dist / 500.0)
	dmg *= hitgroup_mul(group, w)
	var apply_armor := armored
	if group == "head":
		apply_armor = helmet
	if apply_armor:
		dmg *= float(w.armor)
	return int(round(dmg))
