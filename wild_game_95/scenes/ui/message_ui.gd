extends CanvasLayer

@onready var panel: PanelContainer = $PanelContainer
@onready var label: RichTextLabel = $PanelContainer/MarginContainer/RichTextLabel
# @onready var arrow: TextureRect = $PanelContainer/Arrow

var full_text: String = ""
var typing: bool = false

var previous_tree_paused := false
var dialogue_session_active := false
var owns_pause := false

@export_group("Audio")
@export var typing_sounds: Array[AudioStream] = []
@export var sound_every_n_chars: int = 2

func _ready() -> void:
	process_mode = ProcessMode.PROCESS_MODE_WHEN_PAUSED

	panel.modulate.a = 0.0

	MessageManager.message_displayed.connect(_on_message_shown)
	MessageManager.queue_finished.connect(_on_queue_finished)
# 	arrow.visible = !typing

# func _process(delta: float) -> void:
# 	if typing:
# 		arrow.visible = false
# 		return
# 	arrow.visible = int(Time.get_ticks_msec() / 400.0) % 2 == 0

func _on_message_shown(text: String) -> void:
	if not dialogue_session_active:
		previous_tree_paused = get_tree().paused
		dialogue_session_active = true

	full_text = text
	label.text = ""
	panel.modulate.a = 0.0

	get_tree().paused = true

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)

	await tween.finished

	typing = true
	type_text()

func type_text() -> void:
	label.text = full_text
	label.visible_characters = 0
	for i in full_text.length():
		if !typing:
			break
		label.visible_characters = i + 1

		if not typing_sounds.is_empty() and i % sound_every_n_chars == 0:
			var ch := full_text[i]
			if ch != " " and ch != "\n":
				var sound := typing_sounds[randi() % typing_sounds.size()]
				AudioManager.play_sfx_random_pitch(sound, 0.85, 1.15, -8.0)

		await get_tree().create_timer(0.025, true).timeout
	label.visible_characters = full_text.length()
	typing = false

func _unhandled_input(event: InputEvent) -> void:
	if !get_tree().paused:
		return

	if event.is_action_pressed("interact"):
		if typing:
			typing = false
			label.visible_characters = full_text.length()
		else:
			close_message()


func close_message() -> void:
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)

	await tween.finished

	MessageManager.process_message()

func _on_queue_finished() -> void:
	if not dialogue_session_active:
		return

	dialogue_session_active = false
	get_tree().paused = previous_tree_paused
