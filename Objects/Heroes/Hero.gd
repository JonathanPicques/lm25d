extends KinematicBody

enum HeroState {
	stand,

	walk,
	walk_2,
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

var jumps = 0

var state = HeroState.stand
var state_prev = HeroState.stand

var velocity = Vector3()
var velocity_prev = velocity

var input_jump = false
var input_velocity = Vector3()

var direction = HeroDirection.right

var on_wall = false
var on_floor = false
var on_ceiling = false
var floor_angle = 0
var floor_velocity = Vector3()

var _every_timer_tag = null

onready var timer = $Timer
onready var sprite = $HeroSprite
onready var every_timer = $EveryTimer
onready var smoke_particle = $SmokeParticles
onready var animation_player = $AnimationPlayer
onready var audio_stream_player = $AudioStreamPlayer3D

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

# _process_velocity updates position after velocity is applied.
# @impure
# @param(float) delta
func _process_velocity(delta):
	velocity_prev = velocity
	velocity = _process_move_slide(delta)

# _process_move_slide
# @impure
# @param(float) delta
func _process_move_slide(delta):
	on_wall = false
	on_floor = false
	on_ceiling = false
	floor_angle = 0
	floor_velocity = Vector3()
	var motion = (velocity + floor_velocity) * delta
	var linear_velocity = velocity
	for number_of_slide in range(0, 4):
		var collision = move_and_collide(motion)
		if collision:
			motion = collision.remainder
			if collision.normal.dot(FLOOR_VECTOR) >= FLOOR_MAX_ANGLE:
				on_floor = true
				floor_angle = collision.normal.angle_to(FLOOR_VECTOR)
				floor_velocity = collision.collider_velocity
				var relative_velocity = linear_velocity - floor_velocity
				var horizontal_velocity = relative_velocity - FLOOR_VECTOR * FLOOR_VECTOR.dot(relative_velocity)
				if collision.travel.length() < 0.05 and horizontal_velocity.length() < 0.001:
					global_transform.origin -= collision.travel
					return floor_velocity - FLOOR_VECTOR * FLOOR_VECTOR.dot(floor_velocity)
			elif collision.normal.dot(-FLOOR_VECTOR) >= FLOOR_MAX_ANGLE:
				on_ceiling = true
			else:
				on_wall = true
			motion = motion.slide(collision.normal)
			linear_velocity = linear_velocity.slide(collision.normal)
			if motion == Vector3():
				break
		else:
			break
	return linear_velocity

# _start_timer starts a timer for the given duration in seconds.
# @impure
# @param(float) duration
func _start_timer(duration):
	timer.wait_time = duration
	timer.start()

# _every_seconds returns true every given seconds.
# @impure
# @param(float) seconds
# @param(string) timer_tag
func _every_seconds(seconds, timer_tag):
	if _every_timer_tag != timer_tag or every_timer.is_stopped():
		_every_timer_tag = timer_tag
		every_timer.wait_time = seconds
		every_timer.start()
		return true
	return false

# _is_timer_over returns true if the timer is finished.
# @pure
# @param(float) duration
func _is_timer_finished():
	return timer.is_stopped()

# _change_direction changes the hero direction and flips the sprite accordingly.
# @impure
# @param(float) new_direction
func _change_direction(new_direction):
	direction = new_direction
	sprite.scale.x = new_direction
	# sprite.transform = sprite.transform.rotated(Vector3(0.0, 1.0, 0.0), PI)

# _change_animation changes the sprite animation.
# @impure
# @param(string) animation
func _change_animation(animation):
	animation_player.play(animation + " Flashlight" if animation != "Turn" else "Turn")

# _change_animation_speed changes the sprite animation speed.
# @impure
# @param(float) speed
func _change_animation_speed(speed):
	animation_player.playback_speed = speed

# _play_sound_effect plays a sound effect if not already playing (can be forced).
# @impure
# @param(AudioStreamSample) stream
func _play_sound_effect(stream, force = true):
	if force or not audio_stream_player.is_playing():
		audio_stream_player.stream = stream
		audio_stream_player.play()

# _sound_effect_playing returns true if the given stream is playing.
# @pure
# @param(AudioStreamSample) stream
# @returns(bool)
func _is_sound_effect_playing(stream):
	return audio_stream_player.stream == stream and audio_stream_player.is_playing()

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