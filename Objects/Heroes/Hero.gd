extends KinematicBody

enum HeroState {
	stand,

	walk,
	walk_turn,
	walk_wall,

	fall,
	fall_recovery,
	jump
}
enum HeroDirection {
	left = -1,
	none = 0,
	right = 1
}

var jumps = 0

var input = preload("Input.gd").new()
var input_direction = HeroDirection.none

var state = HeroState.stand
var state_prev = HeroState.stand

var velocity = Vector3()
var velocity_prev = Vector3()

var direction = HeroDirection.right

var wall_time = 0
var on_wall = false
var floor_time = 0
var on_floor = false

onready var timer = $Timer
onready var sprite = $Sprite3D
onready var animation_player = $AnimationPlayer

func integrate_jump():
	on_floor = false
	floor_time = 0

func integrate_input(delta):
	input.integrate_input(delta)
	input_direction = get_input_direction()

func integrate_velocity(delta):
	velocity = move_and_slide(velocity, Vector3(0, 1, 0))
	wall_time -= delta
	floor_time -= delta
	if is_on_wall():
		wall_time = 0.1
	if is_on_floor():
		floor_time = 0.1
	on_wall = wall_time > 0
	on_floor = floor_time > 0

func start_timer(seconds):
	timer.set_wait_time(seconds)
	timer.start()

func change_direction(new_direction):
	direction = new_direction
	sprite.scale.x = new_direction

func get_input_direction():
	var opposed = input.left and input.right or (not input.left and not input.right)
	return HeroDirection.none if opposed else HeroDirection.left if input.left else HeroDirection.right

func get_vector_direction(vector):
	return int(sign(vector.x))

func get_velocity_direction():
	return get_vector_direction(velocity)

func get_horizontal_acceleration(delta, velocity, direction, acceleration, maximum_speed):
	match direction:
		HeroDirection.left: return Vector3(max(velocity.x - acceleration * delta, -maximum_speed), velocity.y, velocity.z)
		HeroDirection.right: return Vector3(min(velocity.x + acceleration * delta, maximum_speed), velocity.y, velocity.z)
	return velocity

func get_horizontal_deceleration(delta, velocity, deceleration):
	match get_vector_direction(velocity):
		HeroDirection.left: return Vector3(min(velocity.x + deceleration * delta, 0), velocity.y, velocity.z)
		HeroDirection.right: return Vector3(max(velocity.x - deceleration * delta, 0), velocity.y, velocity.z)
	return velocity

func get_vertical_acceleration(delta, velocity, acceleration, maximum_speed):
	return Vector3(velocity.x, max(velocity.y + acceleration * delta, maximum_speed), velocity.z)

func get_horizontal_input_movement(delta, velocity, direction, acceleration, deceleration, maximum_speed):
	if input_direction == HeroDirection.none:
		return get_horizontal_deceleration(delta, velocity, deceleration)
	elif input_direction == direction:
		return get_horizontal_acceleration(delta, velocity, input_direction, acceleration, maximum_speed)
	else:
		return get_horizontal_deceleration(delta, velocity, (acceleration + deceleration))