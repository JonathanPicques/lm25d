extends "../Hero.gd"

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
	pass

func stand(delta):
	pass

func pre_walk():
	pass

func walk(delta):
	pass

func pre_walk_2():
	pass

func walk_2(delta):
	pass

func pre_walk_wall():
	pass

func walk_wall(delta):
	pass

func pre_walk_skid():
	pass

func walk_skid(delta):
	pass

func pre_walk_turn():
	pass

func walk_turn(delta):
	pass

## Vertical movement states
## ---

func pre_jump():
	pass

func jump(delta):
	pass

func pre_fall():
	pass

func fall(delta):
	pass

func pre_fall_to_stand():
	pass

func fall_to_stand(delta):
	pass

## Pickup
## ---

func _on_AreaPickup_body_entered(body):
	pass