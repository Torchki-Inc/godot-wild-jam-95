class_name CutscenePlayer
extends Control

signal finished

@export_range(0.0, 2.0, 0.05)
var fade_duration := 0.25

@onready var slide_image: TextureRect = $SlideImage
@onready var fade: ColorRect = $Fade

var cutscene: CutsceneData
var slide_index := -1

var is_transitioning := false
var is_finished := false

var previous_tree_paused := false
var transition_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func play(data: CutsceneData) -> void:
	if data == null:
		push_error("CutscenePlayer.play received null CutsceneData.")
		return

	if data.slides.is_empty():
		push_warning("Cutscene contains no slides.")
		finished.emit()
		return

	cutscene = data
	slide_index = -1
	is_finished = false

	previous_tree_paused = get_tree().paused

	if cutscene.pause_game:
		get_tree().paused = true

	show()
	fade.color = Color.BLACK

	await _show_next_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_finished:
		return

	if (
		event.is_action_pressed("ui_cancel")
		and cutscene.allow_skipping
	):
		get_viewport().set_input_as_handled()
		_finish_cutscene()


func _show_next_slide() -> void:
	if is_transitioning or is_finished:
		return

	slide_index += 1

	if slide_index >= cutscene.slides.size():
		_finish_cutscene()
		return

	var slide := cutscene.slides[slide_index]

	if slide == null:
		await _show_next_slide()
		return

	await _transition_to_slide(slide)
	await _play_slide_dialogue(slide)
	await _show_next_slide()


func _transition_to_slide(slide: CutsceneSlide) -> void:
	is_transitioning = true

	_kill_transition_tween()

	transition_tween = create_tween()
	transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	transition_tween.tween_property(
		fade,
		"color:a",
		1.0,
		fade_duration
	)

	await transition_tween.finished

	slide_image.texture = slide.image
	slide_image.visible = slide.image != null

	if slide.sound_effect != null:
		AudioManager.play_sfx(slide.sound_effect)

	transition_tween = create_tween()
	transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	transition_tween.tween_property(
		fade,
		"color:a",
		0.0,
		fade_duration
	)

	await transition_tween.finished

	is_transitioning = false


func _play_slide_dialogue(slide: CutsceneSlide) -> void:
	if slide.text.strip_edges().is_empty():
		return

	MessageManager.show_custom_message(slide.text)

	await MessageManager.queue_finished


func _finish_cutscene() -> void:
	if is_finished:
		return

	is_finished = true
	_kill_transition_tween()

	MessageManager.queue.clear()
	MessageManager.is_displaying = false

	if cutscene != null and cutscene.pause_game:
		get_tree().paused = previous_tree_paused

	hide()
	finished.emit()


func _kill_transition_tween() -> void:
	if transition_tween != null and transition_tween.is_valid():
		transition_tween.kill()
