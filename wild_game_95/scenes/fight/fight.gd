extends Node3D

signal fight_finished(result)

var enemy_data

func setup(enemy) -> void:
	enemy_data = enemy

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	if enemy_data == null:
		push_error("Fight was started without enemy data.")
		return

	print("Fighting: ", enemy_data)

func win_fight() -> void:
	fight_finished.emit({
		"outcome": "victory",
		"enemy": enemy_data,
	})

func lose_fight() -> void:
	fight_finished.emit({
		"outcome": "defeat",
		"enemy": enemy_data,
	})
