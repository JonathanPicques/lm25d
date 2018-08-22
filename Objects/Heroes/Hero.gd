extends KinematicBody

enum HeroState {
	stand,

	walk,
	walk_2,
	walk_wall,
	walk_skid,
	walk_turn,

	jump,
	fall,
	fall_to_stand,
}
enum HeroDirection {
	left = -1,
	right = 1
}
enum HeroOrientation {
	vertical = 0,
	horizontal = 1
}

# Input

var input_jump = false
var input_velocity = Vector3()
var input_flashlight = false

# State and variables

var state = HeroState.stand
var state_prev = state
var current_animation = ""

var gold = 0
var jumps = 0
var health = 100
var direction = HeroDirection.right
var orientation = HeroOrientation.horizontal
var flashlight_on = true

# Movement

const FLOOR_VECTOR = Vector3(0, 1, 0)
const FLOOR_MAX_ANGLE = cos(deg2rad(45))
const FLOOR_STOP_MIN_VELOCITY = 0.005
const MOVE_STATE_THRESHOLD = 0.1

var velocity = Vector3()
var velocity_prev = velocity
var velocity_offset = velocity

var on_wall = false
var on_floor = false
var on_ceiling = false
var _on_wall_threshold = 0
var _on_floor_threshold = 0
var _on_ceiling_threshold = 0

var floor_angle = 0
var floor_velocity = Vector3()

# Nodes

onready var timer = $Timer
onready var sprite = $HeroSprite
onready var flashlight = $HeroSprite/Flashlight
onready var health_hud = $HudViewport/HealthHud
onready var every_timer = $EveryTimer
onready var walk_particles = $WalkParticles
onready var animation_player = $AnimationPlayer
onready var flashlight_light = $HeroSprite/Flashlight/Light
onready var sound_effect_players = [$SoundEffects/SFX1, $SoundEffects/SFX2, $SoundEffects/SFX3, $SoundEffects/SFX4]

# _process updates input.
# @impure
# @param(float) delta
func _process(delta):
	var up = 1 if Input.is_action_pressed("player_up") else 0
	var down = 1 if Input.is_action_pressed("player_down") else 0
	var left = 1 if Input.is_action_pressed("player_left") else 0
	var right = 1 if Input.is_action_pressed("player_right") else 0
	input_jump = Input.is_action_just_pressed("player_jump")
	input_velocity = Vector3(right - left, input_velocity.y, down - up)
	input_flashlight = Input.is_action_just_pressed("player_flashlight")

# process_velocity updates position after velocity is applied.
# @impure
# @param(float) delta
func process_velocity(delta):
	var old_translation = translation
	velocity_prev = velocity
	velocity = process_move_slide(delta)
	var offset = translation - old_translation
	velocity_offset = Vector3(
		0 if is_nearly(offset.x, 0, 0.001) else velocity.x,
		0 if is_nearly(offset.y, 0, 0.001) else velocity.y,
		0 if is_nearly(offset.z, 0, 0.001) else velocity.z
	)

# process_move_slide updates position after velocity and collisions are applied.
# @impure
# @param(float) delta
func process_move_slide(delta):
	on_wall = _on_wall_threshold > 0
	on_floor = _on_floor_threshold > 0
	on_ceiling = _on_ceiling_threshold > 0
	_on_wall_threshold -= delta
	_on_floor_threshold -= delta
	_on_ceiling_threshold -= delta
	floor_angle = 0
	floor_velocity = Vector3()
	var motion = (velocity + floor_velocity) * delta
	var linear_velocity = velocity
	for number_of_slide in range(0, 4):
		var collision = move_and_collide(motion)
		if collision:
			motion = collision.remainder
			if collision.normal.dot(FLOOR_VECTOR) >= FLOOR_MAX_ANGLE:
				_on_floor_threshold = MOVE_STATE_THRESHOLD
				floor_angle = collision.normal.angle_to(FLOOR_VECTOR)
				floor_velocity = collision.collider_velocity
				var relative_velocity = linear_velocity - floor_velocity
				var horizontal_velocity = relative_velocity - FLOOR_VECTOR * FLOOR_VECTOR.dot(relative_velocity)
				if collision.travel.length() < 0.05 and horizontal_velocity.length() < FLOOR_STOP_MIN_VELOCITY:
					global_transform.origin -= collision.travel
					return floor_velocity - FLOOR_VECTOR * FLOOR_VECTOR.dot(floor_velocity)
			elif collision.normal.dot(-FLOOR_VECTOR) < FLOOR_MAX_ANGLE:
				_on_wall_threshold = MOVE_STATE_THRESHOLD
			else:
				_on_ceiling_threshold = MOVE_STATE_THRESHOLD
			motion = motion.slide(collision.normal)
			linear_velocity = linear_velocity.slide(collision.normal)
			if motion == Vector3():
				break
		else:
			break
	return linear_velocity

