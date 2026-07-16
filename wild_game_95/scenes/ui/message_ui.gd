extends CanvasLayer

@onready var panel: PanelContainer = $PanelContainer
@onready var label: RichTextLabel = $PanelContainer/MarginContainer/RichTextLabel

var full_text: String = ""
var typing: bool = false

func _ready() -> void:
	process_mode = ProcessMode.PROCESS_MODE_WHEN_PAUSED

	panel.modulate.a = 0.0
	MessageManager.message_displayed.connect(_on_message_shown)

func _on_message_shown(text: String) -> void:
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

	for i in full_text.length():
		if !typing:
			break
		label.text = full_text.substr(0, i + 1)

		await get_tree().create_timer(0.025, true).timeout

	label.text = full_text
	typing = false

func _unhandled_input(event: InputEvent) -> void:
	if !get_tree().paused:
		return

	if event.is_action_pressed("interact"):
		if typing:

			typing = false
			label.text = full_text
		else:
			close_message()


func close_message() -> void:
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)

	await tween.finished

	MessageManager.process_message()
