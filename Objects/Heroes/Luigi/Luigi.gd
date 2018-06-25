extends "../Hero.gd"

const MAX_JUMPS = 1

const WALK_ACC = 9.0
const WALK_DEC = 14.0
const WALK_MAX_SPEED = 3.8

const AIR_ACC = 8.0
const AIR_DEC = 13.0
const AIR_MAX_SPEED = 3.5

const GRAVITY = -13.8
const GRAVITY_MAX_SPEED = -20.0

const JUMP_STRENGTH = 5.5

# Hero update loop
# ---

func _ready():
	set_state(HeroState.fall)

func _physics_process(delta):
	integrate_input(delta)
	integrate_velocity(delta)
	velocity = get_vertical_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)
	match state:
		HeroState.stand: stand(delta)
		HeroState.walk: walk(delta)
		HeroState.walk_turn: walk_turn(delta)
		HeroState.walk_wall: walk_wall(delta)
		HeroState.fall: fall(delta)
		HeroState.fall_recovery: fall_recovery(delta)
		HeroState.jump: jump(delta)

# Hero finite state machine
# ---

func set_state(new_state):
	state = new_state
	match state:
		HeroState.stand: pre_stand()
		HeroState.walk: pre_walk()
		HeroState.walk_turn: pre_walk_turn()
		HeroState.walk_wall: pre_walk_wall()
		HeroState.fall: pre_fall()
		HeroState.fall_recovery: pre_fall_recovery()
		HeroState.jump: pre_jump()

## Horizontal movement states
## ---

func pre_stand():
	jumps = MAX_JUMPS
	animation_player.play("Stand")

func stand(delta):
	if not on_floor:
		return set_state(HeroState.fall)
	elif input.jump and jumps > 0:
		return set_state(HeroState.jump)
	elif input_direction != HeroDirection.none:
		return set_state(HeroState.walk if direction == input_direction else HeroState.walk_turn)
	velocity = get_horizontal_deceleration(delta, velocity, WALK_DEC)

func pre_walk():
	animation_player.play("Walk")

func walk(delta):
	if not on_floor:
		return set_state(HeroState.fall)
	elif input.jump and jumps > 0:
		return set_state(HeroState.jump)
	elif on_wall:
		return set_state(HeroState.walk_wall)
	else:
		velocity = get_horizontal_input_movement(delta, velocity, direction, WALK_ACC, WALK_DEC, WALK_MAX_SPEED)
		if input_direction != direction and get_velocity_direction() == HeroDirection.none:
			return set_state(HeroState.stand)

func pre_walk_turn():
	change_direction(-direction)

func walk_turn(delta):
	return set_state(HeroState.stand)

func pre_walk_wall():
	animation_player.play("Skid")

func walk_wall(delta):
	if not on_wall:
		return set_state(HeroState.stand)
	elif input.jump and jumps > 0:
		return set_state(HeroState.jump)
	velocity = get_horizontal_input_movement(delta, velocity, direction, WALK_ACC, WALK_DEC, WALK_MAX_SPEED)

## Vertical movement states
## ---

func pre_jump():
	jumps -= 1
	velocity.y = JUMP_STRENGTH
	animation_player.play("Jump")
	integrate_jump()

func jump(delta):
	if self.velocity.y < 0:
		set_state(HeroState.fall)
	velocity = get_horizontal_input_movement(delta, velocity, input_direction, AIR_ACC, AIR_DEC, AIR_MAX_SPEED)

func pre_fall():
	animation_player.play("Fall")

func fall(delta):
	if on_floor:
		return set_state(HeroState.fall_recovery)
	velocity = get_horizontal_input_movement(delta, velocity, input_direction, AIR_ACC, AIR_DEC, AIR_MAX_SPEED)

func pre_fall_recovery():
	start_timer(0.1)
	animation_player.play("Skid")

func fall_recovery(delta):
	if timer.is_stopped():
		return set_state(HeroState.stand)
	elif input.jump:
		return set_state(HeroState.jump)
	velocity = get_horizontal_deceleration(delta, velocity, WALK_DEC)