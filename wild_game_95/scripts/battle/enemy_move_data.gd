class_name EnemyMoveData
extends Resource

enum Effect {
	DAMAGE,
	ACCURACY_DOWN,
	POWER_UP_NEXT_ATTACK,
	STEAL_ITEM,
	DODGE_NEXT_TURN,
	PREPARE_MOVE,
	HEAL,
	TAKE_FLIGHT,
}

@export var display_name: String
@export var effect: Effect
@export var damage: int = 0
@export var damage_bonus: int = 0
@export var damage_multiplier: float = 1.0
@export var effect_amount: float = 0.0
@export var duration_turns: int = 0
@export var follow_up_move: EnemyMoveData
