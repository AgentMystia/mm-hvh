extends Control
## CS:GO 2018 HvH main menu.

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.08)
	add_child(bg)
	var accent := ColorRect.new()
	accent.position = Vector2(0, 0)
	accent.size = Vector2(6, 720)
	accent.set_anchor(SIDE_BOTTOM, 1)
	accent.offset_bottom = 0
	accent.color = Color(0.517, 0.768, 0.298)
	add_child(accent)
	var title := Label.new()
	title.text = "HVH 2018"
	title.position = Vector2(48, 72)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.92, 0.94, 0.9))
	add_child(title)
	var sub := Label.new()
	sub.text = "de_mirage  ·  Matchmaking competitive  ·  $800 start"
	sub.position = Vector2(52, 128)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.65, 0.7, 0.62))
	add_child(sub)
	var body := Label.new()
	body.text = "5v5 bots. Pistol rounds: Dual Berettas, Desert Eagle, or R8 Revolver.\nGun rounds: Scout, AWP, or Auto (G3SG1 / SCAR-20).\nCheats are the game: ragebot, Auto-Revolver, LBY breaker, resolver.\nResolver true yaw drives enemy chams and skeleton. Thirdperson shows Real / Fake / LBY."
	body.position = Vector2(52, 168)
	body.size = Vector2(720, 120)
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.78, 0.8, 0.76))
	add_child(body)
	_btn("PLAY AS TERRORIST", Vector2(52, 320), Color(0.72, 0.52, 0.18), _on_play_t)
	_btn("PLAY AS COUNTER-TERRORIST", Vector2(52, 380), Color(0.28, 0.48, 0.72), _on_play_ct)
	var keys := Label.new()
	keys.text = "WASD move   mouse look   LMB fire   RMB scope/R8 fan\nE plant/defuse   B buy   Insert/Home/`/F10 or MENU cheat   Tab scoreboard   F thirdperson\nZ/X/C manual AA left/back/right"
	keys.position = Vector2(52, 460)
	keys.size = Vector2(700, 80)
	keys.add_theme_font_size_override("font_size", 14)
	keys.add_theme_color_override("font_color", Color(0.55, 0.58, 0.52))
	add_child(keys)
	var foot := Label.new()
	foot.text = "skeet.cc flavour  ·  64 tick  ·  MR15  ·  freeze 15s  ·  bomb 40s"
	foot.position = Vector2(52, 660)
	foot.add_theme_font_size_override("font_size", 13)
	foot.add_theme_color_override("font_color", Color(0.45, 0.5, 0.42))
	add_child(foot)


func _btn(text: String, pos: Vector2, col: Color, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(340, 44)
	b.add_theme_font_size_override("font_size", 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = col.lightened(0.12)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))
	b.pressed.connect(cb)
	add_child(b)


func _on_play_t() -> void:
	Match.local_team = Match.Team.T
	_go()


func _on_play_ct() -> void:
	Match.local_team = Match.Team.CT
	_go()


func _go() -> void:
	Sfx.play2d("res://assets/sounds/sfx/ui_click.wav", -8)
	get_tree().change_scene_to_file("res://scenes/match.tscn")
