extends Node3D

@export var pulse_speed := 0.65
@export var pulse_amount := 0.7

@onready var lights: Array[Light3D] = [
    $AreaLight3D,
    $AreaLight3D2,
    $AreaLight3D3,
    $AreaLight3D4,
]

var base_energies: Array[float] = []
var phases := [0.0, 0.8, 1.6, 2.4]
var elapsed := 0.0


func _ready() -> void:
    for light in lights:
        base_energies.append(light.light_energy)


func _process(delta: float) -> void:
    elapsed += delta

    for index in lights.size():
        var wave := sin(elapsed * pulse_speed + phases[index])

        lights[index].light_energy = (
            base_energies[index]
            + wave * pulse_amount
        )
