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

# number of jumps (reset when grounded)
var jumps = 0
# amount of gold.
var gold = 0
# number of health points
var health = 100

var state = HeroState.stand
var state_prev = state

var velocity = Vector3()
var velocity_prev = velocity
var velocity_offset = velocity

var input_jump = false
var input_velocity = Vector3()

var direction = HeroDirection.right

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
	pass

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