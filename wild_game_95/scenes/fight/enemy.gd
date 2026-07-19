class_name Enemy
extends CharacterBody3D

@export var encounter_data: EncounterData
@export var sprite: Texture2D

@export_group("Movement")
@export var move_speed: float = 2.0
@export var wander_radius: float = 5.0
@export var wander_pause_min: float = 1.0
@export var wander_pause_max: float = 3.0
@export var wander_move_min: float = 1.0
@export var wander_move_max: float = 3.0

var home_position: Vector3
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
	_wait_then_pick_new_direction()
	if sprite:
		$Sprite3D.texture = sprite

func _physics_process(delta: float) -> void:
	if is_waiting or current_direction == Vector3.ZERO:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	var next_position := global_position + current_direction * move_speed * delta
	if not _is_inside_radius(next_position):
		_stop_and_wait()
		return

	velocity.x = current_direction.x * move_speed
	velocity.z = current_direction.z * move_speed
	move_and_slide()

	# врезался в стену/препятствие - не толкаться, а сразу перевыбрать направление
	if get_slide_collision_count() > 0:
		_stop_and_wait()

func _is_inside_radius(pos: Vector3) -> bool:
	var offset := pos - home_position
	return offset.x * offset.x + offset.z * offset.z <= wander_radius * wander_radius

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
	if current_direction != Vector3.ZERO:
		var move_duration := randf_range(wander_move_min, wander_move_max)
		get_tree().create_timer(move_duration).timeout.connect(_stop_and_wait, CONNECT_ONE_SHOT)

func _pick_new_direction() -> void:
	var shuffled := CARDINAL_DIRECTIONS.duplicate()
	shuffled.shuffle()
	for dir in shuffled:
		if _is_inside_radius(global_position + dir * move_speed * 0.5):
			current_direction = dir
			return
	current_direction = Vector3.ZERO


func _trigger_battle() -> void:
	set_physics_process(false)
	var main_game := get_tree().get_first_node_in_group("main_game")
	if main_game == null:
		push_error("main_game not found")
		return
	main_game.enter_fight(encounter_data)
	if main_game.current_fight and main_game.current_fight.has_signal("fight_finished"):
		main_game.current_fight.fight_finished.connect(_on_fight_finished)

func _on_fight_finished(result = null) -> void:
	var victory := false
	if result is Dictionary:
		victory = result.get("victory", false) # проверь актуальный ключ!
	elif result is bool:
		victory = result

	if victory:
		queue_free()
	else:
		set_physics_process(true)
		_wait_then_pick_new_direction()


func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("Player"):
		_trigger_battle()
