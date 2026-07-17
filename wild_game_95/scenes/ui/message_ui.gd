extends CanvasLayer

@onready var panel: PanelContainer = $PanelContainer
@onready var label: RichTextLabel = $PanelContainer/MarginContainer/RichTextLabel
# @onready var arrow: TextureRect = $PanelContainer/Arrow

var full_text: String = ""
var typing: bool = false

func _ready() -> void:
	process_mode = ProcessMode.PROCESS_MODE_WHEN_PAUSED

	panel.modulate.a = 0.0
	MessageManager.message_displayed.connect(_on_message_shown)
# 	arrow.visible = !typing

# func _process(delta: float) -> void:
# 	if typing:
# 		arrow.visible = false
# 		return
# 	arrow.visible = int(Time.get_ticks_msec() / 400.0) % 2 == 0

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
	label.text = full_text        # весь текст сразу, целиком — переносы посчитаны один раз
	label.visible_characters = 0  # но видно 0 символов
	for i in full_text.length():
		if !typing:
			break
		label.visible_characters = i + 1
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
