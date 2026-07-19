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

@export_category("Music")
@export var prologue_music: AudioStream
@export var exploration_music: AudioStream
@export var combat_music: AudioStream
@export var boss_approach_music: AudioStream
@export var boss_music: AudioStream
@export var credits_music: AudioStream

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
	AudioManager.play_music(exploration_music)



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
	level_root.visible = false

	current_fight = fight_scene.instantiate()
	current_fight.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	if current_fight.has_method("setup"):
		current_fight.setup(encounter_data)

	fight_root.add_child(current_fight)

	switch_to_cutscene_camera("camera_player")
	AudioManager.play_music(combat_music, 0.8)

	if current_fight.has_signal("fight_finished"):
		current_fight.fight_finished.connect(_on_fight_finished)
	else:
		push_warning("Fight scene has no fight_finished signal.")


func _on_fight_finished(result = null) -> void:
	if current_fight != null:
		current_fight.queue_free()
		current_fight = null

	GameState.set_state(GameState.State.EXPLORING)
	level_root.visible = true
	get_tree().paused = false

	switch_to_cutscene_camera("camera_fight")
	AudioManager.play_music(exploration_music, 1.2)

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

func switch_to_cutscene_camera(exclude_group: StringName) -> void:
	var cam := find_camera_excluding_group(exclude_group)
	if cam == null:
		push_error("No non-player camera found.")
		return
	cam.current = true

func find_camera_excluding_group(exclude_group: StringName) -> Camera3D:
	for cam in get_tree().get_nodes_in_group("cameras"):
		if cam is Camera3D and not cam.is_in_group(exclude_group):
			return cam
	return null
