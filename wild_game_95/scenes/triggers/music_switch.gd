extends Area3D

@export var music: AudioStream
@export var crossfade_duration: float = 1.5

var already_played: bool = false

func _on_body_entered(body: Node3D) -> void:
	if not already_played:
		AudioManager.play_music(music, crossfade_duration)
		already_played = true
