class_name BattleEnemy
extends RefCounted

var data: EnemyData
var health: int
var current_intent: EnemyMoveData
var forced_next_intent: EnemyMoveData

var dodge_bonus: float = 0.0
var temporary_dodge_bonus: float = 0.0
var temporary_dodge_turns: int = 0

var damage_bonus: int = 0
var damage_multiplier: float = 1.0
var damage_reduction: int = 0

var death_processed := false

var stolen_items := {
	"arrows": 0,
	"potions": 0,
	"bombs": 0,
	"smoke_bombs": 0,
}


func _init(enemy_data: EnemyData) -> void:
	data = enemy_data
	health = data.max_health
