extends Node3D

@export var base_light_energy := 3.0
@export var light_flicker := 0.45

@export var flicker_speed := 7.0

@onready var light: OmniLight3D = $OmniLight3D

var noise := FastNoiseLite.new()
var time_offset := 0.0


func _ready() -> void:
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.65

	time_offset = randf_range(0.0, 100.0)


func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	var value := noise.get_noise_1d(
		(time + time_offset) * flicker_speed
	)

	light.light_energy = base_light_energy + value * light_flicker
