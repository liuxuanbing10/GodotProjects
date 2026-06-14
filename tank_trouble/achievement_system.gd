# ═══════════════════════════════════════════════════════════
# Tank Trouble — Achievement Tracking System
# 成就追踪系统
# ═══════════════════════════════════════════════════════════
extends Node

# ── Achievements ──────────────────────────────────────────
enum Achievement {
	FIRST_BLOOD,      # 首次击杀
	UNSTOPPABLE,      # 连续击杀3名敌人
	SHARPSHOOTER,     # 连续5发命中
	BOOM_MASTER,      # 使用碎片弹击杀5次
	LASER_LORD,       # 使用激光击杀5次
	HOMING_HUNTER,    # 使用追踪弹击杀5次
	MAZE_MASTER,      # 在10张不同地图上获胜
	PERFECT_ROUND,    # 零被击中获胜
	QUICK_DRAW,       # 开局3秒内击杀敌人
	WIN_STREAK_3,     # 3连胜
	WIN_STREAK_5,     # 5连胜
	TOTAL_KILLS_10,   # 总击杀10次
	TOTAL_KILLS_50,   # 总击杀50次
	TOTAL_WINS_10,    # 总获胜10次
	EXPLOSIVE_KILLS_20,  # 爆炸击杀20次（碎片弹+格林机枪）
}

# 成就解锁条件
const ACHIEVEMENT_DATA := {
	Achievement.FIRST_BLOOD:        { name="First Blood",         desc="获得首次击杀",          unlocked=false },
	Achievement.UNSTOPPABLE:        { name="Unstoppable",          desc="连续击杀3名敌人",       unlocked=false },
	Achievement.SHARPSHOOTER:       { name="Sharpshooter",         desc="连续5发命中",           unlocked=false },
	Achievement.BOOM_MASTER:        { name="Boom Master",          desc="使用碎片弹击杀5次",      unlocked=false },
	Achievement.LASER_LORD:         { name="Laser Lord",           desc="使用激光击杀5次",       unlocked=false },
	Achievement.HOMING_HUNTER:      { name="Homing Hunter",         desc="使用追踪弹击杀5次",      unlocked=false },
	Achievement.MAZE_MASTER:        { name="Maze Master",          desc="在10张不同地图上获胜",   unlocked=false },
	Achievement.PERFECT_ROUND:      { name="Perfect Round",        desc="零被击中获胜",           unlocked=false },
	Achievement.QUICK_DRAW:         { name="Quick Draw",           desc="开局3秒内击杀敌人",      unlocked=false },
	Achievement.WIN_STREAK_3:       { name="Hot Streak",           desc="3连胜",                 unlocked=false },
	Achievement.WIN_STREAK_5:       { name="Dominating",           desc="5连胜",                 unlocked=false },
	Achievement.TOTAL_KILLS_10:     { name="Veteran",              desc="总击杀10次",             unlocked=false },
	Achievement.TOTAL_KILLS_50:     { name="War Machine",          desc="总击杀50次",             unlocked=false },
	Achievement.TOTAL_WINS_10:      { name="Champion",             desc="总获胜10次",             unlocked=false },
	Achievement.EXPLOSIVE_KILLS_20: { name="Explosive Expert",     desc="爆炸击杀20次",           unlocked=false },
}

# ── Runtime Stats ────────────────────────────────────────
var total_kills := 0
var total_wins := 0
var win_streak := 0
var consecutive_hits := 0
var consecutive_kills := 0
var frag_bomb_kills := 0
var laser_kills := 0
var homing_kills := 0
var explosive_kills := 0
var maps_won := Set()  # 记录胜利过的地图

var _just_unlocked: Array[Achievement] = []  # 本回合新解锁的成就

# ── Signals ────────────────────────────────────────────────
signal achievement_unlocked(achievement: int, data: Dictionary)

# ── Initialization ────────────────────────────────────────
func _ready() -> void:
	load_progress()

# ── Stats Updates ─────────────────────────────────────────
func record_kill(bullet_type: int, map_id: int) -> void:
	total_kills += 1
	consecutive_kills += 1
	consecutive_hits += 1

	# 类型统计
	match bullet_type:
		Constants.BulletType.FRAG_BOMB:
			frag_bomb_kills += 1
			explosive_kills += 1
		Constants.BulletType.GATLING:
			explosive_kills += 1
		Constants.BulletType.HOMING:
			homing_kills += 1
		Constants.BulletType.BIG_SHOT:
			pass  # 大子弹击杀不算特殊

	_check_all()
	save_progress()

