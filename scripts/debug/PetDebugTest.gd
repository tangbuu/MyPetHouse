extends Node
class_name PetDebugTest

## Thêm node này vào scene, gán Pet, bật debug_log trên Pet, rồi dùng Inspector để trigger test.
## Chạy thủ công: gọi run_automated_test() từ Remote tab khi game đang chạy.

@export var pet: Pet

@export_group("Run Tests")
## Bật → chạy toàn bộ 3 test rồi tắt lại
@export var run_all: bool = false:
	set(v):
		run_all = false
		if v and pet: _run_all()

## Bật → chạy Test 1 (IDLE vs velocity conflict)
@export var run_test_1_conflict: bool = false:
	set(v):
		run_test_1_conflict = false
		if v and pet: _test_idle_walk_conflict()

## Bật → chạy Test 2 (navigation give-up timeout, mất ~11s)
@export var run_test_2_timeout: bool = false:
	set(v):
		run_test_2_timeout = false
		if v and pet: _test_give_up_timeout()

## Bật → chạy Test 3 (velocity không interrupt EAT/SLEEP)
@export var run_test_3_no_interrupt: bool = false:
	set(v):
		run_test_3_no_interrupt = false
		if v and pet: _test_no_interrupt_during_action()

# ─────────────────────────────────────────────────────────────────────────────

func run_automated_test() -> void:
	if not pet:
		push_error("[PetDebugTest] No pet assigned!")
		return
	_run_all()

func _run_all() -> void:
	print("\n══════════ PET DEBUG TEST SUITE ══════════")
	await _test_idle_walk_conflict()
	await get_tree().create_timer(0.5).timeout
	await _test_no_interrupt_during_action()
	await get_tree().create_timer(0.5).timeout
	await _test_give_up_timeout()
	print("══════════ TEST SUITE COMPLETE ══════════\n")

# ── Test 1 ────────────────────────────────────────────────────────────────────
# _sync_state_to_velocity() phải sửa IDLE → WALK khi velocity > 0.
# Giả lập trường hợp bị đẩy bởi physics object trong khi đang đứng yên.

func _test_idle_walk_conflict() -> void:
	print("[TEST 1] IDLE+velocity conflict...")
	var saved_state := pet._anim_state
	pet._change_anim_state(Pet.AnimState.IDLE)
	pet.velocity = Vector2(100.0, 0.0)
	await get_tree().process_frame          # _physics_process chạy 1 frame
	if pet._anim_state == Pet.AnimState.WALK:
		print("[TEST 1] PASS — _sync_state_to_velocity corrected IDLE → WALK ✓")
	else:
		print("[TEST 1] FAIL — anim_state = %s (expected WALK)" % Pet.AnimState.keys()[pet._anim_state])
	pet.velocity = Vector2.ZERO
	pet._change_anim_state(saved_state)

# ── Test 2 ────────────────────────────────────────────────────────────────────
# Đặt bowl ra ngoài tầm tới để navigation không thành công.
# Sau NAV_TIMEOUT_BOWL (10s) + buffer, _nav_target phải được xóa.

func _test_give_up_timeout() -> void:
	print("[TEST 2] Navigation give-up timeout (waiting %.0fs)..." % (Pet.NAV_TIMEOUT_BOWL + 1.0))
	if not pet.food_bowl:
		print("[TEST 2] SKIP — no food_bowl assigned to pet")
		return
	var saved_pos   := pet.food_bowl.global_position
	var saved_hunger := pet.hunger
	pet.food_bowl.global_position = Vector2(999999.0, 999999.0)
	pet.hunger = 0.1
	pet._do_natural_behavior()
	await get_tree().create_timer(Pet.NAV_TIMEOUT_BOWL + 1.0).timeout
	if pet._nav_target == "":
		print("[TEST 2] PASS — _nav_target cleared after timeout ✓")
	else:
		print("[TEST 2] FAIL — _nav_target still = '%s' after %.0fs" % [pet._nav_target, Pet.NAV_TIMEOUT_BOWL + 1.0])
	pet.food_bowl.global_position = saved_pos
	pet.hunger = saved_hunger

# ── Test 3 ────────────────────────────────────────────────────────────────────
# EAT_LOOP và SLEEPING không nằm trong nhóm IDLE/IDLE_RANDOM,
# nên _sync_state_to_velocity() không được phép interrupt chúng.

func _test_no_interrupt_during_action() -> void:
	print("[TEST 3] No-interrupt during EAT...")
	pet._change_anim_state(Pet.AnimState.EAT_LOOP)
	await get_tree().process_frame
	pet.velocity = Vector2(100.0, 0.0)
	await get_tree().process_frame
	var ok_eat := pet._anim_state == Pet.AnimState.EAT_LOOP
	pet.velocity = Vector2.ZERO

	print("[TEST 3a] EAT_LOOP: %s" % ("PASS — not interrupted ✓" if ok_eat else "FAIL — interrupted to %s" % Pet.AnimState.keys()[pet._anim_state]))

	pet._change_anim_state(Pet.AnimState.SLEEPING)
	await get_tree().process_frame
	pet.velocity = Vector2(100.0, 0.0)
	await get_tree().process_frame
	var ok_sleep := pet._anim_state == Pet.AnimState.SLEEPING
	pet.velocity = Vector2.ZERO

	print("[TEST 3b] SLEEPING: %s" % ("PASS — not interrupted ✓" if ok_sleep else "FAIL — interrupted to %s" % Pet.AnimState.keys()[pet._anim_state]))

	pet._change_anim_state(Pet.AnimState.IDLE)
