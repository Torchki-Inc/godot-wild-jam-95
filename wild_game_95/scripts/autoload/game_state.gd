extends Node

enum State{
	MENU,
	PAUSED,
	EXPLORING,
	FIGHTING,
}

var player = {
	health = 100
}

var state:State = State.MENU
var prev_state = state

func set_state(new_state: State) -> void:
	if new_state == state:
		return

	prev_state = state
	state = new_state