func record_win(map_id: int) -> void:
	total_wins += 1
	win_streak += 1
	maps_won.add(map_id)

	_check_all()
	save_progress()

func record_death() -> void:
	win_streak = 0
	consecutive_kills = 0

func record_hit() -> void:
	consecutive_hits += 1
	_check_all()

func record_miss() -> void:
	consecutive_hits = 0

func record_round_start() -> void:
	# 每回合开始重置连续击杀（用于 QUICK_DRAW 检测）
	consecutive_kills = 0

# ── Achievement Checking ───────────────────────────────────
func _check_all() -> void:
	_just_unlocked.clear()

	if total_kills >= 1:
		_try_unlock(Achievement.FIRST_BLOOD)
	if consecutive_kills >= 3:
		_try_unlock(Achievement.UNSTOPPABLE)
	if consecutive_hits >= 5:
		_try_unlock(Achievement.SHARPSHOOTER)
	if frag_bomb_kills >= 5:
		_try_unlock(Achievement.BOOM_MASTER)
	if laser_kills >= 5:
		_try_unlock(Achievement.LASER_LORD)
	if homing_kills >= 5:
		_try_unlock(Achievement.HOMING_HUNTER)
	if maps_won.size() >= 10:
		_try_unlock(Achievement.MAZE_MASTER)
	if win_streak >= 3:
		_try_unlock(Achievement.WIN_STREAK_3)
	if win_streak >= 5:
		_try_unlock(Achievement.WIN_STREAK_5)
	if total_kills >= 10:
		_try_unlock(Achievement.TOTAL_KILLS_10)
	if total_kills >= 50:
		_try_unlock(Achievement.TOTAL_KILLS_50)
	if total_wins >= 10:
		_try_unlock(Achievement.TOTAL_WINS_10)
	if explosive_kills >= 20:
		_try_unlock(Achievement.EXPLOSIVE_KILLS_20)

func _try_unlock(a: Achievement) -> void:
	if not ACHIEVEMENT_DATA[a].unlocked:
		ACHIEVEMENT_DATA[a].unlocked = true
		_just_unlocked.append(a)
		achievement_unlocked.emit(a, ACHIEVEMENT_DATA[a])

# ── Progress Save/Load ─────────────────────────────────────
func save_progress() -> void:
	var save := {
		total_kills = total_kills,
		total_wins = total_wins,
		win_streak = win_streak,
		frag_bomb_kills = frag_bomb_kills,
		laser_kills = laser_kills,
		homing_kills = homing_kills,
		explosive_kills = explosive_kills,
		maps_won = Array(maps_won),
	}
	# 保存到 user://achievements.json
	var f := FileAccess.open("user://achievements.save", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))
		f.close()

func load_progress() -> void:
	if not FileAccess.file_exists("user://achievements.save"):
		return
	var f := FileAccess.open("user://achievements.save", FileAccess.READ)
	if not f:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK:
		var data: Dictionary = json.get_data()
		if data is Dictionary:
			total_kills = data.get("total_kills", 0)
			total_wins = data.get("total_wins", 0)
			win_streak = data.get("win_streak", 0)
			frag_bomb_kills = data.get("frag_bomb_kills", 0)
			laser_kills = data.get("laser_kills", 0)
			homing_kills = data.get("homing_kills", 0)
			explosive_kills = data.get("explosive_kills", 0)
			var saved_maps: Array = data.get("maps_won", [])
			maps_won = Set(saved_maps)
			# 重新检查所有成就（用于解锁已满足但未保存的）
			for key in ACHIEVEMENT_DATA:
				if not ACHIEVEMENT_DATA[key].unlocked:
					_try_unlock(key as Achievement)
	f.close()

# ── Getters ────────────────────────────────────────────────
func get_just_unlocked() -> Array[Achievement]:
	return _just_unlocked

func get_all_achievements() -> Dictionary:
	return ACHIEVEMENT_DATA.duplicate(true)

func get_stats() -> Dictionary:
	return {
		total_kills = total_kills,
		total_wins = total_wins,
		win_streak = win_streak,
		frag_bomb_kills = frag_bomb_kills,
		laser_kills = laser_kills,
		homing_kills = homing_kills,
		explosive_kills = explosive_kills,
		maps_won_count = maps_won.size(),
	}


# ═══════════════════════════════════════════════════════════
# Helper: Set implementation for GDScript
# ═══════════════════════════════════════════════════════════
class Set:
	var _items: Array = []
	func add(item) -> void:
		if not has(item):
			_items.append(item)
	func has(item) -> bool:
		return item in _items
	func size() -> int:
		return _items.size()
