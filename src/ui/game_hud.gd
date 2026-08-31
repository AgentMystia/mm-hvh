class_name GameHUD
extends Control
## CS:GO 2018 HUD + skeet overlay. Resolver true-yaw drives ESP skeleton.

const F_UI := preload("res://assets/fonts/DejaVuSans.ttf")
const F_MONO := preload("res://assets/fonts/DejaVuSansMono.ttf")

const PITCH_N := ["off", "down", "up", "zero", "fake down", "random"]
const YAW_N := ["off", "backwards", "spin", "jitter", "sideways", "low delta", "distortion"]
const FAKE_N := ["off", "static", "opposite", "jitter", "lby"]
const LBY_N := ["off", "opposite", "sway", "predict", "break", "experimental"]
const RES_N := ["lby", "brute", "delta", "hybrid"]
const BASE_N := ["view", "at targets", "static"]
const OVR_N := ["auto", "left", "right", "lby", "last move"]
const PISTOL_N := ["r8", "deagle", "elite"]
const SNIPER_N := ["awp", "ssg08", "auto"]

var match_ctrl: Node
var _killfeed: Array = []
var _tab := 0
var _hits: Array = []
var _radar: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/maps/de_mirage/radar.png"):
		_radar = load("res://assets/maps/de_mirage/radar.png")
	Match.kill_feed.connect(_on_kill)


func bind(m: Node) -> void:
	match_ctrl = m


func _on_kill(attacker: String, victim: String, weapon: String, hs: bool) -> void:
	var tag := "  HS" if hs else ""
	_killfeed.push_front({"t": Time.get_ticks_msec() / 1000.0, "m": "%s  [%s%s]  %s" % [attacker, weapon, tag, victim]})
	if _killfeed.size() > 8:
		_killfeed.pop_back()


func push_kill(msg: String) -> void:
	_killfeed.push_front({"t": Time.get_ticks_msec() / 1000.0, "m": msg})
	if _killfeed.size() > 8:
		_killfeed.pop_back()


func _lp() -> Player:
	return match_ctrl.local_player if match_ctrl else null


