extends Node

enum State{
	MENU,
	PAUSED,
	EXPLORING,
	FIGHTING,
}

var player := {
	"health": 100,
	"max_health": 100,
	"arrows": 3,
}

var inventory := {
	"potions": 2,
	"bombs": 1,
	"smoke_bombs": 1,
}

var state:State = State.MENU
var prev_state = state

func set_state(new_state: State) -> void:
	if new_state == state:
		return

	prev_state = state
	state = new_state
