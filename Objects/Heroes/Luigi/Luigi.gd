extends "../Hero.gd"

# Luigi movement constants

const GRAVITY_ACC = -16.0
const GRAVITY_SPD = -22.0

const FLOOR_SPD = Vector3(3.4, 0.0, 2.7)
const FLOOR_ACC = Vector3(1.5, 0.0, 1.1)
const FLOOR_DEC = Vector3(2.0, 0.0, 1.4)

const MAX_JUMPS = 1
const JUMP_STRENGTH = 5.5
const MULTI_JUMP_FALLOFF = 0

var jump_sound = preload("./Sounds/Jump.ogg")
var turn_sound = preload("./Sounds/Turn.ogg")
var step_sound = preload("./Sounds/NormalStep.ogg")

# Luigi update loop
# ---

func _ready():
	set_state(HeroState.fall)

func _physics_process(delta):
	process_velocity(delta)
	match state:
		HeroState.stand: stand(delta)
		HeroState.walk: walk(delta)
		HeroState.walk_wall: walk_wall(delta)
		HeroState.walk_skid: walk_skid(delta)
		HeroState.walk_turn: walk_turn(delta)
		HeroState.jump: jump(delta)
		HeroState.fall: fall(delta)
		HeroState.fall_to_stand: fall_to_stand(delta)

# Luigi finite state machine
# ---

func set_state(new_state):
	state = new_state
	match state:
		HeroState.stand: pre_stand()
		HeroState.walk: pre_walk()
		HeroState.walk_wall: pre_walk_wall()
		HeroState.walk_skid: pre_walk_skid()
		HeroState.walk_turn: pre_walk_turn()
		HeroState.jump: pre_jump()
		HeroState.fall: pre_fall()
		HeroState.fall_to_stand: pre_fall_to_stand()

## Horizontal movement states
## ---

func pre_stand():
	change_animation("Stand")

func stand(delta):
	if not on_floor:
		return set_state(HeroState.fall)
	elif input_jump and jumps > 0:
		return set_state(HeroState.jump)
	elif is_moving_forward(input_velocity) and is_moving_invert_direction(input_velocity.x, direction):
		return set_state(HeroState.walk_turn)
	elif is_moving_forward(input_velocity) or is_moving_upward(input_velocity):
		return set_state(HeroState.walk)
	elif is_moving_upward(velocity) or is_moving_forward(velocity):
		return set_state(HeroState.walk_skid)
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)

func pre_walk():
	change_animation("Walk")

func walk(delta):
	if not on_floor:
		return set_state(HeroState.fall)
	elif on_wall and not is_moving_forward(velocity_offset) and not is_moving_upward(velocity_offset):
		return set_state(HeroState.walk_wall)
	elif input_jump and jumps > 0:
		return set_state(HeroState.jump)
	elif not is_moving_forward(input_velocity) and not is_moving_upward(input_velocity):
		return set_state(HeroState.walk_skid)
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_directional_move(delta, FLOOR_SPD, FLOOR_ACC, FLOOR_DEC)

func pre_walk_wall():
	change_animation("Stand")

func walk_wall(delta):
	if not on_floor:
		return set_state(HeroState.fall)
	elif not on_wall or is_moving_forward(velocity_offset) or is_moving_upward(velocity_offset):
		return set_state(HeroState.stand)
	elif input_jump and jumps > 0:
		return set_state(HeroState.jump)
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_directional_move(delta, FLOOR_SPD, FLOOR_ACC, FLOOR_DEC)

func pre_walk_skid():
	change_animation("Skid")

func walk_skid(delta):
	if not on_floor:
		return set_state(HeroState.fall)
	elif input_jump and jumps > 0:
		return set_state(HeroState.jump)
	elif is_moving_direction(input_velocity.x, direction) and (is_moving_forward(input_velocity) or is_moving_upward(input_velocity)):
		return set_state(HeroState.walk)
	elif not is_moving_forward(velocity) and not is_moving_upward(velocity):
		return set_state(HeroState.stand)
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_deceleration_move(delta, FLOOR_SPD, FLOOR_ACC + FLOOR_DEC if is_moving_invert_direction(input_velocity.x, direction) else FLOOR_DEC)

func pre_walk_turn():
	start_timer(0.1)
	change_animation("Turn")
	play_sound_effect(turn_sound)

func walk_turn(delta):
	if not on_floor:
		return set_state(HeroState.fall)
	elif is_timer_finished():
		change_direction(-direction)
		return self.set_state(HeroState.stand)
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_deceleration_move(delta, FLOOR_SPD, FLOOR_DEC)

## Vertical movement states
## ---

func pre_jump():
	jumps -= 1
	handle_jump(JUMP_STRENGTH)
	change_animation("Jump")
	play_sound_effect(jump_sound)

func jump(delta):
	if velocity.y < 0:
		return set_state(HeroState.fall)
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_airborne_move(delta, FLOOR_SPD, FLOOR_ACC, FLOOR_DEC)

func pre_fall():
	change_animation("Fall")

func fall(delta):
	if on_floor:
		return set_state(HeroState.fall_to_stand)
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_airborne_move(delta, FLOOR_SPD, FLOOR_ACC, FLOOR_DEC)

func pre_fall_to_stand():
	jumps = MAX_JUMPS
	start_timer(0.08)
	change_animation("Skid")
	play_sound_effect(step_sound)

func fall_to_stand(delta):
	if not on_floor:
		return set_state(HeroState.fall)
	elif is_timer_finished():
		return set_state(HeroState.stand)
	handle_gravity(delta, GRAVITY_SPD, GRAVITY_ACC)
	handle_deceleration_move(delta, FLOOR_SPD, FLOOR_DEC)

## Pickup
## ---

func _on_AreaPickup_body_entered(body):
	pass