## Timer
## ---

# start_timer starts a timer for the given duration in seconds.
# @impure
# @param(float) duration
func start_timer(duration):
	timer.wait_time = duration
	timer.start()

# is_timer_finished returns true if the timer is finished.
# @pure
# @param(float) duration
func is_timer_finished():
	return timer.is_stopped()

# every_seconds returns true every given number of seconds.
# @impure
# @param(float) seconds
# @param(string) timer_tag
var _every_timer_tag = null
func every_seconds(seconds, timer_tag):
	if _every_timer_tag != timer_tag or every_timer.is_stopped():
		_every_timer_tag = timer_tag
		every_timer.wait_time = seconds
		every_timer.start()
		return true
	return false

## Direction / Orientation / Animation
## ---

# change_direction changes the hero direction and flips the sprite accordingly.
# @impure
# @param(float) new_direction
func change_direction(new_direction):
	direction = new_direction
	sprite.scale.x = abs(sprite.scale.x) * new_direction * (1 if orientation == HeroOrientation.horizontal else -1)
	flashlight_light.shadow_reverse_cull_face = new_direction > 0

# change_orientation changes the hero orientation and flips the sprite accordingly.
# @impure
# @param(float) new_direction
func change_orientation(new_orientation):
	orientation = new_orientation
	rotation_degrees.y = (1 - new_orientation) * 90
	change_direction(-direction)

# change_animation changes the sprite animation.
# @impure
# @param(string) animation
func change_animation(animation):
	current_animation = animation
	if flashlight_on and animation_player.get_animation(animation + " Flashlight") != null:
		animation_player.play(animation + " Flashlight")
	else:
		animation_player.play(animation)

# change_animation_speed changes the sprite animation speed.
# @impure
# @param(float) speed
func change_animation_speed(speed):
	animation_player.playback_speed = speed

## Flashlight

# handle_flashlight handles flashlight input
# @impure
func handle_flashlight():
	if input_flashlight:
		input_flashlight = false
		change_flashlight(!flashlight_on)

# change_flashlight changes the flashlight switch status
# @impure
# @param(boolean) new_flashlight_on
func change_flashlight(new_flashlight_on):
	print(new_flashlight_on)
	flashlight_on = new_flashlight_on
	flashlight.visible = flashlight_on
	change_animation(current_animation)

## Audio
## ---

# play_sound_effect plays a sound effect.
# @impure
# @param(AudioStreamSample) stream
func play_sound_effect(stream):
	var sound_effect_player = get_sound_effect_player()
	if sound_effect_player != null:
		sound_effect_player.stream = stream
		sound_effect_player.play()

# is_sound_effect_playing returns true if the given stream is playing.
# @pure
# @param(AudioStreamSample) stream
# @returns(boolean)
func is_sound_effect_playing(stream):
	for sound_effect_player in sound_effect_players:
		if sound_effect_player.stream == stream and sound_effect_player.is_playing():
			return true
	return false

# get_sound_effect_player returns the next available (non-playing) audio stream for sound effects or null.
# @pure
# @returns(AudioStreamPlayer3D)
func get_sound_effect_player():
	for sound_effect_player in sound_effect_players:
		if not sound_effect_player.is_playing():
			return sound_effect_player
	return null

## Gold / Health
## ---

# add_gold adds the given number of gold and updates the HUD.
# @impure
# @param(float) gold_to_add
func add_gold(gold_to_add):
	change_gold(gold + gold_to_add)

# change_gold changes the given number of gold and updates the HUD.
# @impure
# @param(float) gold_to_change
func change_gold(gold_to_change):
	gold = max(0, gold_to_change)
	health_hud.gold_counter = gold

# add_health adds the given number of health points and updates the HUD.
# @impure
# @param(float) health_to_add
func add_health(health_to_add):
	change_health(health + health_to_add)

# change_health changes the health points and updates the HUD.
# @impure
# @param(float) health_to_change
func change_health(health_to_change):
	health = health_to_change
	health_hud.health_counter = health
	if health <= 0:
		pass # TODO: Death

## Movement
## --

# handle_gravity handles gravity.
# @impure
# @param(float) jump_strength
func handle_jump(jump_strength):
	velocity.y = jump_strength
	on_floor = false
	_on_floor_threshold = MOVE_STATE_THRESHOLD

