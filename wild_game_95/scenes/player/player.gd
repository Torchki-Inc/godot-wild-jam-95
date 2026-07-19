extends CharacterBody3D

@export_group("Movement")
@export var SPEED = 14.0
@export var acceleration: float = 10.0
@export var friction: float = 12.0

@export_group("Camera")
@export var head: Node3D
@export var debug_label: Label

@export var sprite: AnimatedSprite3D

enum FacingDirection {
	FORWARD,
	BACKWARD,
	LEFT,
	RIGHT,
}
var current_facing: FacingDirection = FacingDirection.LEFT

var is_scripted_moving: bool = false
var scripted_direction: Vector3 = Vector3.ZERO


func _physics_process(delta: float) -> void:
	RenderingServer.global_shader_parameter_set("player_position", global_position)
	update_debug_label()

	var direction := Vector3.ZERO

	if is_scripted_moving:
		direction = scripted_direction
	else:
		var dir := Vector2.ZERO
		if Input.is_action_pressed("move_left"):
			dir = Vector2.LEFT
		elif Input.is_action_pressed("move_right"):
			dir = Vector2.RIGHT
		elif Input.is_action_pressed("move_up"):
			dir = Vector2.UP
		elif Input.is_action_pressed("move_down"):
			dir = Vector2.DOWN
		direction = Vector3(dir.x, 0, dir.y)

	if direction.length() > 0:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		update_animations(direction)
	else:
		velocity.x = 0
		velocity.z = 0
		sprite.stop()

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

func start_scripted_walk(direction: Vector3, duration: float) -> void:
	is_scripted_moving = true
	scripted_direction = direction
	update_animations(direction)
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func():
		is_scripted_moving = false
		velocity.x = 0
		velocity.z = 0
		sprite.stop()
	)

func update_debug_label() -> void:
	if debug_label:
		debug_label.text = "Arrow: " + str(GameState.player.arrows) \
			+ "\nBombs: " + str(GameState.inventory.bombs) \
			+ "\nSmoke Bombs: " + str(GameState.inventory.smoke_bombs) \
			+ "\nPotions: " + str(GameState.inventory.potions)

func update_animations(dir: Vector3) -> void:
	if abs(dir.x) > abs(dir.z):
		current_facing = FacingDirection.RIGHT if dir.x > 0 else FacingDirection.LEFT
	else:
		current_facing = FacingDirection.BACKWARD if dir.z > 0 else FacingDirection.FORWARD

	match current_facing:
		FacingDirection.FORWARD:
			sprite.play("move_forward")
		FacingDirection.BACKWARD:
			sprite.play("move_down")
		FacingDirection.LEFT:
			sprite.play("move_left")
		FacingDirection.RIGHT:
			sprite.play("move_right")
