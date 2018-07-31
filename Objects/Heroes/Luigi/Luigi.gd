extends "../Hero.gd"

const MAX_JUMPS = 1
const JUMP_STRENGTH = 5.5

const GRAVITY = Vector3(0, -16.0, 0)
const GRAVITY_MAX_SPEED = Vector3(0, -22.0, 0)

const FLOOR_ACC = Vector3(4.0, 0.0, 4.0)
const FLOOR_DEC = Vector3(6.0, 0.0, 4.5)
const FLOOR_MAX_SPEED = Vector3(3.4, 0, 2.8)

const AIRBORNE_ACC = Vector3(3.5, 0.0, 3.0)
const AIRBORNE_DEC = Vector3(6.0, 0.0, 4.5)
const AIRBORNE_MAX_SPEED = Vector3(3.2, 0.0, 2.4)

var jump_sound = preload("./Sounds/Jump.ogg")
var turn_sound = preload("./Sounds/Turn.ogg")
var step_sound = preload("./Sounds/NormalStep.ogg")
var coin_sound = preload("../../Pickups/Coin/Sounds/Coin.ogg")

# Hero update loop
# ---

func _ready():
	set_state(HeroState.fall)

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

## Horizontal movement states
## ---

func pre_stand():
	jumps = MAX_JUMPS
	change_animation("Stand")

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
	elif is_moving_x(velocity) or is_moving_z(velocity):
		return set_state(HeroState.walk_skid)

var walk_lock_velocity = 0
var walk_lock_direction = 0

func pre_walk():
	walk_particles.emitting = true
	walk_lock_velocity = input_velocity
	walk_lock_direction = direction
	start_timer(0.25)
	every_seconds(1.0, "r")
	change_animation("Walk")
	if is_moving_direction(direction, velocity) and abs(velocity.x) > FLOOR_MAX_SPEED.x - 1.0:
		return self.set_state(HeroState.walk_2)
	change_animation_speed(1.6)

func walk(delta):
	velocity = get_movement(delta, velocity, walk_lock_velocity, FLOOR_ACC, FLOOR_DEC, FLOOR_MAX_SPEED)
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)
	if every_seconds(0.08, "walk"):
		play_sound_effect(step_sound)
	if not on_floor:
		change_animation_speed(1.0)
		walk_particles.emitting = false
		return set_state(HeroState.fall)
	elif input_jump and jumps > 0:
		walk_particles.emitting = false
		return set_state(HeroState.jump)
	elif is_timer_finished():
		change_animation_speed(1.0)
		return self.set_state(HeroState.walk_2)

func pre_walk_2():
	every_seconds(1.0, "r")

func walk_2(delta):
	velocity = get_movement(delta, velocity, input_velocity, FLOOR_ACC, FLOOR_DEC, FLOOR_MAX_SPEED)
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)
	if every_seconds(0.24, "walk"):
		play_sound_effect(step_sound)
	if not on_floor:
		walk_particles.emitting = false
		return set_state(HeroState.fall)
	elif on_wall and not is_moving_x(velocity_offset) and not is_moving_z(velocity_offset):
		walk_particles.emitting = false
		return set_state(HeroState.walk_wall)
	elif input_jump and jumps > 0:
		walk_particles.emitting = false
		return set_state(HeroState.jump)
	elif is_moving_direction(-walk_lock_direction, input_velocity):
		walk_particles.emitting = false
		return self.set_state(HeroState.walk_turn)
	elif not is_moving_x(input_velocity) and not is_moving_z(input_velocity):
		walk_particles.emitting = false
		return self.set_state(HeroState.walk_skid)

func pre_walk_wall():
	change_animation("Stand")

func walk_wall(delta):
	velocity = get_movement(delta, velocity, input_velocity, FLOOR_ACC, FLOOR_DEC, FLOOR_MAX_SPEED)
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)
	if not on_floor:
		return set_state(HeroState.fall)
	elif not on_wall or is_moving_x(velocity_offset) or is_moving_z(velocity_offset):
		return set_state(HeroState.stand)
	elif input_jump and jumps > 0:
		return set_state(HeroState.jump)

func pre_walk_skid():
	change_animation("Skid")

func walk_skid(delta):
	velocity = get_movement(delta, velocity, Vector3(), FLOOR_ACC, FLOOR_DEC if not is_moving_direction(-walk_lock_direction, input_velocity) else FLOOR_ACC + FLOOR_DEC, FLOOR_MAX_SPEED)
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)
	if not on_floor:
		return set_state(HeroState.fall)
	elif input_jump and jumps > 0:
		return set_state(HeroState.jump)
	elif is_moving_x(input_velocity) and not is_moving_direction(direction, input_velocity):
		return set_state(HeroState.walk_turn)
	elif is_moving_x(input_velocity) or is_moving_z(input_velocity):
		return set_state(HeroState.walk)
	elif not is_moving_x(velocity) and not is_moving_z(velocity):
		return set_state(HeroState.stand)

func pre_walk_turn():
	start_timer(0.1)
	change_animation("Turn")
	play_sound_effect(turn_sound)

func walk_turn(delta):
	velocity = get_movement(delta, velocity, Vector3(), FLOOR_ACC, FLOOR_ACC + FLOOR_DEC, FLOOR_MAX_SPEED)
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)
	if is_timer_finished():
		change_direction(-direction)
		return self.set_state(HeroState.stand)

## Vertical movement states
## ---

func pre_jump():
	jumps -= 1
	velocity = Vector3(velocity.x, JUMP_STRENGTH, velocity.z)
	change_animation("Jump")
	play_sound_effect(jump_sound)

func jump(delta):
	if velocity.y < 0:
		set_state(HeroState.fall)
	velocity = get_movement(delta, velocity, input_velocity, AIRBORNE_ACC, AIRBORNE_DEC, AIRBORNE_MAX_SPEED)
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)

func pre_fall():
	change_animation("Fall")

func fall(delta):
	velocity = get_movement(delta, velocity, input_velocity, AIRBORNE_ACC, AIRBORNE_DEC, AIRBORNE_MAX_SPEED)
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)
	if on_floor:
		return set_state(HeroState.fall_to_stand)

func pre_fall_to_stand():
	start_timer(0.08)
	change_animation("Skid")
	play_sound_effect(step_sound)

func fall_to_stand(delta):
	velocity = get_movement(delta, velocity, Vector3(), FLOOR_ACC, FLOOR_DEC, FLOOR_MAX_SPEED)
	velocity = get_gravity_acceleration(delta, velocity, GRAVITY, GRAVITY_MAX_SPEED)
	if is_timer_finished():
		return self.set_state(HeroState.stand)

func _on_AreaPickup_body_entered(body):
	if body.is_in_group("Coin"):
		coins += 10
		body.queue_free()
		play_sound_effect(coin_sound)
		$HudViewport/HealthHud.set_gold_counter(coins)