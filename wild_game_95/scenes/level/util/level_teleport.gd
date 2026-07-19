extends Area3D

@export var teleport_target: Marker3D
@export var walk_in_direction: Vector3 = Vector3.FORWARD
@export var walk_in_duration: float = 2.0
@export var exit_direction: Vector3 = Vector3.RIGHT
@export var walk_out_duration: float = 1.0
@export var fade_duration: float = 0.3

var _triggered: bool = false


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Player"):
		return
	if not teleport_target or _triggered:
		return
	_triggered = true
	_do_transition(body)

func _do_transition(body: Node3D) -> void:
	if not teleport_target:
		return

	body.start_scripted_walk(walk_in_direction, walk_in_duration)
	ScreenFade.fade_out(fade_duration)
	await get_tree().create_timer(fade_duration).timeout

	body.global_position = teleport_target.global_position
	body.start_scripted_walk(exit_direction, walk_out_duration)
	await ScreenFade.fade_in(fade_duration)
	_triggered = false
