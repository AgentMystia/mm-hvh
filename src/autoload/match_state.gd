extends Node
## CS:GO 2018 Matchmaking competitive rules (MR15, $800 start, pistol rounds).

enum Phase { WARMUP, FREEZE, LIVE, BOMB, ROUND_END, MATCH_END, OVERTIME }
enum Team { NONE = 0, T = 2, CT = 3 }

signal phase_changed(phase: int)
signal kill_feed(attacker: String, victim: String, weapon: String, hs: bool)
signal bomb_update(planted: bool, remaining: float, site: String)
signal score_changed
signal money_changed
signal round_reset
signal side_swapped

const START_MONEY := 800
const MAX_MONEY := 16000
const OT_MONEY := 10000
const WIN_ELIM := 3250
const WIN_BOMB := 3500
const LOSS_BASE := 1400
const LOSS_STEP := 500
const LOSS_MAX := 3400
const PLANT_TEAM_BONUS := 800
const PLANT_PLAYER := 300
const KILL_PENALTY_FF := -300

var phase: int = Phase.WARMUP
var round_idx := 0  ## 1-based competitive round in the half
var total_rounds := 0
var t_score := 0
var ct_score := 0
var freeze_left := 0.0
var buy_left := 0.0
var round_left := 0.0
var bomb_left := 0.0
var bomb_planted := false
var bomb_exploded := false
var bomb_site := ""
var bomb_pos := Vector3.ZERO
var bomb_planter: Node = null
var defusing := false
var defuse_left := 0.0
var defuser: Node = null
var freeze_time := 15.0
var buy_time := 20.0
var round_time := 115.0
var bomb_time := 40.0
var warmup_left := 5.0
var paused := false
var local_team: int = Team.T
var ping_ms := 28
var tickrate := 64
var loss_bonus_t := 0
var loss_bonus_ct := 0
var overtime := false
var ot_halves := 0
var last_winner := 0
var last_reason := ""
var swapped := false  ## true after halftime swap


func is_pistol_round() -> bool:
	if overtime:
		return false
	# MM: first round of each half (0-0, then  after 15 rounds played).
	var played := t_score + ct_score
	return played == 0 or played == 15


func is_buy_time() -> bool:
	return phase == Phase.WARMUP or phase == Phase.FREEZE or (phase == Phase.LIVE and buy_left > 0.0 and not bomb_planted)


func in_play() -> bool:
	return phase == Phase.LIVE or phase == Phase.BOMB


func clock() -> String:
	var t := 0.0
	match phase:
		Phase.WARMUP:
			t = warmup_left
		Phase.FREEZE:
			t = freeze_left
		Phase.LIVE:
			t = round_left
		Phase.BOMB:
			t = bomb_left
		Phase.ROUND_END:
			t = round_left
		_:
			t = 0.0
	var s := maxi(int(ceil(t)), 0)
	return "%d:%02d" % [s / 60, s % 60]


func phase_name() -> String:
	match phase:
		Phase.WARMUP:
			return "WARMUP"
		Phase.FREEZE:
			return "FREEZE"
		Phase.LIVE:
			return "LIVE"
		Phase.BOMB:
			return "BOMB"
		Phase.ROUND_END:
			return "ROUND"
		Phase.MATCH_END:
			return "MATCH"
		Phase.OVERTIME:
			return "OT"
		_:
			return ""


func reset_match(_unused: int = 16) -> void:
	t_score = 0
	ct_score = 0
	round_idx = 0
	total_rounds = 0
	bomb_planted = false
	bomb_exploded = false
	overtime = false
	ot_halves = 0
	swapped = false
	loss_bonus_t = 0
	loss_bonus_ct = 0
	phase = Phase.WARMUP
	warmup_left = 5.0
	score_changed.emit()
	phase_changed.emit(phase)


