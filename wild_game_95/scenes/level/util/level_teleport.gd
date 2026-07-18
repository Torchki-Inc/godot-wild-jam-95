extends Area3D

@export var teleport_target: Marker3D
@export var exit_direction: Vector3 = Vector3.RIGHT
@export var walk_out_duration: float = 1.0


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		print(body)
		body.global_position = teleport_target.global_position
		body.start_scripted_walk(exit_direction, walk_out_duration)
