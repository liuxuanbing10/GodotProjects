extends Node

# ═══════════════════════════════════════════════════════════
# Tank Trouble — Shared Constants
# ═══════════════════════════════════════════════════════════

# Arena dimensions
const ARENA_W := 960.0
const ARENA_H := 640.0

# Grid / cell size
const CELL := 40
const GRID_COLS := 24
const GRID_ROWS := 16

# Gameplay
const WIN_SCORE := 5

# ── 道具类型枚举（所有脚本统一引用此枚举）───────────────────
# 注意：NONE(=0) 仅用于坦克；bullet.gd 的 BulletType 无 NONE而有 NORMAL
enum PowerUp { NONE, BIG_SHOT, LASER, FRAG_BOMB, GATLING, HOMING }

# 子弹类型枚举（供 bullet.gd 和道具转换表引用）
enum BulletType { NORMAL, BIG_SHOT, FRAG_BOMB, GATLING, HOMING }

# 道具 → 子弹类型转换表（用于 main.gd::_bullet_type()）
# PowerUp 索引 → BulletType 索引
const POWERUP_TO_BULLET_TYPE := {
	PowerUp.NONE:      BulletType.NORMAL,
	PowerUp.BIG_SHOT:  BulletType.BIG_SHOT,
	PowerUp.LASER:     -1,               # 激光由 main.gd 直接处理，无需子弹
	PowerUp.FRAG_BOMB: BulletType.FRAG_BOMB,
	PowerUp.GATLING:   BulletType.GATLING,
	PowerUp.HOMING:    BulletType.HOMING,
}

# ═══════════════════════════════════════════════════════════
# Visual Theme — Shared Color Palette
# ═══════════════════════════════════════════════════════════

# Arena
const COLOR_ARENA_BG      := Color(0.10, 0.11, 0.15)    # Dark blue-black floor
const COLOR_ARENA_GRID    := Color(0.14, 0.15, 0.20, 0.3) # Subtle grid lines
const COLOR_WALL          := Color(0.35, 0.30, 0.25)    # Warm stone walls
const COLOR_WALL_LIGHT    := Color(0.45, 0.38, 0.30)    # Wall highlight edge
const COLOR_WALL_DARK     := Color(0.25, 0.20, 0.16)    # Wall shadow edge

# Players
const COLOR_P1_BODY       := Color(0.20, 0.55, 0.95)    # Blue - Player 1
const COLOR_P1_ACCENT     := Color(0.40, 0.70, 1.00)    # Light blue accent
const COLOR_P2_BODY       := Color(0.90, 0.25, 0.20)    # Red - Player 2
const COLOR_P2_ACCENT     := Color(1.00, 0.45, 0.40)    # Light red accent

# Bullets
const COLOR_BULLET_NORMAL := Color(1.00, 0.90, 0.20)    # Yellow normal
const COLOR_BULLET_BIG    := Color(0.30, 0.60, 1.00)    # Blue big shot
const COLOR_BULLET_FRAG   := Color(1.00, 0.55, 0.10)    # Orange frag
const COLOR_BULLET_GATLIN := Color(0.95, 0.85, 0.30)    # Yellow gatling
const COLOR_BULLET_HOMING := Color(0.30, 0.90, 0.30)    # Green homing

# UI
const COLOR_UI_TITLE      := Color(1.00, 0.85, 0.20)    # Gold title
const COLOR_UI_SUBTITLE   := Color(0.70, 0.72, 0.78)    # Light gray subtitle
const COLOR_UI_BUTTON     := Color(0.22, 0.24, 0.30)    # Dark button bg
const COLOR_UI_BUTTON_HL  := Color(0.30, 0.35, 0.45)    # Button hover
const COLOR_UI_PANEL      := Color(0.12, 0.13, 0.18, 0.85) # Semi-transparent panel
const COLOR_UI_TEXT       := Color(0.90, 0.92, 0.95)    # Near-white text

# Effects
const COLOR_EXPLOSION_FIRE    := Color(1.00, 0.60, 0.10, 0.8) # Orange fire
const COLOR_EXPLOSION_CORE    := Color(1.00, 0.95, 0.60, 1.0) # Bright core flash
const COLOR_EXPLOSION_SMOKE   := Color(0.35, 0.35, 0.35, 0.5) # Gray smoke
const COLOR_POWERUP_SPEED     := Color(0.20, 0.90, 0.30)    # Green speed
const COLOR_POWERUP_SHIELD    := Color(0.30, 0.70, 1.00)    # Blue shield
const COLOR_POWERUP_DAMAGE    := Color(1.00, 0.30, 0.20)    # Red damage