func _process(_dt: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if (Cheat.menu_open or Cheat.buy_open) else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _input(event: InputEvent) -> void:
	# Menu toggle lives on Cheat autoload (web Insert is physical-keycode dead).
	# Still accept a click on the on-canvas MENU / watermark.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		for h in _hits:
			if h.rect.has_point(mb.position):
				h.fn.call()
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("buy"):
		if Match.is_buy_time():
			Cheat.buy_open = not Cheat.buy_open
			if Cheat.buy_open:
				Cheat.menu_open = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			elif not Cheat.menu_open:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if Cheat.menu_open:
			Cheat.toggle_menu()
		elif Cheat.buy_open:
			Cheat.buy_open = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if Cheat.buy_open and event is InputEventKey and event.pressed and not event.echo:
		_buy_key(event.keycode)
		get_viewport().set_input_as_handled()
		return
	if Cheat.menu_open and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				_tab = 0
			KEY_F2:
				_tab = 1
			KEY_F3:
				_tab = 2
			KEY_F4:
				_tab = 3
		get_viewport().set_input_as_handled()
		return
	if Cheat.menu_open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()


func _buy_key(code: int) -> void:
	var lp := _lp()
	if lp == null:
		return
	match code:
		KEY_1:
			lp.buy("elite")
		KEY_2:
			lp.buy("deagle")
		KEY_3:
			lp.buy("r8")
		KEY_4:
			lp.buy("ssg08")
		KEY_5:
			lp.buy("awp")
		KEY_6:
			lp.buy("g3sg1" if lp.team == Player.TEAM_T else "scar20")
		KEY_7:
			lp.buy("kevlar")
		KEY_8:
			lp.buy("helmet")
		KEY_9:
			lp.buy("kit")


func _t(pos: Vector2, text: String, size := 14, col := Color.WHITE, mono := false) -> void:
	draw_string(F_MONO if mono else F_UI, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw() -> void:
	_hits.clear()
	var sz := size
	if sz.x < 8.0:
		sz = get_viewport_rect().size
	if bool(Cheat.t("visuals/watermark", true)):
		_draw_watermark(sz)
	_draw_round_bar(sz)
	_draw_hp(sz)
	_draw_ammo(sz)
	_draw_killfeed(sz)
	if bool(Cheat.t("visuals/radar", true)):
		_draw_radar(sz)
	_draw_center(sz)
	if bool(Cheat.t("visuals/aa_arrows", true)):
		_draw_aa_arrows(sz)
	_draw_esp(sz)
	_draw_tracers()
	if bool(Cheat.t("visuals/indicators", true)):
		_draw_indicators(sz)
	_draw_plant(sz)
	if Cheat.buy_open:
		_draw_buy(sz)
	if Cheat.menu_open:
		_draw_menu(sz)
	if Input.is_action_pressed("scoreboard"):
		_draw_scoreboard(sz)


func _draw_watermark(sz: Vector2) -> void:
	var txt := "skeet.cc  |  HVH 2018  |  de_mirage  |  %dfps  |  %dtick" % [Engine.get_frames_per_second(), Match.tickrate]
	var w := F_MONO.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var wr := Rect2(sz.x - w - 22, 8, w + 14, 22)
	draw_rect(wr, Color(0.05, 0.06, 0.08, 0.78))
	draw_rect(Rect2(sz.x - w - 22, 8, 3, 22), Cheat.accent)
	_t(Vector2(sz.x - w - 14, 24), txt, 13, Color(0.85, 0.9, 0.95, 0.95), true)
	_hit(wr, func(): Cheat.toggle_menu())
	var menu := Rect2(sz.x - 96, sz.y - 78, 80, 28)
	draw_rect(menu, Color(0.07, 0.09, 0.11, 0.92))
	draw_rect(menu, Cheat.accent, false, 1.2)
	_t(menu.position + Vector2(14, 19), "MENU", 13, Color(0.9, 0.95, 0.85), true)
	_hit(menu, func(): Cheat.toggle_menu())
	_t(Vector2(sz.x - 268, sz.y - 86), "Insert / Home / ` / F10", 10, Color(0.55, 0.6, 0.58), true)


func _draw_round_bar(sz: Vector2) -> void:
	var clock := Match.clock()
	var phase := Match.phase_name()
	var cx := sz.x * 0.5
	draw_rect(Rect2(cx - 96, 8, 192, 36), Color(0.04, 0.05, 0.07, 0.82))
	_t(Vector2(cx - 84, 32), str(Match.t_score), 18, Color(0.92, 0.72, 0.28))
	_t(Vector2(cx - 22, 32), clock, 16, Color(0.95, 0.95, 0.95), true)
	_t(Vector2(cx + 62, 32), str(Match.ct_score), 18, Color(0.45, 0.7, 0.95))
	_t(Vector2(cx - 36, 52), phase, 11, Color(0.7, 0.75, 0.8), true)
	var lp := _lp()
	if lp:
		_t(Vector2(cx - 44, 68), "$%d" % lp.money, 13, Color(0.55, 0.9, 0.45), true)
	if Match.bomb_planted:
		_t(Vector2(cx - 50, 84), "BOMB %s  %.0fs" % [Match.bomb_site, Match.bomb_left], 12, Color(0.95, 0.35, 0.25), true)


func _draw_hp(sz: Vector2) -> void:
	var lp := _lp()
	if lp == null:
		return
	var y := sz.y - 42
	draw_rect(Rect2(16, y, 280, 28), Color(0.04, 0.05, 0.07, 0.75))
	var hp_w := 180.0 * clampf(float(lp.health) / 100.0, 0.0, 1.0)
	var hp_c := Color(0.85, 0.22, 0.22) if lp.health < 30 else Color(0.9, 0.9, 0.9)
	draw_rect(Rect2(20, y + 6, hp_w, 16), hp_c)
	_t(Vector2(24, y + 20), str(maxi(lp.health, 0)), 16, Color(0.05, 0.05, 0.05) if lp.health > 40 else Color.WHITE)
	_t(Vector2(210, y + 20), "ARMOR %d" % lp.armor, 12, Color(0.7, 0.75, 0.85), true)
	if lp.kit:
		_t(Vector2(292, y + 20), "KIT", 11, Color(0.4, 0.75, 1.0), true)


func _draw_ammo(sz: Vector2) -> void:
	var lp := _lp()
	if lp == null:
		return
	var w := Weapons.get_w(lp.weapon_id)
	var txt := "%s  %d / %d" % [w.display, lp.clip, lp.reserve]
	if lp.weapon_id == "r8":
		if lp.cocking and not lp.revolver_ready:
			txt += "  COCK %.0f%%" % (lp.revolver_cock_frac() * 100.0)
		elif lp.revolver_ready:
			txt += "  READY"
	var tw := F_MONO.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_rect(Rect2(sz.x - tw - 28, sz.y - 42, tw + 16, 28), Color(0.04, 0.05, 0.07, 0.75))
	_t(Vector2(sz.x - tw - 20, sz.y - 22), txt, 16, Color(0.92, 0.92, 0.92), true)


func _draw_killfeed(sz: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var y := 86.0
	for k in _killfeed:
		var age: float = now - k.t
		if age > 6.0:
			continue
		var a := 1.0 if age < 5.0 else 1.0 - (age - 5.0)
		_t(Vector2(sz.x - 420, y), k.m, 13, Color(0.95, 0.95, 0.95, a))
		y += 18


func _draw_radar(_sz: Vector2) -> void:
	var r := 156.0
	var origin := Vector2(18, 78)
	draw_rect(Rect2(origin, Vector2(r, r)), Color(0.02, 0.03, 0.04, 0.62))
	if _radar:
		draw_texture_rect(_radar, Rect2(origin, Vector2(r, r)), false, Color(1, 1, 1, 0.72))
	if match_ctrl == null:
		return
	var world: MapWorld = match_ctrl.world
	if world == null:
		return
	for p in match_ctrl.players:
		if not p.alive:
			continue
		var uv := world.world_to_radar(p.global_position)
		var px := origin + Vector2(uv.x, uv.y) * r
		var col := Color(0.92, 0.72, 0.28) if p.team == Player.TEAM_T else Color(0.4, 0.65, 0.95)
		if p.is_local:
			col = Color(1, 1, 1)
		draw_circle(px, 3.6 if p.is_local else 2.6, col)
	if Match.bomb_planted and Match.bomb_pos != Vector3.ZERO:
		var buv := world.world_to_radar(Match.bomb_pos)
		draw_circle(origin + Vector2(buv.x, buv.y) * r, 4.2, Color(0.95, 0.2, 0.15))


func _draw_center(sz: Vector2) -> void:
	var c := sz * 0.5
	var col := Color(0.2, 1.0, 0.35, 0.9)
	var gap := 4.0
	var len := 8.0
	draw_line(c + Vector2(-gap - len, 0), c + Vector2(-gap, 0), col, 1.4)
	draw_line(c + Vector2(gap, 0), c + Vector2(gap + len, 0), col, 1.4)
	draw_line(c + Vector2(0, -gap - len), c + Vector2(0, -gap), col, 1.4)
	draw_line(c + Vector2(0, gap), c + Vector2(0, gap + len), col, 1.4)
	draw_circle(c, 1.1, col)
	var lp := _lp()
	if lp and lp.scoped:
		draw_circle(c, 3.0, Color(0, 0, 0, 0.15))
	if Match.phase == Match.Phase.FREEZE:
		_t(c + Vector2(-78, -86), "ROUND %d  —  BUY" % Match.total_rounds, 16, Color(0.95, 0.9, 0.55))
		var hint := "B buy   1 Duals  2 Deagle  3 R8"
		if not Match.is_pistol_round():
			hint += "   4 Scout  5 AWP  6 Auto"
		_t(c + Vector2(-150, -64), hint, 12, Color(0.8, 0.8, 0.8))
		if Match.is_pistol_round():
			_t(c + Vector2(-70, -46), "PISTOL ROUND  $800", 12, Color(0.95, 0.75, 0.35))
	if Match.phase == Match.Phase.WARMUP:
		_t(c + Vector2(-52, -70), "WARMUP  %.0f" % Match.warmup_left, 16, Color(0.85, 0.9, 0.7))
	if Match.phase == Match.Phase.MATCH_END:
		var win := "TERRORISTS WIN" if Match.t_score > Match.ct_score else "COUNTER-TERRORISTS WIN"
		_t(c + Vector2(-110, -40), win, 18, Color(1, 0.85, 0.3))
	if lp and lp.flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 1, 1, clampf(lp.flash / 3.0, 0, 0.92)))


func _draw_aa_arrows(sz: Vector2) -> void:
	var lp := _lp()
	if lp == null or not lp.alive:
		return
	if not bool(Cheat.t("aa/enable", true)):
		return
	var c := Vector2(72.0, sz.y * 0.5 + 168.0)
	_arrow(c, lp.aa.real_yaw, Color(1.0, 0.25, 0.2, 0.92), 28.0)
	_arrow(c, lp.aa.fake_yaw, Color(0.25, 0.55, 1.0, 0.92), 20.0)
	_arrow(c, lp.aa.lby, Color(0.95, 0.85, 0.2, 0.9), 14.0)
	_t(c + Vector2(-18, 36), "REAL", 9, Color(1.0, 0.28, 0.2), true)
	_t(c + Vector2(8, 36), "FAKE", 9, Color(0.3, 0.55, 1.0), true)
	_t(c + Vector2(8, 48), "LBY", 9, Color(1.0, 0.86, 0.2), true)
	_draw_aa_world_axes()


func _draw_aa_world_axes() -> void:
	if match_ctrl == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var tp := bool(Cheat.t("visuals/thirdperson", true))
	for p in match_ctrl.players:
		if p == null or not p.alive:
			continue
		if p.is_local and not tp:
			continue
		_world_axis(cam, p, p.aa.real_yaw, Color(1.0, 0.22, 0.16, 0.95), "REAL", 1.55)
		_world_axis(cam, p, p.aa.fake_yaw, Color(0.22, 0.50, 1.0, 0.92), "FAKE", 1.18)
		_world_axis(cam, p, p.aa.lby, Color(1.0, 0.86, 0.14, 0.95), "LBY", 0.88)


func _world_axis(cam: Camera3D, p: Player, yaw: float, col: Color, label: String, length: float) -> void:
	var o: Vector3 = p.global_position + Vector3(0.0, 0.42, 0.0)
	var tip: Vector3 = o + Net.yaw_vec(yaw) * length
	if cam.is_position_behind(o) or cam.is_position_behind(tip):
		return
	var a: Vector2 = cam.unproject_position(o)
	var b: Vector2 = cam.unproject_position(tip)
	draw_line(a, b, Color(0, 0, 0, 0.55), 5.0)
	draw_line(a, b, col, 3.0)
	draw_circle(b, 5.0, col)
	_t(b + Vector2(6, -2), label, 11, col, true)


func _arrow(c: Vector2, yaw_deg: float, col: Color, radius: float) -> void:
	var a := deg_to_rad(-yaw_deg) + PI * 0.5
	var tip := c + Vector2(cos(a), -sin(a)) * radius
	draw_line(c, tip, col, 2.0)
	draw_circle(tip, 3.0, col)


func _draw_esp(_sz: Vector2) -> void:
	if match_ctrl == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vis_on := bool(Cheat.t("visuals/box", true))
	var lp := _lp()
	for p in match_ctrl.players:
		if p.is_local or not p.alive:
			continue
		if lp and p.team == lp.team:
			continue
		var head: Vector3 = p.head_pos()
		var feet: Vector3 = p.global_position
		if cam.is_position_behind(head) and cam.is_position_behind(feet):
			continue
		var hs := cam.unproject_position(head)
		var fs := cam.unproject_position(feet)
		var h := absf(fs.y - hs.y)
		var w := h * 0.42
		var box := Rect2(hs.x - w * 0.5, minf(hs.y, fs.y), w, h)
		var col := Color(0.2, 0.85, 0.4, 0.9)
		if vis_on:
			draw_rect(box.grow(1), Color(0, 0, 0, 0.7), false, 1.0)
			draw_rect(box, col, false, 1.0)
		if bool(Cheat.t("visuals/name", true)):
			_t(Vector2(box.position.x, box.position.y - 4), p.player_name, 11, Color(0.95, 0.95, 0.95))
		if bool(Cheat.t("visuals/health", true)):
			var hp_h := box.size.y * clampf(float(p.health) / 100.0, 0.0, 1.0)
			var hc := Color(0.3, 0.9, 0.35) if p.health > 40 else Color(0.9, 0.25, 0.2)
			draw_rect(Rect2(box.position.x - 5, box.position.y + box.size.y - hp_h, 3, hp_h), hc)
		if bool(Cheat.t("visuals/weapon", true)):
			_t(Vector2(box.position.x, box.end.y + 12), Weapons.get_w(p.weapon_id).display, 10, Color(0.8, 0.82, 0.85))
		if bool(Cheat.t("visuals/ammo", true)):
			_t(Vector2(box.position.x, box.end.y + 24), "%d/%d" % [p.clip, p.reserve], 10, Color(0.7, 0.7, 0.7), true)
		if bool(Cheat.t("visuals/flags", true)):
			var flags: PackedStringArray = []
			if p.scoped:
				flags.append("ZOOM")
			if p.ducking:
				flags.append("DUCK")
			if p.planting:
				flags.append("PLANT")
			if p.defusing:
				flags.append("DEFUSE")
			if Vector2(p.velocity.x, p.velocity.z).length() < 0.2:
				flags.append("LBY")
			flags.append(p.resolved_label)
			_t(Vector2(box.end.x + 4, box.position.y + 12), " ".join(flags), 10, Color(0.95, 0.75, 0.35), true)
		if bool(Cheat.t("visuals/skeleton", true)) and Engine.get_frames_per_second() >= 40:
			_draw_skel(cam, p)
		_t(Vector2(box.position.x, box.position.y - 16), "yaw %.0f" % p.resolved_yaw, 10, Color(1.0, 0.45, 0.35), true)


func _draw_skel(cam: Camera3D, p: Player) -> void:
	var yaw := p.resolved_yaw if bool(Cheat.t("visuals/skeleton_resolved", true)) else p.aa.fake_yaw
	var pitch := p.aa.real_pitch
	var origin := p.global_position
	var fwd := Net.yaw_vec(yaw)
	var right := Net.right_vec(yaw)
	var look := Net.look_dir(pitch, yaw)
	var pelvis := origin + Vector3(0, 0.92, 0)
	var chest := origin + Vector3(0, 1.28, 0)
	var neck := origin + Vector3(0, 1.48, 0)
	var head := neck + look * 0.16
	var l_sh := chest - right * 0.18 + Vector3(0, 0.08, 0)
	var r_sh := chest + right * 0.18 + Vector3(0, 0.08, 0)
	var l_el := l_sh - right * 0.12 + Vector3(0, -0.22, 0)
	var r_el := r_sh + right * 0.12 + Vector3(0, -0.22, 0)
	var l_h := l_el - right * 0.08 + Vector3(0, -0.22, 0)
	var r_h := r_el + right * 0.08 + Vector3(0, -0.22, 0)
	var l_hip := pelvis - right * 0.09
	var r_hip := pelvis + right * 0.09
	var l_kn := origin + Vector3(0, 0.48, 0) - right * 0.08
	var r_kn := origin + Vector3(0, 0.48, 0) + right * 0.08
	var l_ft := origin - right * 0.08 + fwd * 0.06
	var r_ft := origin + right * 0.08 + fwd * 0.06
	var col := Color(0.95, 0.95, 0.95, 0.85)
	var pts := [
		[pelvis, chest], [chest, neck], [neck, head],
		[chest, l_sh], [l_sh, l_el], [l_el, l_h],
		[chest, r_sh], [r_sh, r_el], [r_el, r_h],
		[pelvis, l_hip], [l_hip, l_kn], [l_kn, l_ft],
		[pelvis, r_hip], [r_hip, r_kn], [r_kn, r_ft],
	]
	for e in pts:
		if cam.is_position_behind(e[0]) or cam.is_position_behind(e[1]):
			continue
		draw_line(cam.unproject_position(e[0]), cam.unproject_position(e[1]), col, 1.4)


func _draw_tracers() -> void:
	if not bool(Cheat.t("visuals/tracers", true)) or match_ctrl == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for p in match_ctrl.players:
		for tr in p.tracers:
			if cam.is_position_behind(tr.a) or cam.is_position_behind(tr.b):
				continue
			var a := cam.unproject_position(tr.a)
			var b := cam.unproject_position(tr.b)
			draw_line(a, b, Color(1.0, 0.85, 0.2, clampf(tr.t * 4.0, 0, 0.8)), 1.2)


func _draw_indicators(sz: Vector2) -> void:
	var lp := _lp()
	if lp == null:
		return
	var y := sz.y * 0.5 + 96
	var x := 18.0
	_t(Vector2(x, y), "HC  %d%%" % int(Cheat.t("rage/hitchance", 55)), 12, Color(0.75, 0.8, 0.9), true)
	_t(Vector2(x, y + 16), "DMG %d" % int(Cheat.t("rage/mindmg", 20)), 12, Color(0.75, 0.8, 0.9), true)
	if lp.weapon_id == "r8":
		var rc := Color(0.3, 0.9, 0.4) if lp.revolver_ready else Color(0.9, 0.7, 0.2)
		var st := "READY" if lp.revolver_ready else ("COCK %.0f%%" % (lp.revolver_cock_frac() * 100.0) if lp.cocking else "idle")
		_t(Vector2(x, y + 32), "R8  %s" % st, 12, rc, true)
	if Input.is_action_pressed("move_left"):
		_t(Vector2(x, y + 96), "A  +left", 12, Color(0.45, 0.95, 0.55), true)
	elif Input.is_action_pressed("move_right"):
		_t(Vector2(x, y + 96), "D  +right", 12, Color(0.45, 0.95, 0.55), true)
	if bool(Cheat.t("aa/enable", true)):
		_t(Vector2(x, y + 48), "AA  %s  PITCH %s" % [YAW_N[clampi(int(Cheat.t("aa/yaw", 1)), 0, YAW_N.size() - 1)], PITCH_N[clampi(int(Cheat.t("aa/pitch", 1)), 0, PITCH_N.size() - 1)]], 12, Color(0.55, 0.75, 1.0), true)
	if bool(Cheat.t("aa/fakelag", true)):
		_t(Vector2(x, y + 64), "FL  %d" % int(Cheat.t("aa/fakelag_amt", 14)), 12, Color(0.7, 0.7, 0.75), true)
	_t(Vector2(x, y + 80), "RES %s" % (lp.resolved_label if false else RES_N[clampi(int(Cheat.t("rage/resolver_type", 3)), 0, 3)]), 12, Color(0.95, 0.55, 0.4), true)
	_t(Vector2(x, y + 112), "LOOK  p %.0f  y %.0f  z %.2f" % [lp.view_pitch, lp.view_yaw, lp.global_position.y], 12, Color(0.95, 0.95, 0.7), true)
	if bool(Cheat.t("aa/enable", true)):
		_t(Vector2(x, y + 128), "R %.0f  F %.0f  LBY %.0f" % [lp.aa.real_yaw, lp.aa.fake_yaw, lp.aa.lby], 12, Color(0.85, 0.82, 0.7), true)


func _draw_plant(sz: Vector2) -> void:
	var lp := _lp()
	if lp == null:
		return
	if lp.planting:
		var t := 1.0 - clampf(lp.plant_left / 3.2, 0, 1)
		_bar(sz, t, "PLANTING", Color(0.9, 0.3, 0.2))
	elif lp.defusing:
		var need := 5.0 if lp.kit else 10.0
		var t2 := 1.0 - clampf(lp.defuse_left / need, 0, 1)
		_bar(sz, t2, "DEFUSING", Color(0.3, 0.55, 1.0))


func _bar(sz: Vector2, t: float, label: String, col: Color) -> void:
	var w := 220.0
	var r := Rect2(sz.x * 0.5 - w * 0.5, sz.y * 0.62, w, 14)
	draw_rect(r, Color(0.05, 0.05, 0.06, 0.8))
	draw_rect(Rect2(r.position, Vector2(r.size.x * t, r.size.y)), col)
	_t(r.position + Vector2(8, 12), label, 11, Color.WHITE, true)


func _draw_buy(sz: Vector2) -> void:
	var lp := _lp()
	if lp == null:
		return
	var panel := Rect2(sz.x * 0.5 - 230, sz.y * 0.5 - 210, 460, 360)
	draw_rect(panel, Color(0.06, 0.07, 0.09, 0.94))
	draw_rect(panel, Color(0.35, 0.55, 0.8, 0.9), false, 1.0)
	var pistol := Match.is_pistol_round()
	_t(panel.position + Vector2(16, 28), "BUY  —  $%d   round %d%s" % [lp.money, Match.total_rounds, "  PISTOL" if pistol else ""], 16, Color(0.95, 0.9, 0.5))
	var lines: Array = [
		["1", "Dual Berettas", "elite"],
		["2", "Desert Eagle", "deagle"],
		["3", "R8 Revolver", "r8"],
		["4", "SSG 08 Scout", "ssg08"],
		["5", "AWP", "awp"],
		["6", "Auto (G3 / SCAR)", "auto"],
		["7", "Kevlar", "kevlar"],
		["8", "Kevlar + Helmet", "helmet"],
		["9", "Defuse Kit", "kit"],
	]
	var y := panel.position.y + 56
	for ln in lines:
		var id: String = ln[2]
		var cost := 0
		if id == "kevlar":
			cost = 650
		elif id == "helmet":
			cost = 1000 if lp.armor < 100 else 350
		elif id == "kit":
			cost = 400
		elif id == "auto":
			cost = 5000
		else:
			cost = int(Weapons.get_w(id).price)
		var ok := true
		if id in ["ssg08", "awp", "auto"] and pistol:
			ok = false
		if id == "kit" and lp.team != Player.TEAM_CT:
			ok = false
		var col := Color(0.9, 0.9, 0.9) if ok and lp.money >= cost else Color(0.45, 0.45, 0.48)
		if not ok:
			col = Color(0.35, 0.35, 0.38)
		_t(Vector2(panel.position.x + 24, y), "[%s]  %s" % [ln[0], ln[1]], 14, col, true)
		_t(Vector2(panel.position.x + 340, y), "$%d" % cost, 14, col, true)
		y += 26
	_t(panel.position + Vector2(16, panel.size.y - 18), "ESC close    pistol: Duals / Deagle / R8    Insert/Home/MENU: cheat", 11, Color(0.6, 0.62, 0.65))


func _draw_menu(sz: Vector2) -> void:
	var panel := Rect2(36, 86, 540, minf(sz.y - 110, 580))
	draw_rect(panel, Color(0.07, 0.08, 0.10, 0.97))
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 32)), Color(0.12, 0.14, 0.18, 1))
	draw_rect(Rect2(panel.position.x, panel.position.y, 4, panel.size.y), Cheat.accent)
	_t(panel.position + Vector2(16, 22), "skeet.cc    AIMBOT  ·  ANTIAIM  ·  VISUALS  ·  MISC", 13, Color(0.92, 0.94, 0.97), true)
	var tabs := ["Rage", "Anti-aim", "Visuals", "Misc"]
	for i in tabs.size():
		var tx := panel.position.x + 18 + i * 96
		var on := _tab == i
		var rr := Rect2(tx - 6, panel.position.y + 36, 88, 20)
		_hit(rr, func(): _tab = i)
		_t(Vector2(tx, panel.position.y + 52), tabs[i], 13, Color(0.95, 0.95, 0.95) if on else Color(0.55, 0.58, 0.62), true)
	var y := panel.position.y + 80
	var x := panel.position.x + 20
	match _tab:
		0:
			y = _tog(x, y, "Enabled", "rage/enable")
			y = _tog(x, y, "Silent", "rage/silent")
			y = _tog(x, y, "Auto fire", "rage/autoshoot")
			y = _tog(x, y, "Auto revolver", "rage/auto_revolver")
			y = _tog(x, y, "Auto wall", "rage/autowall")
			y = _tog(x, y, "Auto scope", "rage/autoscope")
			y = _tog(x, y, "Auto stop", "rage/autostop")
			y = _tog(x, y, "Multipoint", "rage/multipoint")
			y = _sl(x, y, "Hitchance", "rage/hitchance", 0, 100)
			y = _sl(x, y, "Minimum damage", "rage/mindmg", 1, 120)
			y = _sl(x, y, "FOV", "rage/fov", 1, 180)
			y = _tog(x, y, "Hitbox head", "rage/hitboxes/head")
			y = _tog(x, y, "Hitbox chest", "rage/hitboxes/chest")
			y = _tog(x, y, "Hitbox stomach", "rage/hitboxes/stomach")
			y = _tog(x, y, "Hitbox arms", "rage/hitboxes/arms")
			y = _tog(x, y, "Hitbox legs", "rage/hitboxes/legs")
			y = _tog(x, y, "Resolver", "rage/resolver")
			y = _enum(x, y, "Resolver", "rage/resolver_type", RES_N)
			y = _enum(x, y, "Override", "rage/resolver_override", OVR_N)
			_t(Vector2(x, y + 10), "F1–F4 tabs   click to change   Insert / Home / MENU close", 11, Color(0.5, 0.52, 0.55))
		1:
			y = _tog(x, y, "Enabled", "aa/enable")
			y = _enum(x, y, "Pitch", "aa/pitch", PITCH_N)
			y = _enum(x, y, "Yaw base", "aa/yaw_base", BASE_N)
			y = _enum(x, y, "Yaw", "aa/yaw", YAW_N)
			y = _sl(x, y, "Yaw add", "aa/yaw_add", -180, 180)
			y = _tog(x, y, "Jitter", "aa/jitter")
			y = _sl(x, y, "Jitter range", "aa/jitter_range", 0, 60)
			y = _enum(x, y, "Fake", "aa/fake", FAKE_N)
			y = _sl(x, y, "Fake limit", "aa/fake_limit", 0, 58)
			y = _enum(x, y, "LBY", "aa/lby", LBY_N)
			y = _sl(x, y, "LBY delta", "aa/lby_delta", 0, 180)
			y = _tog(x, y, "Freestanding", "aa/freestanding")
			y = _tog(x, y, "Fake lag", "aa/fakelag")
			y = _sl(x, y, "Fake lag", "aa/fakelag_amt", 1, 16)
			y = _tog(x, y, "Fake duck", "aa/fakeduck")
			y = _tog(x, y, "Slow walk", "aa/slowwalk")
			_t(Vector2(x, y + 8), "Z left  X back  C right   manual AA", 11, Color(0.5, 0.52, 0.55))
		2:
			y = _tog(x, y, "Box ESP", "visuals/box")
			y = _tog(x, y, "Name", "visuals/name")
			y = _tog(x, y, "Health", "visuals/health")
			y = _tog(x, y, "Weapon", "visuals/weapon")
			y = _tog(x, y, "Flags", "visuals/flags")
			y = _tog(x, y, "Skeleton (resolved yaw)", "visuals/skeleton")
			y = _tog(x, y, "Chams", "visuals/chams")
			y = _tog(x, y, "Chams XQZ", "visuals/chams_xqz")
			y = _tog(x, y, "Chams = resolved yaw", "visuals/chams_resolved")
			y = _tog(x, y, "Fake chams (enemy)", "visuals/chams_fake")
			y = _tog(x, y, "Glow", "visuals/glow")
			y = _tog(x, y, "Nightmode", "visuals/nightmode")
			y = _sl(x, y, "Night amount", "visuals/night_amt", 0, 100)
			y = _tog(x, y, "Thirdperson", "visuals/thirdperson")
			y = _sl(x, y, "TP distance", "visuals/tp_dist", 40, 200)
			y = _tog(x, y, "Local real chams", "visuals/local_real")
			y = _tog(x, y, "Local fake chams", "visuals/local_fake")
			y = _tog(x, y, "Local LBY chams", "visuals/local_lby")
			y = _tog(x, y, "AA axes (REAL/FAKE/LBY)", "visuals/aa_arrows")
			_t(Vector2(x, y + 8), "Enemy chams/skeleton = resolver true yaw", 11, Color(0.95, 0.55, 0.4))
		3:
			y = _tog(x, y, "Bunnyhop", "misc/bhop")
			y = _tog(x, y, "Autostrafer", "misc/autostrafe")
			y = _tog(x, y, "Hitsound", "misc/hitsound")
			y = _tog(x, y, "Autobuy", "misc/autobuy")
			y = _enum_str(x, y, "Pistol autobuy", "misc/autobuy_pistol", PISTOL_N)
			y = _enum_str(x, y, "Sniper autobuy", "misc/autobuy_sniper", SNIPER_N)
			y = _tog(x, y, "Autobuy armor", "misc/autobuy_armor")
			y = _tog(x, y, "Tracers", "visuals/tracers")
			y = _sl(x, y, "View FOV (H)", "visuals/fov", 70, 130)
			y = _sl(x, y, "Sensitivity", "misc/sens", 0.4, 6.0, 2)
			y = _sl(x, y, "Zoom sens", "misc/zoom_sens", 0.2, 1.5, 2)
			_t(Vector2(x, y + 12), "Mouse: m_yaw 0.022 raw, FOV is horizontal like CS:GO", 11, Color(0.6, 0.62, 0.55))


