var jump = false
var left = false
var right = false

func integrate_input(delta):
	jump = Input.is_action_just_pressed("ui_up")
	left = Input.is_action_pressed("ui_left")
	right = Input.is_action_pressed("ui_right")