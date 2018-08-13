extends KinematicBody

enum HeroState {
	stand,

	walk,
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
	Vertical = 0,
	Horizontal = 1
}

const FLOOR_NORMAL = Vector3(0, 1, 0)
const FLOOR_MAX_ANGLE = cos(deg2rad(45))
const MOVE_STATE_THRESHOLD = 0.1

var jumps = 0

var gold = 0
var health = 100

var state = HeroState.stand
var state_prev = state

var velocity = Vector3()
var velocity_prev = velocity
var velocity_offset = velocity

var floor_angle = 0
var floor_velocity = Vector3()
var on_wall = false
var on_floor = false
var on_ceiling = false
var _on_wall_threshold = 0
var _on_floor_threshold = 0
var _on_ceiling_threshold = 0

var input_jump = false
var input_velocity = Vector3()

var direction = HeroDirection.right
var orientation = HeroOrientation.Horizontal

onready var timer = $Timer
onready var sprite = $HeroSprite
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

# process_velocity updates position after velocity is applied.
# @impure
# @param(float) delta
func process_velocity(delta):
	var old_translation = translation
	velocity_prev = velocity
	velocity = move_and_slide(delta, velocity)
	var offset = translation - old_translation
	velocity_offset = Vector3(
		0 if is_nearly(offset.x, 0, 0.001) else velocity.x,
		0 if is_nearly(offset.y, 0, 0.001) else velocity.y,
		0 if is_nearly(offset.z, 0, 0.001) else velocity.z
	)

# move_and_slide updates position after velocity and collisions are applied.
# @impure
# @param(float) delta
func move_and_slide(delta, velocity):
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
			if collision.normal.dot(FLOOR_NORMAL) >= FLOOR_MAX_ANGLE:
				_on_floor_threshold = MOVE_STATE_THRESHOLD
				floor_angle = collision.normal.angle_to(FLOOR_NORMAL)
				floor_velocity = collision.collider_velocity
				var relative_velocity = linear_velocity - floor_velocity
				var horizontal_velocity = relative_velocity - FLOOR_NORMAL * FLOOR_NORMAL.dot(relative_velocity)
				if collision.travel.length() < 0.05 and horizontal_velocity.length() < 0.001:
					global_transform.origin -= collision.travel
					return floor_velocity - FLOOR_NORMAL * FLOOR_NORMAL.dot(floor_velocity)
			elif collision.normal.dot(-FLOOR_NORMAL) < FLOOR_MAX_ANGLE:
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

## Animation / Direction
## ---

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
	animation_player.play(animation)

# change_animation_speed changes the sprite animation speed.
# @impure
# @param(float) speed
func change_animation_speed(speed):
	animation_player.playback_speed = speed

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
# @returns(bool)
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
## ---

# handle_gravity handles gravity.
# @impure
# @param(float) jump_strength
func handle_jump(jump_strength):
	on_floor = false
	_on_floor_threshold = 0
	velocity.y = jump_strength

# handle_gravity handles gravity.
# @impure
# @param(float) delta
# @param(Vector3) speed
# @param(Vector3) acceleration
func handle_gravity(delta, speed, acceleration):
	velocity.y = max(velocity.y + delta * acceleration, speed)

# handle_free_move handles moving in or against the given direction.
# @impure
# @param(float) delta
# @param(Vector3) speed
# @param(Vector3) acceleration
# @param(Vector3) deceleration
func handle_airborne_move(delta, speed, acceleration, deceleration):
	if sign(input_velocity.x) == direction:
		handle_directional_move(delta, speed, acceleration, deceleration)
	else:
		handle_deceleration_move(delta, speed, deceleration)