func _hit(r: Rect2, fn: Callable) -> void:
	_hits.append({"rect": r, "fn": fn})


func _tog(x: float, y: float, label: String, path: String) -> float:
	var on := bool(Cheat.t(path, false))
	_t(Vector2(x, y), ("[x] " if on else "[ ] ") + label, 13, Color(0.85, 0.88, 0.9) if on else Color(0.55, 0.58, 0.6), true)
	_hit(Rect2(x, y - 14, 500, 20), func(): Cheat.s(path, not bool(Cheat.t(path, false))))
	return y + 22


func _sl(x: float, y: float, label: String, path: String, lo: float, hi: float, decimals := 0) -> float:
	var v := float(Cheat.t(path, lo))
	var shown := ("%.2f" % v) if decimals > 0 else str(int(round(v)))
	_t(Vector2(x, y), "%s  %s" % [label, shown], 13, Color(0.85, 0.88, 0.9), true)
	var bar := Rect2(x + 250, y - 12, 160, 8)
	draw_rect(bar, Color(0.15, 0.16, 0.18))
	var t := clampf((v - lo) / (hi - lo), 0, 1)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)), Color(0.45, 0.7, 1.0))
	_hit(bar.grow(6), func():
		var mx := get_viewport().get_mouse_position().x
		var nt := clampf((mx - bar.position.x) / bar.size.x, 0.0, 1.0)
		Cheat.s(path, lerpf(lo, hi, nt))
	)
	return y + 22


