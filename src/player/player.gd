class_name Player
extends CharacterBody3D
## CS:GO 2018 MM player: Source move, AA, LBY, R8 auto-revolver, plant/defuse.

const TEAM_T := 2
const TEAM_CT := 3

@export var is_bot := false
@export var is_local := false
@export var team := TEAM_T
@export var player_name := "player"

var health := 100
var armor := 0
var helmet := false
var kit := false
var money := 800
var alive := true
var ducking := false
var duck_amt := 0.0
var scoped := false
var weapon_id := "glock"
var clip := 20
var reserve := 120
var inv: Dictionary = {}
var view_pitch := 0.0
var view_yaw := 0.0
var next_attack := 0.0
var shots_fired := 0
var aa := AntiAim.new()
var resolver := Resolver.new()
var rage: Ragebot
var model: PlayerModel
var cam: Camera3D
var yaw_helper: Node3D
var resolved_yaw := 0.0
var resolved_label := "LBY"
var lag_origin := Vector3.ZERO
var choke := 0
var shot_this_tick := false
var revolver_ready := false
var revolver_ready_at := 0.0
var cocking := false
var planting := false
var plant_left := 0.0
var defusing := false
var defuse_left := 0.0
var kills := 0
var deaths := 0
var damage_dealt := 0
var last_place := ""
var want_autostop := false
var flash := 0.0
var on_ground_was := true
var stamina := 0.0
var hull: CollisionShape3D
var time := 0.0
var foot_cd := 0.0
var last_hurt_from: Player = null
var spawn_origin := Vector3.ZERO
var spawn_yaw := 0.0
var holding_bomb := false
var last_rage: Dictionary = {}
var tracers: Array = []
var bot_wish := Vector3.ZERO
var bot_duck := false
var bot_jump := false
var bot_fire := false
var qa_wish := Vector3.ZERO
var qa_steps := 0
var _origin_prev := Vector3.ZERO
var _origin_curr := Vector3.ZERO
var _cam_fov := 90.0
var viewmodel: MeshInstance3D


func _ready() -> void:
	rage = Ragebot.new(resolver)
	collision_layer = 2
	collision_mask = 1
	floor_stop_on_slope = true
	floor_block_on_wall = false
	floor_max_angle = deg_to_rad(45.573)
	floor_snap_length = Net.hu(8.0)
	safe_margin = Net.hu(1.5)
	max_slides = 8
	wall_min_slide_angle = deg_to_rad(0.0)
	set_process(true)
	var hs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(Net.PLAYER_HULL_W, Net.PLAYER_HULL_H, Net.PLAYER_HULL_W)
	hs.shape = box
	hs.position = Vector3(0, Net.PLAYER_HULL_H * 0.5, 0)
	add_child(hs)
	hull = hs
	yaw_helper = Node3D.new()
	add_child(yaw_helper)
	model = PlayerModel.new()
	add_child(model)
	model.setup(self)
	cam = Camera3D.new()
	cam.fov = 90
	cam.near = 0.06
	cam.far = 400
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.top_level = true
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	yaw_helper.add_child(cam)
	cam.position = Vector3(0, Net.EYE_STAND, 0)
	viewmodel = MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.055, 0.07, 0.42)
	viewmodel.mesh = vm
	var vm_mat := StandardMaterial3D.new()
	vm_mat.albedo_color = Color(0.08, 0.08, 0.09)
	vm_mat.roughness = 0.45
	viewmodel.material_override = vm_mat
	viewmodel.position = Vector3(0.16, -0.14, -0.32)
	viewmodel.rotation_degrees = Vector3(4.0, 2.0, 0.0)
	cam.add_child(viewmodel)
	if not is_local:
		cam.current = false
	lag_origin = global_position
	_origin_prev = global_position
	_origin_curr = global_position
	resolved_yaw = view_yaw
	add_to_group("players")


func eye() -> Vector3:
	var h := lerpf(Net.EYE_STAND, Net.EYE_DUCK, duck_amt)
	return global_position + Vector3(0, h, 0)


func head_pos() -> Vector3:
	return eye()


func revolver_cock_frac() -> float:
	var w := Weapons.get_w(weapon_id)
	if not bool(w.get("revolver", false)):
		return 1.0
	if revolver_ready:
		return 1.0
	if not cocking:
		return 0.0
	var cock := float(w.get("cock", 0.207))
	if cock <= 0.001:
		return 1.0
	return clampf(1.0 - (revolver_ready_at - time) / cock, 0.0, 1.0)


func add_money(amt: int) -> void:
	money = clampi(money + amt, 0, Match.MAX_MONEY)
	Match.money_changed.emit()
