extends Node

const SETTINGS_PATH := "user://settings.cfg"

const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 1.0
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_FULLSCREEN := false

var master_volume := DEFAULT_MASTER_VOLUME
var music_volume := DEFAULT_MUSIC_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var fullscreen := DEFAULT_FULLSCREEN


func _ready() -> void:
	load_settings()
	apply_settings()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_master_volume(master_volume)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_music_volume(music_volume)

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_sfx_volume(sfx_volume)

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled

	if fullscreen:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN
		)
	else:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED
		)

func apply_settings() -> void:
	set_master_volume(master_volume)
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)
	set_fullscreen(fullscreen)

func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value(
		"audio",
		"master_volume",
		master_volume
	)
	config.set_value(
		"audio",
		"music_volume",
		music_volume
	)
	config.set_value(
		"audio",
		"sfx_volume",
		sfx_volume
	)
	config.set_value(
		"display",
		"fullscreen",
		fullscreen
	)

	var error := config.save(SETTINGS_PATH)

	if error != OK:
		push_error(
			"Could not save settings. Error: %s" % error
		)

func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)

	if error != OK:
		return

	master_volume = float(
		config.get_value(
			"audio",
			"master_volume",
			DEFAULT_MASTER_VOLUME
		)
	)

	music_volume = float(
		config.get_value(
			"audio",
			"music_volume",
			DEFAULT_MUSIC_VOLUME
		)
	)

	sfx_volume = float(
		config.get_value(
			"audio",
			"sfx_volume",
			DEFAULT_SFX_VOLUME
		)
	)

	fullscreen = bool(
		config.get_value(
			"display",
			"fullscreen",
			DEFAULT_FULLSCREEN
		)
	)

func reset_to_defaults() -> void:
	master_volume = DEFAULT_MASTER_VOLUME
	music_volume = DEFAULT_MUSIC_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	fullscreen = DEFAULT_FULLSCREEN

	apply_settings()
	save_settings()
