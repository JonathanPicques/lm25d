extends KinematicBody

enum HeroState {
	stand,

	walk,
	walk_turn,

	jump,
	fall,
	fall_to_stand,
}
enum HeroDirection {
	left = -1,
	right = 1
}

const FLOOR_VECTOR = Vector3(0.0, 1.0, 0.0)

var jumps = 0

var state = HeroState.stand
var state_prev = HeroState.stand

var velocity = Vector3()

var input_jump = false
var input_velocity = Vector3()

var direction = HeroDirection.right

var on_wall = false
var on_floor = false
var _wall_time = 0
var _floor_time = 0

var _every_timer_tag = null

onready var timer = $Timer
onready var sprite = $Sprite3D
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

var f = 0

# _process_velocity updates position after velocity is applied.
# @impure
# @param(float) delta
func _process_velocity(delta):
	velocity = move_and_slide(velocity, FLOOR_VECTOR, 0.0)
	_wall_time -= delta
	_floor_time -= delta
	if is_on_wall():
		_wall_time = 0.1
	if is_on_floor():
		_floor_time = 0.1
	on_wall = _wall_time > 0
	on_floor = _floor_time > 0

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

# _change_direction changes the hero direction and flips the sprite accordingly.
# @impure
# @param(float) new_direction
func _change_direction(new_direction):
	direction = new_direction
	sprite.scale.x = new_direction

# _change_animation changes the sprite animation.
# @impure
# @param(string) animation
func _change_animation(animation):
	animation_player.play(animation)

# _play_sound_effect plays a sound effect if not already playing (can be forced).
# @impure
# @param(AudioStreamSample) stream
func _play_sound_effect(stream, force = true):
	if force or not audio_stream_player.is_playing():
		audio_stream_player.stream = stream
		audio_stream_player.play()

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

# is_moving_direction returns true if the given velocity is moving in the given direction.
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