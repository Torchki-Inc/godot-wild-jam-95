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


func _physics_process(delta: float) -> void:
	RenderingServer.global_shader_parameter_set("player_position", global_position)

	update_debug_label()

	# var input_dir := Vector2.ZERO
	# input_dir = Input.get_vector(
	# 	"move_left",
	# 	"move_right",
	# 	"move_up",
	# 	"move_down",
	# )
	var dir := Vector2.ZERO

	if Input.is_action_pressed("move_left"):
		dir = Vector2.LEFT
	elif Input.is_action_pressed("move_right"):
		dir = Vector2.RIGHT
	elif Input.is_action_pressed("move_up"):
		dir = Vector2.UP
	elif Input.is_action_pressed("move_down"):
		dir = Vector2.DOWN
	var direction := Vector3(dir.x, 0, dir.y)

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
