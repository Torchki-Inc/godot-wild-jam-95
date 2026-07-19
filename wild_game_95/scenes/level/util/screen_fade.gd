extends CanvasLayer

@onready var fade_rect: ColorRect = $ColorRect

func _ready() -> void:
	layer = 100  # поверх всего, включая CRT-шейдер если тот на меньшем layer
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_out(duration: float = 0.3) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = 0.3) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, duration)
	await tween.finished
