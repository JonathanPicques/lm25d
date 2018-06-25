extends "../Hero.gd"

const MAX_JUMPS = 1
const JUMP_STRENGTH = 5.5

const GRAVITY = Vector3(0, -16.0, 0)
const GRAVITY_MAX_SPEED = Vector3(0, -22.0, 0)

const FLOOR_ACC = Vector3(9.0, 0.0, 7.0)
const FLOOR_DEC = Vector3(14.0, 0.0, 12.0)
const FLOOR_MAX_SPEED = Vector3(3.8, 0, 2.8)

const AIRBORNE_ACC = Vector3(8.0, 0.0, 4.0)
const AIRBORNE_DEC = Vector3(13.0, 0.0, 6.5)
const AIRBORNE_MAX_SPEED = Vector3(3.5, 0.0, 2.5)

# Hero update loop
# ---

func _ready():
	set_state(HeroState.fall)

func _physics_process(delta):
	_process_velocity(delta)
	match state:
		HeroState.stand: stand(delta)
		HeroState.walk: walk(delta)
		HeroState.walk_turn: walk_turn(delta)
		HeroState.jump: jump(delta)
		HeroState.fall: fall(delta)
		HeroState.fall_to_stand: fall_to_stand(delta)

# Hero finite state machine
# ---

func set_state(new_state):
	state = new_state
	match state:
		HeroState.stand: pre_stand()
		HeroState.walk: pre_walk()
		HeroState.walk_turn: pre_walk_turn()
		HeroState.jump: pre_jump()
		HeroState.fall: pre_fall()
		HeroState.fall_to_stand: pre_fall_to_stand()

## Horizontal movement states
## ---

func pre_stand():
	jumps = MAX_JUMPS
	_change_animation("Stand")

func stand(delta):
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)
	if not on_floor:
		return set_state(HeroState.fall)
	elif input_jump and jumps > 0:
		return set_state(HeroState.jump)
	elif is_moving_x(input_velocity) and not is_moving_direction(direction, input_velocity):
		return set_state(HeroState.walk_turn)
	elif is_moving_x(input_velocity) or is_moving_z(input_velocity):
		return set_state(HeroState.walk)
	else:
		velocity = get_movement(delta, velocity, Vector3(), FLOOR_ACC, FLOOR_DEC, FLOOR_MAX_SPEED)

func pre_walk():
	_change_animation("Walk")

func walk(delta):
	velocity = get_movement(delta, velocity, input_velocity, FLOOR_ACC, FLOOR_DEC, FLOOR_MAX_SPEED)
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)
	if not on_floor:
		return set_state(HeroState.fall)
	elif input_jump and jumps > 0:
		return set_state(HeroState.jump)
	elif not is_moving_x(velocity) and not is_moving_z(velocity) and not is_moving_z(input_velocity):
		return set_state(HeroState.stand)
	elif is_moving_x(velocity) and not is_moving_direction(direction, velocity) and not is_moving_direction(direction, input_velocity):
		return set_state(HeroState.stand)

func pre_walk_turn():
	_start_timer(0.1)
	_change_animation("Skid")

func walk_turn(delta):
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)
	if timer.is_stopped():
		_change_direction(-direction)
		return self.set_state(HeroState.walk)

## Vertical movement states
## ---

func pre_jump():
	jumps -= 1
	velocity = Vector3(velocity.x, JUMP_STRENGTH, velocity.z)
	_change_animation("Jump")

func jump(delta):
	if velocity.y < 0:
		set_state(HeroState.fall)
	velocity = get_movement(delta, velocity, input_velocity, AIRBORNE_ACC, AIRBORNE_DEC, AIRBORNE_MAX_SPEED)
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)

func pre_fall():
	_change_animation("Fall")

func fall(delta):
	velocity = get_movement(delta, velocity, input_velocity, AIRBORNE_ACC, AIRBORNE_DEC, AIRBORNE_MAX_SPEED)
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)
	if on_floor:
		return set_state(HeroState.fall_to_stand)

func pre_fall_to_stand():
	_start_timer(0.08)
	_change_animation("Skid")

func fall_to_stand(delta):
	velocity = get_movement(delta, velocity, Vector3(), FLOOR_ACC, FLOOR_DEC, FLOOR_MAX_SPEED)
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)
	if timer.is_stopped():
		return self.set_state(HeroState.stand)