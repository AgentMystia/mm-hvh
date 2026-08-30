extends Node
## Source-unit helpers. 1 Godot metre = 1/0.0254 CS units.

const HU := 0.0254
const TICK_HZ := 64
const TICK := 1.0 / 64.0
const GRAVITY := 800.0 * HU
const JUMP_IMPULSE := 301.993378 * HU
const MAX_SPEED := 250.0 * HU
const STOP_SPEED := 80.0 * HU
const DUCK_SPEED := 0.34
const ACCELERATE := 5.6
const AIRACCELERATE := 12.0
const AIR_CAP := 30.0 * HU
const FRICTION := 5.2
const STAMINA_RESTORE := 60.0
const PLAYER_HULL_W := 32.0 * HU
const PLAYER_HULL_H := 72.0 * HU
const PLAYER_DUCK_H := 54.0 * HU
const EYE_STAND := 64.0 * HU
const EYE_DUCK := 46.0 * HU
const HEAD_R := 4.5 * HU
const STEP := 18.0 * HU

static func hu(v: float) -> float:
	return v * HU

static func ang_norm(a: float) -> float:
	a = fmod(a + 180.0, 360.0)
	if a < 0.0:
		a += 360.0
	return a - 180.0

static func ang_delta(a: float, b: float) -> float:
	return ang_norm(a - b)

static func yaw_vec(yaw_deg: float) -> Vector3:
	var r := deg_to_rad(yaw_deg)
	return Vector3(-sin(r), 0.0, -cos(r))


static func look_basis(dir: Vector3) -> Basis:
	var d := dir.normalized()
	if d.length_squared() < 0.0001:
		d = Vector3.FORWARD
	var up := Vector3.UP
	if absf(d.dot(up)) > 0.995:
		up = Vector3.RIGHT
	return Basis.looking_at(d, up)
