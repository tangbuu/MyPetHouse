extends RefCounted
class_name PetStateMachine

# GameManager macro-state (kept for GameManager.state_changed compat)
enum State { IDLE, HAPPY, HUNGRY, TIRED, SLEEPING }

# ── Static helpers — nhận AnimState int từ Pet.gd ────────────────────────────
# Tương ứng với Pet.AnimState: IDLE=0 IDLE_RANDOM=1 WALK=2
#   EAT_START=3 EAT_LOOP=4 EAT_END=5
#   DRINK_START=6 DRINK_LOOP=7 DRINK_END=8
#   SLEEP_PREPARE=9 SLEEPING=10 SLEEP_DONE=11 SOFULL=12

static func is_eating(s: int) -> bool:
	return s in [3, 4, 5]   # EAT_START, EAT_LOOP, EAT_END

static func is_drinking(s: int) -> bool:
	return s in [6, 7, 8]   # DRINK_START, DRINK_LOOP, DRINK_END

static func is_sleeping(s: int) -> bool:
	return s in [9, 10, 11, 12]  # SLEEP_PREPARE, SLEEPING, SLEEP_DONE, SOFULL

static func is_busy(s: int) -> bool:
	return s >= 3   # mọi state từ EAT_START trở đi

static func is_interruptible(s: int) -> bool:
	return s <= 2   # IDLE, IDLE_RANDOM, WALK

static func evaluate(stats: PetStats, is_sleeping_flag: bool) -> State:
	if is_sleeping_flag:      return State.SLEEPING
	if stats.hunger < 20.0:  return State.HUNGRY   # ăn trước
	if stats.energy < 20.0:  return State.TIRED    # rồi mới ngủ
	return State.IDLE