# handle_gravity handles gravity.
# @impure
# @param(float) delta
# @param(Vector3) speed
# @param(Vector3) acceleration
func handle_gravity(delta, speed, acceleration):
	velocity.y = max(velocity.y + delta * acceleration.y, speed.y)

# handle_airborne_move handles moving while airborne.
# @impure
# @param(float) delta
# @param(Vector3) speed
# @param(Vector3) acceleration
# @param(Vector3) deceleration
func handle_airborne_move(delta, speed, acceleration, deceleration):
	if has_forward_input_same_direction():
		handle_directional_move(delta, speed, acceleration, deceleration)
	elif has_upward_input():
		handle_directional_move(delta, with_forward_vector_value(speed, 0), acceleration, deceleration)
	else:
		handle_deceleration_move(delta, deceleration)

# handle_directional_move handles moving in the hero direction.
# @impure
# @param(float) delta
# @param(Vector3) speed
# @param(Vector3) acceleration
# @param(Vector3) deceleration
func handle_directional_move(delta, speed, acceleration, deceleration):
	var upward = sign(get_upward_input()) * get_acceleration(delta, get_upward_velocity(), get_upward_vector(speed), get_upward_vector(acceleration)) if not has_upward_velocity() or has_upward_input_same_direction(sign(get_upward_velocity())) \
			else get_deceleration(delta, get_upward_velocity(), get_upward_vector(deceleration))
	var forward = direction * get_acceleration(delta, get_forward_velocity(), get_forward_vector(speed), get_forward_vector(acceleration)) if not has_forward_velocity() or has_forward_input_same_direction() \
			else get_deceleration(delta, get_forward_velocity(), get_forward_vector(deceleration))
	velocity = with_upward_vector_value(with_forward_vector_value(velocity, forward), upward)

# handle_deceleration handles deceleration.
# @impure
# @param(float) delta
# @param(Vector3) deceleration
func handle_deceleration_move(delta, deceleration):
	var upward = get_deceleration(delta, get_upward_velocity(), get_upward_vector(deceleration))
	var forward = get_deceleration(delta, get_forward_velocity(), get_forward_vector(deceleration))
	velocity = with_upward_vector_value(with_forward_vector_value(velocity, forward), upward)

# get_acceleration returns the next value after the given acceleration is applied, clamped to the given speed.
# @pure
# @param(float) delta
# @param(float) value
# @param(float) speed
# @param(float) acceleration
# @returns(float)
func get_acceleration(delta, value, speed, acceleration):
	return min(abs(value) + delta * acceleration, speed)

# get_deceleration returns the next value after the given deceleration is applied, clamped to zero.
# @pure
# @param(float) delta
# @param(float) value
# @param(float) deceleration
# @returns(Vector3)
func get_deceleration(delta, value, deceleration):
	return max(abs(value) - delta * deceleration, 0) * sign(value)

## Input
## --

# get_upward_input returns the upward input component.
# @pure
# @returns(float)
func get_upward_input():
	return input_velocity.z

# get_upward_input returns the forward input component.
# @pure
# @returns(float)
func get_forward_input():
	return input_velocity.x if orientation == HeroOrientation.horizontal else -input_velocity.x

# has_upward_input returns whether there is a non-zero upward input component.
# @pure
# @returns(boolean)
func has_upward_input():
	return get_upward_input() != 0

# has_forward_input returns whether there is a non-zero forward input component.
# @pure
# @returns(boolean)
func has_forward_input():
	return get_forward_input() != 0

# has_upward_input_same_direction returns whether the upward input component is moving towards the hero direction.
# @pure
# @returns(boolean)
func has_upward_input_same_direction(direction = self.direction):
	return has_same_direction(sign(get_upward_input()), direction)

# has_forward_input_same_direction returns whether the forward input component is moving towards the hero direction.
# @pure
# @returns(boolean)
func has_forward_input_same_direction(direction = self.direction):
	return has_same_direction(sign(get_forward_input()), direction)

# has_upward_input_invert_direction returns whether the upward input component is moving invertedly to the hero direction.
# @pure
# @returns(boolean)
func has_upward_input_invert_direction(direction = self.direction):
	return has_invert_direction(sign(get_upward_input()), direction)

# has_forward_input_invert_direction returns whether the forward input component is moving invertedly to the hero direction.
# @pure
# @returns(boolean)
func has_forward_input_invert_direction(direction = self.direction):
	return has_invert_direction(sign(get_forward_input()), direction)

## Velocity
## --

# get_upward_velocity returns the upward velocity component.
# @pure
# @returns(float)
func get_upward_velocity():
	return get_upward_vector(velocity)

# get_upward_velocity returns the forward velocity component.
# @pure
# @returns(float)
func get_forward_velocity():
	return get_forward_vector(velocity)

