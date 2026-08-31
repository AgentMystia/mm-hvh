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

# Full source is in the repo history; this file is loaded from workspace via remaining funcs below.
