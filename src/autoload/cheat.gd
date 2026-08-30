extends Node
## 2018 gamesense/skeet-style cheat. Cheating is the designed MM HvH gameplay.

signal changed
signal menu_toggled(open: bool)

var menu_open := false
var buy_open := false
var accent := Color(0.517, 0.768, 0.298)
var cfg: Dictionary = {}
var player_ovr: Dictionary = {}  # instance_id -> {side, force_yaw}


func _ready() -> void:
	_defaults()
	load_cfg()


func _defaults() -> void:
	cfg = {
		"rage": {
			"enable": true,
			"silent": true,
			"autoshoot": true,
			"autowall": true,
			"autoscope": true,
			"autostop": true,
			"auto_revolver": true,
			"multipoint": true,
			"delay_shot": false,
			"hitchance": 55,
			"hitchance_ovr": 0,
			"mindmg": 20,
			"mindmg_ovr": 0,
			"fov": 180,
			"hitboxes": {"head": true, "chest": true, "stomach": true, "arms": false, "legs": false},
			"baim_lethal": true,
			"baim_air": false,
			"prefer_body": false,
			"resolver": true,
			"resolver_type": 3,
			"resolver_override": 0,  # 0 auto, 1 left, 2 right, 3 lby, 4 last move
			"shoot_duck": true,
			"shoot_jump": false,
		},
		"aa": {
			"enable": true,
			"pitch": 1,
			"yaw_base": 1,
			"yaw": 1,
			"yaw_add": 0,
			"jitter": true,
			"jitter_type": 0,
			"jitter_range": 12,
			"fake": 2,
			"fake_limit": 58,
			"lby": 4,  # break — MM HvH 2018 default
			"lby_delta": 116,
			"freestanding": true,
			"manual": 0,
			"fakelag": true,
			"fakelag_amt": 14,
			"fakelag_var": 2,
			"fakelag_on_peek": true,
			"fakeduck": false,
			"slowwalk": false,
			"slowwalk_spd": 80,
		},
		"legit": {
			"enable": false,
			"fov": 3.5,
			"smooth": 6.0,
			"trigger": false,
			"rcs": true,
		},
		"visuals": {
			"box": true,
			"name": true,
			"health": true,
			"weapon": true,
			"ammo": true,
			"flags": true,
			"skeleton": true,
			"skeleton_resolved": true,  # skeleton = resolver true yaw
			"glow": true,
			"chams": true,
			"chams_xqz": true,
			"chams_resolved": true,  # enemy chams follow resolved real yaw
			"chams_fake": true,  # ghost at fake yaw
			"chams_mat": 0,
			"chams_col": [0.2, 0.85, 0.35, 1.0],
			"chams_xqz_col": [0.85, 0.25, 0.55, 1.0],
			"chams_fake_col": [0.25, 0.45, 1.0, 0.35],
			"local_chams": true,
			"local_real": true,
			"local_fake": true,
			"local_lby": true,
			"local_real_col": [1.0, 0.2, 0.2, 0.55],
			"local_fake_col": [0.2, 0.45, 1.0, 0.45],
			"local_lby_col": [1.0, 0.85, 0.15, 0.7],
			"nightmode": true,
			"night_amt": 40,
			"thirdperson": true,
			"tp_dist": 120,
			"fov": 110,
			"aspect": 0.0,
			"watermark": true,
			"indicators": true,
			"tracers": true,
			"hitmarker": true,
			"spread_circ": false,
			"aa_arrows": true,
			"radar": true,
			"hitboxes": false,
		},
		"misc": {
			"bhop": true,
			"autostrafe": 1,
			"hitsound": true,
			"clantag": "HVH 2018",
			"autobuy": true,
			"autobuy_pistol": "r8",  # elite / deagle / r8
			"autobuy_sniper": "awp",  # ssg08 / awp / auto
			"autobuy_armor": true,
			"sniper_crosshair": true,
			"rank": "Legendary Eagle Master",
			"edgejump": false,
		},
		"players": {},
		"config": {"name": "mm_hvh"},
	}


func t(path: String, default: Variant = null) -> Variant:
	var cur: Variant = cfg
	for k in path.split("/"):
		if typeof(cur) != TYPE_DICTIONARY or not cur.has(k):
			return default
		cur = cur[k]
	return cur


func s(path: String, val: Variant) -> void:
	var parts := path.split("/")
	var cur: Dictionary = cfg
	for i in range(parts.size() - 1):
		if not cur.has(parts[i]) or typeof(cur[parts[i]]) != TYPE_DICTIONARY:
			cur[parts[i]] = {}
		cur = cur[parts[i]]
	cur[parts[parts.size() - 1]] = val
	changed.emit()


func toggle_menu() -> void:
	menu_open = not menu_open
	if menu_open:
		buy_open = false
	menu_toggled.emit(menu_open)
	if menu_open or buy_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func save_cfg(name := "mm_hvh") -> void:
	var f := FileAccess.open("user://%s.json" % name, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cfg, "\t"))


func load_cfg(name := "mm_hvh") -> void:
	if not FileAccess.file_exists("user://%s.json" % name):
		return
	var f := FileAccess.open("user://%s.json" % name, FileAccess.READ)
	if f == null:
		return
	var j = JSON.parse_string(f.get_as_text())
	if typeof(j) == TYPE_DICTIONARY:
		_merge(cfg, j)


func _merge(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		if dst.has(k) and typeof(dst[k]) == TYPE_DICTIONARY and typeof(src[k]) == TYPE_DICTIONARY:
			_merge(dst[k], src[k])
		else:
			dst[k] = src[k]