# has_upward_velocity returns whether there is a non-zero upward velocity component.
# @pure
# @returns(boolean)
func has_upward_velocity():
	return has_upward_vector(velocity)

# has_forward_velocity returns whether there is a non-zero forward velocity component.
# @pure
# @returns(boolean)
func has_forward_velocity():
	return has_forward_vector(velocity)

# has_upward_velocity_same_direction returns whether the upward velocity component is moving towards the hero direction.
# @pure
# @returns(boolean)
func has_upward_velocity_same_direction(direction = self.direction):
	return has_upward_vector_same_direction(velocity, direction)

# has_forward_velocity_same_direction returns whether the forward velocity component is moving towards the hero direction.
# @pure
# @returns(boolean)
func has_forward_velocity_same_direction(direction = self.direction):
	return has_forward_vector_same_direction(velocity, direction)

# has_upward_velocity_invert_direction returns whether the upward velocity component is moving invertedly to the hero direction.
# @pure
# @returns(boolean)
func has_upward_velocity_invert_direction(direction = self.direction):
	return has_upward_vector_invert_direction(velocity, direction)

## Direction
## --

# has_same_direction returns true if the two given numbers are non-zero and of the same sign.
# @pure
# @param(float) a
# @param(float) b
# returns(boolean)
func has_same_direction(a, b):
	return a != 0 and sign(a) == sign(b)

# has_invert_direction returns true if the two given numbers are non-zero and of the opposed sign.
# @pure
# @param(float) a
# @param(float) b
# returns(boolean)
func has_invert_direction(a, b):
	return a != 0 and sign(a) != sign(b)

## Utilities
## --

# is_nearly returns true if the first given value nearly equals the second given value.
# @pure
# @param(float) value1
# @param(float) value2
# @param(float) epsilon
# @returns(boolean)
func is_nearly(value1, value2, epsilon = 0.01):
	return abs(value1 - value2) < epsilon

# get_upward_vector returns the upward vector component.
# @pure
# @returns(float)
func get_upward_vector(vec):
	return vec.z if orientation == HeroOrientation.horizontal else vec.x

# get_upward_vector returns the forward vector component.
# @pure
# @returns(float)
func get_forward_vector(vec):
	return vec.x if orientation == HeroOrientation.horizontal else vec.z

# has_upward_vector returns whether there is a non-zero upward vector component.
# @pure
# @returns(boolean)
func has_upward_vector(vec):
	return not is_nearly(vec.z if orientation == HeroOrientation.horizontal else vec.x, 0, 0.001)

# has_forward_vector returns whether there is a non-zero forward vector component.
# @pure
# @returns(boolean)
func has_forward_vector(vec):
	return not is_nearly(vec.x if orientation == HeroOrientation.horizontal else vec.z, 0, 0.001)

# has_upward_vector_same_direction returns whether the upward vector component is moving towards the hero direction.
# @pure
# @returns(boolean)
func has_upward_vector_same_direction(vec, direction = self.direction):
	return has_same_direction(sign(get_upward_vector(vec)), direction)

# has_forward_vector_same_direction returns whether the forward vector component is moving towards the hero direction.
# @pure
# @returns(boolean)
func has_forward_vector_same_direction(vec, direction = self.direction):
	return has_same_direction(sign(get_forward_vector(vec)), direction)

# has_upward_vector_invert_direction returns whether the upward vector component is moving invertedly to the hero direction.
# @pure
# @returns(boolean)
func has_upward_vector_invert_direction(vec, direction = self.direction):
	return has_invert_direction(sign(get_upward_vector(vec)), direction)

# has_forward_vector_invert_direction returns whether the forward vector component is moving invertedly to the hero direction.
# @pure
# @returns(boolean)
func has_forward_vector_invert_direction(vec, direction = self.direction):
	return has_invert_direction(sign(get_forward_vector(vec)), direction)

# with_upward_vector_value returns a vector with the upward component set to the given value.
# @pure
# @param(Vector3) vec
# @param(float) value
# @returns(Vector3)
func with_upward_vector_value(vec, value):
	match orientation:
		HeroOrientation.vertical: return Vector3(value, vec.y, vec.z)
		HeroOrientation.horizontal: return Vector3(vec.x, vec.y, value)

# with_forward_vector_value returns a vector with the forward component set to the given value.
# @pure
# @param(Vector3) vec
# @param(float) value
# @returns(Vector3)
func with_forward_vector_value(vec, value):
	match orientation:
		HeroOrientation.vertical: return Vector3(vec.x, vec.y, value)
		HeroOrientation.horizontal: return Vector3(value, vec.y, vec.z)