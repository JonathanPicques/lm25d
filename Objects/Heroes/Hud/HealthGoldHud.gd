extends Control

var _gold_counter = 0
export var gold_counter = 43020 setget set_gold_counter, get_gold_counter

var _health_counter = 0
export var health_counter = 100 setget set_health_counter, get_health_counter

func set_gold_counter(value):
	_gold_counter = value

func get_gold_counter():
	return _gold_counter

func set_health_counter(value):
	_health_counter = value

func get_health_counter():
	return _health_counter

func _ready():
	appear()

func _process(delta):
	$HealthHearts.texture.region.position.x = floor(lerp(0, 6, _health_counter / 100.0)) * 16
	$HealthCounter.text = "%0*d" % [3, _health_counter]
	$GoldCounter.text = comma_sep(_gold_counter)

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

func appear():
	if $AnimationPlayer == null:
		return
	$VisibilityTimer.start()
	$AnimationPlayer.play("Appear")

func _on_VisibilityTimer_timeout():
	$AnimationPlayer.play("Disappear")