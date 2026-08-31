extends Node
## 2018 gamesense/skeet-style cheat. Cheating is the designed MM HvH gameplay.

signal changed
signal menu_toggled(open: bool)

var menu_open := false
var buy_open := false
var accent := Color(0.517, 0.768, 0.298)
var cfg: Dictionary = {}
var player_ovr: Dictionary = {}  # instance_id -> {side, force_yaw}
var _menu_toggle_ms := 0
var _web_menu_cb = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_defaults()
	load_cfg()
	_bind_menu_keys()
	if OS.has_feature("web"):
		_install_web_menu()


func _bind_menu_keys() -> void:
	if not InputMap.has_action("cheat_menu"):
		InputMap.add_action("cheat_menu")
	# Web HTML5 often leaves physical_keycode at 0 for Insert — bind keycode too.
	for code in [KEY_INSERT, KEY_HOME, KEY_QUOTELEFT, KEY_F10, KEY_END]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		if not InputMap.event_is_action(e, "cheat_menu"):
			InputMap.action_add_event("cheat_menu", e)
	var f := InputEventKey.new()
	f.keycode = KEY_F
	f.physical_keycode = KEY_F
	if not InputMap.event_is_action(f, "thirdperson"):
		InputMap.action_add_event("thirdperson", f)


func _install_web_menu() -> void:
	# Keep the callback referenced or the JS proxy is garbage-collected.
	_web_menu_cb = JavaScriptBridge.create_callback(_on_web_menu)
	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return
	window._hvhMenuCb = _web_menu_cb
	JavaScriptBridge.eval("""
(function () {
  if (window.__hvhMenuHook) return;
  window.__hvhMenuHook = true;
  function fire(e) {
    if (e) { try { e.preventDefault(); e.stopPropagation(); } catch (err) {} }
    if (window._hvhMenuCb) { try { window._hvhMenuCb(); } catch (err) {} }
  }
  function isMenu(e) {
    var c = e.code || '', k = e.key || '', kc = e.keyCode || 0;
    return c === 'Insert' || k === 'Insert' || c === 'Home' || k === 'Home'
      || c === 'End' || k === 'End' || c === 'Backquote' || k === '`'
      || c === 'F10' || k === 'F10' || c === 'NumpadInsert' || kc === 45
      || kc === 36 || kc === 192 || kc === 121;
  }
  function onKey(e) {
    if (!isMenu(e)) return;
    fire(e);
  }
  window.addEventListener('keydown', onKey, true);
  document.addEventListener('keydown', onKey, true);
  function hookCanvas() {
    var c = document.getElementById('canvas');
    if (!c || c.__hvhKeys) return;
    c.__hvhKeys = true;
    c.addEventListener('keydown', onKey, true);
    c.setAttribute('tabindex', '0');
  }
  hookCanvas();
  setInterval(hookCanvas, 400);
  if (document.getElementById('hvh-menu-btn')) return;
  var b = document.createElement('button');
  b.id = 'hvh-menu-btn';
  b.type = 'button';
  b.textContent = 'MENU';
  b.title = 'Insert / Home / ` / F10';
  b.style.cssText = 'position:fixed;right:10px;bottom:10px;z-index:2147483647;pointer-events:auto;font:700 12px sans-serif;letter-spacing:0.06em;color:#e4eedc;background:#10151b;border:1px solid #84c44c;padding:10px 14px;cursor:pointer;opacity:0.94;';
  b.addEventListener('click', function (e) { fire(e); });
  document.body.appendChild(b);
})();
""")


func _on_web_menu(_args: Array) -> void:
	toggle_menu()


func is_menu_toggle_event(event: InputEvent) -> bool:
	if event.is_action_pressed("cheat_menu"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		var p: int = event.physical_keycode
		if k in [KEY_INSERT, KEY_HOME, KEY_QUOTELEFT, KEY_F10, KEY_END]:
			return true
		if p in [KEY_INSERT, KEY_HOME, KEY_QUOTELEFT, KEY_F10, KEY_END]:
			return true
		# HTML5 sometimes delivers Insert as KEY_UNKNOWN with unicode 0 and label
		if OS.get_keycode_string(k).to_lower() in ["insert", "home", "f10"]:
			return true
	return false


func _input(event: InputEvent) -> void:
	if is_menu_toggle_event(event):
		toggle_menu()
		buy_open = false
		get_viewport().set_input_as_handled()


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
			"chams_col": [0.12, 0.42, 1.0, 1.0],
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
			"sens": 2.0,
			"m_yaw": 0.022,
			"m_pitch": 0.022,
			"zoom_sens": 1.0,
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
	var now := Time.get_ticks_msec()
	if now - _menu_toggle_ms < 90:
		return
	_menu_toggle_ms = now
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