func _enum(x: float, y: float, label: String, path: String, opts: Array) -> float:
	var i := clampi(int(Cheat.t(path, 0)), 0, opts.size() - 1)
	_t(Vector2(x, y), "%s  < %s >" % [label, opts[i]], 13, Color(0.85, 0.88, 0.9), true)
	_hit(Rect2(x, y - 14, 500, 20), func():
		var n := (int(Cheat.t(path, 0)) + 1) % opts.size()
		Cheat.s(path, n)
	)
	return y + 22


func _enum_str(x: float, y: float, label: String, path: String, opts: Array) -> float:
	var cur := str(Cheat.t(path, opts[0]))
	_t(Vector2(x, y), "%s  < %s >" % [label, cur], 13, Color(0.85, 0.88, 0.9), true)
	_hit(Rect2(x, y - 14, 500, 20), func():
		var i := opts.find(str(Cheat.t(path, opts[0])))
		Cheat.s(path, opts[(i + 1) % opts.size()])
	)
	return y + 22


func _draw_scoreboard(sz: Vector2) -> void:
	if match_ctrl == null:
		return
	var panel := Rect2(sz.x * 0.5 - 300, 70, 600, 440)
	draw_rect(panel, Color(0.05, 0.06, 0.08, 0.92))
	_t(panel.position + Vector2(16, 28), "SCOREBOARD   T %d  —  CT %d    round %d" % [Match.t_score, Match.ct_score, Match.total_rounds], 15, Color(0.95, 0.9, 0.55))
	var y := panel.position.y + 52
	_t(Vector2(panel.position.x + 16, y), "TERRORISTS", 12, Color(0.92, 0.72, 0.28), true)
	y += 8
	for p in match_ctrl.players:
		if p.team != Player.TEAM_T:
			continue
		y += 18
		var st := "" if p.alive else "DEAD"
		_t(Vector2(panel.position.x + 24, y), "%s   %d-%d   $%d  %s  %s" % [p.player_name, p.kills, p.deaths, p.money, Weapons.get_w(p.weapon_id).display, st], 12, Color(0.9, 0.9, 0.9) if p.alive else Color(0.5, 0.5, 0.5), true)
	y += 28
	_t(Vector2(panel.position.x + 16, y), "COUNTER-TERRORISTS", 12, Color(0.45, 0.7, 0.95), true)
	y += 8
	for p in match_ctrl.players:
		if p.team != Player.TEAM_CT:
			continue
		y += 18
		var st2 := "" if p.alive else "DEAD"
		_t(Vector2(panel.position.x + 24, y), "%s   %d-%d   $%d  %s  %s" % [p.player_name, p.kills, p.deaths, p.money, Weapons.get_w(p.weapon_id).display, st2], 12, Color(0.9, 0.9, 0.9) if p.alive else Color(0.5, 0.5, 0.5), true)
