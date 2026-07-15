class_name BattleAction
extends RefCounted

enum ActorType {
	PLAYER,
	ENEMY,
}

enum PlayerMove {
	NONE,

	SLASH,
	HEAVY_STRIKE,
	CROSSBOW,

	DEFEND,
	AIM,

	POTION,
	BOMB,
	SMOKE_BOMB,
}

var actor_type: ActorType
var player_move: PlayerMove = PlayerMove.NONE
var enemy_index: int = -1
var priority: int = 0
var target_index: int = -1