# handle_directional_move handles moving in the same direction.
# @impure
# @param(float) delta
# @param(Vector3) speed
# @param(Vector3) acceleration
# @param(Vector3) deceleration
func handle_directional_move(delta, speed, acceleration, deceleration):
	var accelerate_upward = sign(input_velocity.z) != 0
	var accelerate_forward = sign(input_velocity.x) == direction
	velocity = Vector3(
		direction * min(abs(velocity.x) + delta * acceleration.x, speed.x) if accelerate_forward else max(abs(velocity.x) - delta * deceleration.x, 0) * sign(velocity.x),
		velocity.y,
		sign(input_velocity.z) * min(abs(velocity.z) + delta * acceleration.z, speed.z) if accelerate_upward else max(abs(velocity.z) - delta * deceleration.z, 0) * sign(velocity.z)
	)

# handle_deceleration handles deceleration.
# @impure
# @param(float) delta
# @param(Vector3) speed
# @param(Vector3) deceleration
func handle_deceleration_move(delta, speed, deceleration):
	velocity = Vector3(
		max(abs(velocity.x) - delta * deceleration.x, 0) * sign(velocity.x),
		velocity.y,
		max(abs(velocity.z) - delta * deceleration.z, 0) * sign(velocity.z)
	)

## Velocity
## --

# get_upward_velocity returns the upward vector value depending on the given orientation.
# @pure
# @param(Vector3) vec
# @param(HeroOrientation) orientation
# @returns(float)
func get_upward_velocity(vec, orientation = HeroOrientation.Horizontal):
	match orientation:
		HeroOrientation.Vertical:
			return vec.x
		HeroOrientation.Horizontal:
			return vec.z

# get_forward_velocity returns the forward vector value depending on the given orientation.
# @pure
# @param(Vector3) vec
# @param(HeroOrientation) orientation
# @returns(float)
func get_forward_velocity(vec, orientation = HeroOrientation.Horizontal):
	match orientation:
		HeroOrientation.Vertical:
			return vec.z
		HeroOrientation.Horizontal:
			return vec.x

# with_upward_velocity returns a new vector with the upward vector set to the given value depending on the given orientation.
# @pure
# @param(Vector3) vec
# @param(float) value
# @param(HeroOrientation) orientation
# @returns(Vector3)
func with_upward_velocity(vec, value, orientation = HeroOrientation.Horizontal):
	match orientation:
		HeroOrientation.Vertical:
			return Vector3(value, vec.y, vec.z)
		HeroOrientation.Horizontal:
			return Vector3(vec.x, vec.y, value)

# with_forward_velocity returns a new vector with the forward vector set to the given value depending on the given orientation.
# @pure
# @param(Vector3) vec
# @param(float) value
# @param(HeroOrientation) orientation
# @returns(Vector3)
func with_forward_velocity(vec, value, orientation = HeroOrientation.Horizontal):
	match orientation:
		HeroOrientation.Vertical:
			return Vector3(vec.x, vec.y, value)
		HeroOrientation.Horizontal:
			return Vector3(value, vec.y, vec.z)

## Utilities
## ---

# is_nearly returns true if the first given value nearly equals the second given value by the given epsilon.
# @pure
# @param(float) value1
# @param(float) value2
# @param(float) epsilon
# @returns(bool)
func is_nearly(value1, value2, epsilon = 0.01):
	return abs(value1 - value2) < epsilon

# is_moving_upward returns true whether the given vector as a non zero oriented upward value.
# @pure
# @param(Vector3) vec
# @returns(boolean)
func is_moving_upward(vec, orientation = HeroOrientation.Horizontal):
	return not is_nearly(get_upward_velocity(vec, orientation), 0)

# is_moving_forward returns true whether the given vector as a non zero oriented forward value.
# @pure
# @param(Vector3) vec
# @returns(boolean)
func is_moving_forward(vec, orientation = HeroOrientation.Horizontal):
	return not is_nearly(get_forward_velocity(vec, orientation), 0)

# is_moving_direction
# @pure
# @param(float) a
# @param(float) b
func is_moving_direction(a, b):
	return a != 0 and sign(a) == sign(b)

# is_moving_direction
# @pure
# @param(float) a
# @param(float) b
func is_moving_invert_direction(a, b):
	return a != 0 and sign(a) != sign(b)