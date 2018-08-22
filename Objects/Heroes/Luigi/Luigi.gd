extends "../Hero.gd"

const MAX_JUMPS = 1
const JUMP_STRENGTH = 5.5

const GRAVITY_SPD = Vector3(0, -22.0, 0)
const GRAVITY_ACC = Vector3(0, -16.0, 0)

const FLOOR_SPD = Vector3(3.4, 0, 2.8)
const FLOOR_ACC = Vector3(4.0, 0.0, 4.0)
const FLOOR_DEC = Vector3(6.0, 0.0, 4.5)

const AIRBORNE_SPD = Vector3(3.2, 0.0, 2.4)
const AIRBORNE_ACC = Vector3(3.5, 0.0, 3.0)
const AIRBORNE_DEC = Vector3(6.0, 0.0, 4.5)

var jump_sound = preload("./Sounds/Jump.ogg")
var turn_sound = preload("./Sounds/Turn.ogg")
var step_sound = preload("./Sounds/NormalStep.ogg")
var coin_sound = preload("../../Pickups/Coin/Sounds/Coin.ogg")

# Hero update loop
# ---

func _ready():
	set_state(HeroState.fall)
	change_orientation(HeroOrientation.horizontal)
	change_direction(HeroDirection.right)

func _physics_process(delta):
	process_velocity(delta)
	match state:
		HeroState.stand: stand(delta)
		HeroState.walk: walk(delta)
		HeroState.walk_2: walk_2(delta)
		HeroState.walk_wall: walk_wall(delta)
		HeroState.walk_skid: walk_skid(delta)
		HeroState.walk_turn: walk_turn(delta)
		HeroState.jump: jump(delta)
		HeroState.fall: fall(delta)
		HeroState.fall_to_stand: fall_to_stand(delta)

# Hero finite state machine
# ---

func set_state(new_state):
	reset_state()
	state = new_state
	match state:
		HeroState.stand: pre_stand()
		HeroState.walk: pre_walk()
		HeroState.walk_2: pre_walk_2()
		HeroState.walk_wall: pre_walk_wall()
		HeroState.walk_skid: pre_walk_skid()
		HeroState.walk_turn: pre_walk_turn()
		HeroState.jump: pre_jump()
		HeroState.fall: pre_fall()
		HeroState.fall_to_stand: pre_fall_to_stand()

func reset_state():
	walk_particles.emitting = false
	every_seconds(100.0, "res")
	change_animation_speed(1.0)

## Horizontal movement states
## ---

func pre_stand():
	change_animation("Stand")

func stand(delta):
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_flashlight()
	if not on_floor:
		return set_state(HeroState.fall)
	elif input_jump and jumps > 0:
		return set_state(HeroState.jump)
	elif has_forward_input() and has_forward_input_invert_direction():
		return set_state(HeroState.walk_turn)
	elif has_forward_input() or has_upward_input():
		return set_state(HeroState.walk)
	elif has_forward_velocity() or has_upward_velocity():
		return set_state(HeroState.walk_skid)

func pre_walk():
	walk_particles.emitting = true
	start_timer(0.25)
	change_animation("Walk")
	if has_forward_velocity_same_direction() and get_forward_velocity() > FLOOR_SPD.x - 1.0:
		return self.set_state(HeroState.walk_2)
	change_animation_speed(1.6)

func walk(delta):
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_flashlight()
	handle_directional_move(delta, FLOOR_SPD, FLOOR_ACC, FLOOR_DEC)
	if every_seconds(0.08, "walk"):
		play_sound_effect(step_sound)
	if not on_floor:
		return set_state(HeroState.fall)
	elif input_jump and jumps > 0:
		return set_state(HeroState.jump)
	elif is_timer_finished():
		return self.set_state(HeroState.walk_2)

func pre_walk_2():
	walk_particles.emitting = true

func walk_2(delta):
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_flashlight()
	handle_directional_move(delta, FLOOR_SPD, FLOOR_ACC, FLOOR_DEC)
	if every_seconds(0.24, "walk"):
		play_sound_effect(step_sound)
	if not on_floor:
		return set_state(HeroState.fall)
	elif has_forward_input_invert_direction() or not has_forward_input() and not has_upward_input():
		return self.set_state(HeroState.walk_skid)
	elif on_wall and not has_forward_vector(velocity_offset) and not has_upward_vector(velocity_offset):
		return set_state(HeroState.walk_wall)
	elif input_jump and jumps > 0:
		return set_state(HeroState.jump)

func pre_walk_wall():
	change_animation("Stand")

func walk_wall(delta):
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_directional_move(delta, FLOOR_SPD, FLOOR_ACC, FLOOR_DEC)
	if not on_floor:
		return set_state(HeroState.fall)
	elif input_jump and jumps > 0:
		return set_state(HeroState.jump)
	elif not on_wall or has_forward_vector(velocity_offset) or has_upward_vector(velocity_offset):
		return set_state(HeroState.stand)

func pre_walk_skid():
	start_timer(0.2)
	change_animation("Skid")

func walk_skid(delta):
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_flashlight()
	handle_deceleration_move(delta, FLOOR_DEC if not has_forward_input_invert_direction() else FLOOR_ACC + FLOOR_DEC)
	if not on_floor:
		return set_state(HeroState.fall)
	elif input_jump and jumps > 0:
		return set_state(HeroState.jump)
	elif has_forward_input_invert_direction() and is_timer_finished():
		return set_state(HeroState.walk_turn)
	elif has_forward_input() and has_forward_input_same_direction() or has_upward_input() and not has_forward_input_invert_direction():
		return set_state(HeroState.walk)
	elif not has_forward_velocity() and not has_upward_velocity():
		return set_state(HeroState.stand)

func pre_walk_turn():
	start_timer(0.1)
	change_animation("Turn")
	play_sound_effect(turn_sound)

func walk_turn(delta):
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_flashlight()
	handle_deceleration_move(delta, FLOOR_ACC + FLOOR_DEC)
	if is_timer_finished():
		change_direction(-direction)
		return self.set_state(HeroState.stand)

## Vertical movement states
## ---

func pre_jump():
	jumps -= 1
	handle_jump(JUMP_STRENGTH)
	change_animation("Jump")
	play_sound_effect(jump_sound)

func jump(delta):
	if velocity.y < 0:
		set_state(HeroState.fall)
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_flashlight()
	handle_airborne_move(delta, AIRBORNE_SPD, AIRBORNE_ACC, AIRBORNE_DEC)

func pre_fall():
	change_animation("Fall")

func fall(delta):
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_flashlight()
	handle_airborne_move(delta, AIRBORNE_SPD, AIRBORNE_ACC, AIRBORNE_DEC)
	if on_floor:
		return set_state(HeroState.fall_to_stand)

func pre_fall_to_stand():
	jumps = MAX_JUMPS
	start_timer(0.08)
	change_animation("Skid")
	play_sound_effect(step_sound)

func fall_to_stand(delta):
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_flashlight()
	handle_deceleration_move(delta, FLOOR_DEC)
	if is_timer_finished():
		return self.set_state(HeroState.stand if velocity == Vector3() else HeroState.walk_skid)

func _on_AreaPickup_body_entered(body):
	if body.is_in_group("Coin"):
		add_gold(10)
		body.queue_free()
		play_sound_effect(coin_sound)