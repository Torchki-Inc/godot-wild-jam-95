class_name Door
extends Node3D

@export var area: Area3D
@export var required_key: String = ""

@export var required_levers: Array[Lever] = []

var player_in_area: bool = false

func _ready() -> void:
	for lever in required_levers:
		lever.activated.connect(try_open)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("interact") && player_in_area:
		try_open()


func try_open() -> void:
	if required_key == "" && required_levers.all(func(l): return GameState.has_lever(l.lever_id)) or GameState.has_key(required_key):
		open_door()
	else:
		#CALL MESSAGE LOG
		MessageManager.show_message("door_locked", {"item": required_key} )
		MessageManager.show_message("need_key", {"item": required_key} )

		print("Door is close, " + required_key + " required" )

func open_door():
	if area:
		area.monitoring = false
		rotation.y -= 67.5
	print("Door opened")

func _on_area_3d_area_exited(area: Area3D) -> void:
	player_in_area = false

func _on_area_3d_area_entered(area: Area3D) -> void:
	player_in_area = true
