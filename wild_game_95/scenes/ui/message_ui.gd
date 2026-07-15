extends CanvasLayer

@onready var panel: PanelContainer = $PanelContainer
@onready var label: RichTextLabel = $PanelContainer/RichTextLabel

func _ready() -> void:
	panel.modulate.a = 0.0
	MessageManager.message_displayed.connect(_on_message_shown)

func _on_message_shown(text: String) -> void:
	label.text = text
	# panel.reset_size()

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(MessageManager.process_message)
