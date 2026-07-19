extends Control

signal closed

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider

@onready var master_value: Label = %MasterValue
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SFXValue

@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var back_button: TextureButton = %BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_load_controls_from_settings()

	master_slider.value_changed.connect(
		_on_master_slider_value_changed
	)
	music_slider.value_changed.connect(
		_on_music_slider_value_changed
	)
	sfx_slider.value_changed.connect(
		_on_sfx_slider_value_changed
	)

	fullscreen_check.toggled.connect(
		_on_fullscreen_check_toggled
	)

	%ResetButton.pressed.connect(
		_on_reset_button_pressed
	)

	back_button.pressed.connect(
		_on_back_button_pressed
	)

	back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	show()
	_load_controls_from_settings()
	back_button.grab_focus()


func close() -> void:
	SettingsManager.save_settings()
	hide()
	closed.emit()


func _load_controls_from_settings() -> void:
	master_slider.set_value_no_signal(
		SettingsManager.master_volume * 100.0
	)
	music_slider.set_value_no_signal(
		SettingsManager.music_volume * 100.0
	)
	sfx_slider.set_value_no_signal(
		SettingsManager.sfx_volume * 100.0
	)

	fullscreen_check.set_pressed_no_signal(
		SettingsManager.fullscreen
	)

	_update_volume_labels()


func _update_volume_labels() -> void:
	master_value.text = "%d%%" % roundi(master_slider.value)
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)


func _on_master_slider_value_changed(value: float) -> void:
	SettingsManager.set_master_volume(value / 100.0)
	SettingsManager.save_settings()
	master_value.text = "%d%%" % roundi(value)


func _on_music_slider_value_changed(value: float) -> void:
	SettingsManager.set_music_volume(value / 100.0)
	SettingsManager.save_settings()
	music_value.text = "%d%%" % roundi(value)


func _on_sfx_slider_value_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value / 100.0)
	SettingsManager.save_settings()
	sfx_value.text = "%d%%" % roundi(value)


func _on_fullscreen_check_toggled(enabled: bool) -> void:
	SettingsManager.set_fullscreen(enabled)


func _on_reset_button_pressed() -> void:
	SettingsManager.reset_to_defaults()
	_load_controls_from_settings()


func _on_back_button_pressed() -> void:
	close()
