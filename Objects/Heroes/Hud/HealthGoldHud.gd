extends Control

var _gold_counter = 0
var _gold_counter_prev = 0
export var gold_counter = 0 setget set_gold_counter, get_gold_counter

var _health_counter = 100
var _health_counter_prev = 100
export var health_counter = 100 setget set_health_counter, get_health_counter

func set_gold_counter(value):
	_gold_counter = value

func get_gold_counter():
	return _gold_counter

func set_health_counter(value):
	_health_counter = value

func get_health_counter():
	return _health_counter

func _process(delta):
	if _health_counter != _health_counter_prev or _gold_counter != _gold_counter_prev:
		if $AnimationPlayer.assigned_animation != "Appear":
			$AnimationPlayer.play("Appear")
		$VisibilityTimer.stop()
		$VisibilityTimer.start()
	elif $AnimationPlayer.assigned_animation != "Disappear" and $VisibilityTimer.is_stopped():
		$VisibilityTimer.start()
	
	if abs(_health_counter - _health_counter_prev) <= 1:
		_health_counter_prev = _health_counter
	_health_counter_prev = _health_counter_prev + sign(_health_counter - _health_counter_prev)
	if abs(_gold_counter - _gold_counter_prev) <= 1:
		_gold_counter_prev = _gold_counter
	_gold_counter_prev = _gold_counter_prev + sign(_gold_counter - _gold_counter_prev)
	
	$HealthHearts.texture.region.position.x = floor(lerp(0, 6, _health_counter_prev / 100.0)) * 16
	$HealthCounter.text = "%0*d" % [3, _health_counter_prev]
	$GoldCounter.text = comma_sep(_gold_counter_prev)

func comma_sep(number):
	var string = str(number)
	var string_len = len(string)
	var string_mod = string_len % 3
	var string_sep = ""
	for i in range(0, string_len):
		if i != 0 && i % 3 == string_mod:
			string_sep += ","
		string_sep += string[i]
	return string_sep

func _on_VisibilityTimer_timeout():
	$AnimationPlayer.play("Disappear")