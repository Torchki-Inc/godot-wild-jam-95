extends CharacterBody3D

@export_group("Movement")
@export var SPEED = 14.0
@export var acceleration: float = 10.0
@export var friction: float = 12.0

@export_group("Camera")
@export var head: Node3D



func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down",
	)
	var direction := Vector3(input_dir.x, 0, input_dir.y)
	var target_velocity := Vector3(input_dir.x * SPEED, 0, input_dir.y * SPEED)

	if direction.length() > 0.01:
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta * SPEED)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta * SPEED)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta * SPEED)
		velocity.z = move_toward(velocity.z, 0, friction * delta * SPEED)

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	move_and_slide()
