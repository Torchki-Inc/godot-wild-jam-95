class_name EnemyData
extends Resource

enum Passive {
	NONE,
	DODGE,
	ACTS_FIRST,
	STEAL_ITEMS,
	DAMAGE_REDUCTION,
}

@export var display_name: String
@export var max_health: int = 20

@export var model_scene: PackedScene
@export var portrait: Texture2D

@export var passive: Passive = Passive.NONE
@export var moves: Array[EnemyMoveData] = []