func begin_round() -> void:
	if phase == Phase.MATCH_END:
		return
	bomb_planted = false
	bomb_exploded = false
	defusing = false
	defuser = null
	bomb_planter = null
	round_idx += 1
	total_rounds += 1
	phase = Phase.FREEZE
	freeze_left = freeze_time
	buy_left = buy_time
	round_left = round_time
	round_reset.emit()
	phase_changed.emit(phase)


func go_live() -> void:
	phase = Phase.LIVE
	phase_changed.emit(phase)


func plant(site: String, pos: Vector3, planter: Node) -> void:
	if bomb_planted:
		return
	bomb_planted = true
	bomb_site = site
	bomb_pos = pos
	bomb_planter = planter
	bomb_left = bomb_time
	phase = Phase.BOMB
	if planter and planter.has_method("add_money"):
		planter.add_money(PLANT_PLAYER)
	bomb_update.emit(true, bomb_left, site)
	phase_changed.emit(phase)


func explode() -> void:
	bomb_exploded = true
	end_round(Team.T, "bomb")


func defuse_done() -> void:
	end_round(Team.CT, "defuse")


func loss_bonus(team: int) -> int:
	var s := loss_bonus_t if team == Team.T else loss_bonus_ct
	return mini(LOSS_BASE + LOSS_STEP * s, LOSS_MAX)


func payout(winner: int, reason: String, players: Array) -> void:
	var win_amt := WIN_BOMB if reason == "bomb" or reason == "defuse" else WIN_ELIM
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		if p.team == winner:
			p.add_money(win_amt)
		else:
			var lb := loss_bonus(p.team)
			if p.team == Team.T and bomb_planted and winner == Team.CT:
				lb += PLANT_TEAM_BONUS
			p.add_money(lb)
	if winner == Team.T:
		loss_bonus_t = 0
		loss_bonus_ct = mini(loss_bonus_ct + 1, 4)
	else:
		loss_bonus_ct = 0
		loss_bonus_t = mini(loss_bonus_t + 1, 4)


func end_round(winner: int, reason: String) -> void:
	if phase == Phase.ROUND_END or phase == Phase.MATCH_END:
		return
	last_winner = winner
	last_reason = reason
	if winner == Team.T:
		t_score += 1
	else:
		ct_score += 1
	score_changed.emit()
	phase = Phase.ROUND_END
	round_left = 5.0
	phase_changed.emit(phase)
	# Halftime after 15 rounds played (scores sum 15).
	if not overtime and t_score + ct_score == 15:
		swapped = true
	# Regulation: first to 16. If 15-15, overtime.
	if not overtime:
		if t_score >= 16 or ct_score >= 16:
			phase = Phase.MATCH_END
			phase_changed.emit(phase)
		elif t_score == 15 and ct_score == 15:
			overtime = true
			ot_halves = 0
	else:
		# OT MR3: first to (15 + 4 + 3*ot extra...) — first side to lead by winning 4 in a half-pair.
		var ot_t := t_score - 15
		var ot_ct := ct_score - 15
		if ot_t >= 4 and ot_t - ot_ct >= 0 and (ot_t + ot_ct) % 6 == 0:
			if ot_t != ot_ct:
				phase = Phase.MATCH_END
				phase_changed.emit(phase)
		elif ot_ct >= 4 and ot_ct - ot_t >= 0 and (ot_t + ot_ct) % 6 == 0:
			if ot_t != ot_ct:
				phase = Phase.MATCH_END
				phase_changed.emit(phase)
		elif ot_t >= 4 and ot_ct >= 4 and ot_t == ot_ct and (ot_t + ot_ct) % 6 == 0:
			pass  # continue OT


func should_swap_now() -> bool:
	if overtime:
		var played := (t_score - 15) + (ct_score - 15)
		return played > 0 and played % 3 == 0 and phase == Phase.ROUND_END
	return not overtime and t_score + ct_score == 15 and phase == Phase.ROUND_END
