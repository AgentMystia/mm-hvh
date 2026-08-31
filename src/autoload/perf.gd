extends Node
## Web 60 FPS budget: cap traces, turn off expensive viewport features.

var is_web := false
var ray_budget := 0
var wall_budget := 0
var local_ray := 0
var local_wall := 0


func _ready() -> void:
	is_web = OS.has_feature("web")
	Engine.max_fps = 60
	var root := get_tree().root
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	if is_web:
		root.scaling_3d_scale = 0.8
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR


func begin_physics() -> void:
	if is_web:
		ray_budget = 16
		wall_budget = 4
		local_ray = 14
		local_wall = 6
	else:
		ray_budget = 48
		wall_budget = 16
		local_ray = 24
		local_wall = 12


func take_ray(local := false) -> bool:
	if local:
		if local_ray <= 0:
			return false
		local_ray -= 1
		return true
	if ray_budget <= 0:
		return false
	ray_budget -= 1
	return true


func take_wall(local := false) -> bool:
	if local:
		if local_wall <= 0:
			return false
		local_wall -= 1
		return true
	if wall_budget <= 0:
		return false
	wall_budget -= 1
	return true
