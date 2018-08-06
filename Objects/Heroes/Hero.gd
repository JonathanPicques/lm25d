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

const FLOOR_VECTOR = Vector3(0, 1, 0)
const FLOOR_MAX_ANGLE = cos(deg2rad(45))
const MOVE_STATE_THRESHOLD = 0.1

var jumps = 0
var coins = 0
var health = 100

var state = HeroState.stand
var state_prev = state

var velocity = Vector3()
var velocity_prev = velocity
var velocity_offset = velocity

var input_jump = false
var input_velocity = Vector3()

var direction = HeroDirection.right

var on_wall = false
var on_floor = false
var on_ceiling = false
var _on_wall_threshold = 0
var _on_floor_threshold = 0
var _on_ceiling_threshold = 0

var floor_angle = 0
var floor_velocity = Vector3()

var _every_timer_tag = null


onready var timer = $Timer
onready var sprite = $HeroSprite
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
				if collision.travel.length() < 0.05 and horizontal_velocity.length() < 0.001:
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

# start_timer starts a timer for the given duration in seconds.
# @impure
# @param(float) duration
func start_timer(duration):
	timer.wait_time = duration
	timer.start()

# every_seconds returns true every given seconds.
# @impure
# @param(float) seconds
# @param(string) timer_tag
func every_seconds(seconds, timer_tag):
	if _every_timer_tag != timer_tag or every_timer.is_stopped():
		_every_timer_tag = timer_tag
		every_timer.wait_time = seconds
		every_timer.start()
		return true
	return false

# is_timer_finished returns true if the timer is finished.
# @pure
# @param(float) duration
func is_timer_finished():
	return timer.is_stopped()

# change_direction changes the hero direction and flips the sprite accordingly.
# @impure
# @param(float) new_direction
func change_direction(new_direction):
	direction = new_direction
	sprite.scale.x = new_direction
	flashlight_light.shadow_reverse_cull_face = new_direction > 0

# change_animation changes the sprite animation.
# @impure
# @param(string) animation
func change_animation(animation):
	animation_player.play(animation + " Flashlight" if animation != "Turn" else "Turn")

# change_animation_speed changes the sprite animation speed.
# @impure
# @param(float) speed
func change_animation_speed(speed):
	animation_player.playback_speed = speed

# play_sound_effect plays a sound effect.
# @impure
# @param(AudioStreamSample) stream
func play_sound_effect(stream):
	var sound_effect_player = get_available_sound_effect_player()
	if sound_effect_player != null:
		sound_effect_player.stream = stream
		sound_effect_player.play()

# is_sound_effect_playing returns true if the given stream is playing.
# @pure
# @param(AudioStreamSample) stream
# @returns(bool)
func is_sound_effect_playing(stream):
	for sound_effect_player in sound_effect_players:
		if sound_effect_player.stream == stream and sound_effect_player.is_playing():
			return true
	return false

# get_available_sound_effect_player returns the next available (non-playing) audio stream for sound effects or null.
# @pure
# @returns(AudioStreamPlayer3D)
func get_available_sound_effect_player():
	for sound_effect_player in sound_effect_players:
		if not sound_effect_player.is_playing():
			return sound_effect_player
	return null

# is_nearly returns true if the first given value nearly equals the second given value.
# @pure
# @param(float) value1
# @param(float) value2
# @param(float) epsilon
# @returns(bool)
func is_nearly(value1, value2, epsilon = 0.01):
	return abs(value1 - value2) < epsilon

# is_moving_x returns true if the given velocity has a non-zero x.
# @pure
# @param(Vector3) velocity
# @returns(bool)
func is_moving_x(velocity):
	return velocity.x != 0

# is_moving_z returns true if the given velocity has a non-zero z.
# @pure
# @param(Vector3) velocity
# @returns(bool)
func is_moving_z(velocity):
	return velocity.z != 0

# is_moving_direction returns true if the given velocity in x is moving in the given direction.
# @pure
# @param (float) direction
# @param(Vector3) velocity
# @returns(bool)
func is_moving_direction(direction, velocity):
	return int(sign(velocity.x)) == direction

# get_movement returns the next velocity after given acceleration or deceleration is applied depending on the given direction.
# @pure
# @param(float) delta
# @param(Vector3) velocity
# @param(Vector3) direction
# @param(Vector3) acceleration
# @param(Vector3) maximum_speed
# @returns(Vector3)
func get_movement(delta, velocity, direction, acceleration, deceleration, maximum_speed, force = false):
	return Vector3(
		get_acceleration(delta, velocity.x, direction.x, acceleration.x, maximum_speed.x) if force or (velocity.x == 0 or sign(direction.x) == sign(velocity.x)) else get_deceleration(delta, velocity.x, deceleration.x),
		velocity.y,
		get_acceleration(delta, velocity.z, direction.z, acceleration.z, maximum_speed.z) if force or (velocity.z == 0 or sign(direction.z) == sign(velocity.z)) else get_deceleration(delta, velocity.z, deceleration.z)
	)

# get_acceleration returns the next value after the given acceleration is applied, clamped to the given maximum_speed.
# @pure
# @param(float) delta
# @param(float) velocity
# @param(float) direction
# @param(float) acceleration
# @param(float) maximum_speed
# @returns(float)
func get_acceleration(delta, velocity, direction, acceleration, maximum_speed):
	return min(abs(velocity) + delta * acceleration, maximum_speed) * sign(direction)

# get_deceleration returns the next value after the given deceleration is applied, clamped to zero.
# @pure
# @param(float) delta
# @param(float) velocity
# @param(float) deceleration
# @returns(Vector3)
func get_deceleration(delta, velocity, deceleration):
	return max(abs(velocity) - delta * deceleration, 0) * sign(velocity)

# get_gravity_acceleration returns the next value after the gravity is applied, clamped to the given gravity_max_speed.
# @pure
# @param(Vector3) delta
# @param(Vector3) velocity
# @param(Vector3) gravity
# @param(Vector3) gravity_max_speed
# @returns(Vector3)
func get_gravity_acceleration(delta, velocity, gravity, gravity_max_speed):
	return Vector3(velocity.x, max(velocity.y + gravity.y * delta, gravity_max_speed.y), velocity.z)