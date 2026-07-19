class_name Enemy
extends CharacterBody3D

@export_group("Moving")
@export var move_speed: float = 2.0
@export var wander_pause_min: float = 1.0
@export var wander_pause_max: float = 3.0
@export var wander_move_min: float = 1.0
@export var wander_move_max: float = 3.0
@export var movement_zone: Area3D  # опционально, fallback на wander_radius
@export var wander_radius: float = 5.0

@export_group("Fight")
@export var encounter_data: EncounterData

var home_position: Vector3
var zone_min: Vector3
var zone_max: Vector3
var current_direction: Vector3 = Vector3.ZERO
var is_waiting: bool = false




const CARDINAL_DIRECTIONS := [
	Vector3.LEFT,
	Vector3.RIGHT,
	Vector3.FORWARD,
	Vector3.BACK,
]

func _ready() -> void:
	home_position = global_position
	_setup_zone_bounds()
	_wait_then_pick_new_direction()

func _setup_zone_bounds() -> void:
	if movement_zone:
		var shape_node := movement_zone.get_node("CollisionShape3D") as CollisionShape3D
		var box := shape_node.shape as BoxShape3D
		var half := box.size * 0.5
		var center := movement_zone.global_position
		zone_min = center - half
		zone_max = center + half
	else:
		zone_min = home_position - Vector3(wander_radius, 0, wander_radius)
		zone_max = home_position + Vector3(wander_radius, 0, wander_radius)

func _physics_process(delta: float) -> void:
	if is_waiting or current_direction == Vector3.ZERO:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	var next_position := global_position + current_direction * move_speed * delta
	if not _is_inside_zone(next_position):
		_stop_and_wait()
		return

	velocity.x = current_direction.x * move_speed
	velocity.z = current_direction.z * move_speed
	move_and_slide()

func _is_inside_zone(pos: Vector3) -> bool:
	return pos.x >= zone_min.x and pos.x <= zone_max.x \
		and pos.z >= zone_min.z and pos.z <= zone_max.z

func _stop_and_wait() -> void:
	current_direction = Vector3.ZERO
	velocity.x = 0
	velocity.z = 0
	_wait_then_pick_new_direction()

func _wait_then_pick_new_direction() -> void:
	is_waiting = true
	await get_tree().create_timer(randf_range(wander_pause_min, wander_pause_max)).timeout
	is_waiting = false
	_pick_new_direction()
	var move_duration := randf_range(wander_move_min, wander_move_max)
	get_tree().create_timer(move_duration).timeout.connect(_stop_and_wait, CONNECT_ONE_SHOT)

func _pick_new_direction() -> void:
	var shuffled := CARDINAL_DIRECTIONS.duplicate()
	shuffled.shuffle()
	for dir in shuffled:
		if _is_inside_zone(global_position + dir * move_speed * 0.5):
			current_direction = dir
			return
	current_direction = Vector3.ZERO

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_trigger_battle()

func _trigger_battle() -> void:
	set_physics_process(false)
	var main_game := get_tree().get_first_node_in_group("main_game")
	if main_game == null:
		push_error("main_game not found — is it in group 'main_game'?")
		return
	main_game.enter_fight(encounter_data)
