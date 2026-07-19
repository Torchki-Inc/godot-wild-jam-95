class_name Lever
extends Node3D

signal activated

@export_group("Textures")
@export var lever_texture_up: Texture2D
@export var lever_texture_down: Texture2D

@export var lever_id: String
@export var activation_message: String = ""

var in_lever_area: bool = false
var is_activated: bool = false

func _ready() -> void:
	if lever_texture_down == null:
		lever_texture_down = lever_texture_up
	$Sprite3D.texture = lever_texture_up

func activate() -> void:
	GameState.add_lever(lever_id)
	if activation_message != "":
		MessageManager.show_custom_message(activation_message)
	$Sprite3D.texture = lever_texture_down
	# else:
		# MessageManager.show_message("l")
	emit_signal("activated")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("interact") && in_lever_area:
		activate()

func _on_area_3d_area_exited(area: Area3D) -> void:
	if area.is_in_group("Player"):
		in_lever_area = false


func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("Player"):
		in_lever_area = true
