extends Node

@export var test_encounter: EncounterData

@export var starting_level: PackedScene
@export var fight_scene: PackedScene
@export var player_scene: PackedScene

@onready var entity_root: Node = $EntityRoot
@onready var level_root: Node3D = $LevelRoot
@onready var fight_root: Node = $FightRoot

@export_category("Cutscenes")
@export var test_cutscene: CutsceneData

@onready var cutscene_player: CutscenePlayer = $UI/CutscenePlayer

var current_level: Node
var player: Node
var current_fight: Node

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if GameState.state == GameState.State.EXPLORING:
			enter_fight(test_encounter)

	if event.is_action_pressed("ui_undo"):
		if test_cutscene != null:
			await play_cutscene(test_cutscene)

func _ready() -> void:
	# process_mode = Node.PROCESS_MODE_ALWAYS

	spawn_player()
	load_level(starting_level)
	add_to_group("main_game")

	GameState.set_state(GameState.State.EXPLORING)



func load_level(
	level: PackedScene,
	spawn_point_name: StringName = &"PlayerSpawn"
) -> void:
	if level == null:
		push_error("Tried to load a null level.")
		return

	if current_level != null:
		current_level.queue_free()
		current_level = null

		await get_tree().process_frame

	current_level = level.instantiate()
	level_root.add_child(current_level)

	move_player_to_spawn(spawn_point_name)


func change_level(
	level: PackedScene,
	spawn_point_name: StringName = &"PlayerSpawn"
) -> void:
	await load_level(level, spawn_point_name)


func spawn_player() -> void:
	if player_scene == null:
		push_error("No player_scene assigned in main_game.gd")
		return

	player = player_scene.instantiate()
	entity_root.add_child(player)


func move_player_to_spawn(spawn_point_name: StringName) -> void:
	if player == null or current_level == null:
		return

	var spawn_point := current_level.find_child(
		str(spawn_point_name),
		true,
		false
	) as Node3D

	if spawn_point == null:
		push_warning(
			'Level has no spawn point named "%s".' % spawn_point_name
		)
		return

	if player is Node3D:
		player.global_transform = spawn_point.global_transform

func enter_fight(encounter_data: EncounterData) -> void:
	if current_fight != null:
		push_warning("A fight is already active.")
		return

	if fight_scene == null:
		push_error("No fight_scene assigned.")
		return

	GameState.set_state(GameState.State.FIGHTING)

	get_tree().paused = true

	current_fight = fight_scene.instantiate()
	current_fight.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	if current_fight.has_method("setup"):
		current_fight.setup(encounter_data)

	fight_root.add_child(current_fight)

	if current_fight.has_signal("fight_finished"):
		current_fight.fight_finished.connect(_on_fight_finished)
	else:
		push_warning("Fight scene has no fight_finished signal.")


func _on_fight_finished(result = null) -> void:
	if current_fight != null:
		current_fight.queue_free()
		current_fight = null

	GameState.set_state(GameState.State.EXPLORING)
	get_tree().paused = false

	handle_fight_result(result)


func handle_fight_result(result) -> void:
	if result == null:
		return

	print("Fight result: ", result)

func play_cutscene(data: CutsceneData) -> void:
	if data == null:
		push_warning("Tried to play a null cutscene.")
		return

	GameState.set_state(GameState.State.CUTSCENE)

	cutscene_player.play(data)
	await cutscene_player.finished

	GameState.set_state(GameState.State.EXPLORING)
