extends Node

const SILENT_VOLUME_DB := -80.0
const DEFAULT_CROSSFADE_DURATION := 1.0
const DEFAULT_SFX_PLAYER_COUNT := 8

var music_players: Array[AudioStreamPlayer] = []
var active_music_player_index := 0

var sfx_players: Array[AudioStreamPlayer] = []

var current_music: AudioStream
var music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_create_music_players()
	_create_sfx_players()


func _create_music_players() -> void:
	for index in 2:
		var player := AudioStreamPlayer.new()

		player.name = "MusicPlayer%d" % index
		player.bus = &"Music"
		player.volume_db = SILENT_VOLUME_DB

		add_child(player)
		music_players.append(player)


func _create_sfx_players() -> void:
	for index in DEFAULT_SFX_PLAYER_COUNT:
		var player := AudioStreamPlayer.new()

		player.name = "SFXPlayer%d" % index
		player.bus = &"SFX"

		add_child(player)
		sfx_players.append(player)

func play_music(
	stream: AudioStream,
	crossfade_duration: float = DEFAULT_CROSSFADE_DURATION,
	restart: bool = false
) -> void:
	if stream == null:
		push_warning("AudioManager.play_music received a null stream.")
		return

	if stream == current_music and not restart:
		return

	var old_player := _get_active_music_player()
	var new_player := _get_inactive_music_player()

	if music_tween != null and music_tween.is_valid():
		music_tween.kill()

	new_player.stop()
	new_player.stream = stream
	new_player.volume_db = SILENT_VOLUME_DB
	new_player.play()

	current_music = stream

	var duration := maxf(crossfade_duration, 0.0)

	if duration == 0.0:
		old_player.stop()
		old_player.volume_db = SILENT_VOLUME_DB
		new_player.volume_db = 0.0
	else:
		music_tween = create_tween()
		music_tween.set_parallel(true)

		music_tween.tween_property(
			old_player,
			"volume_db",
			SILENT_VOLUME_DB,
			duration
		)

		music_tween.tween_property(
			new_player,
			"volume_db",
			0.0,
			duration
		)

		music_tween.chain().tween_callback(
			func() -> void:
				old_player.stop()
				old_player.stream = null
				old_player.volume_db = SILENT_VOLUME_DB
		)

	active_music_player_index = 1 - active_music_player_index


func stop_music(
	fade_duration: float = DEFAULT_CROSSFADE_DURATION
) -> void:
	current_music = null

	if music_tween != null and music_tween.is_valid():
		music_tween.kill()

	var player := _get_active_music_player()
	var duration := maxf(fade_duration, 0.0)

	if duration == 0.0:
		player.stop()
		player.stream = null
		player.volume_db = SILENT_VOLUME_DB
		return

	music_tween = create_tween()
	music_tween.tween_property(
		player,
		"volume_db",
		SILENT_VOLUME_DB,
		duration
	)

	music_tween.tween_callback(
		func() -> void:
			player.stop()
			player.stream = null
	)


func _get_active_music_player() -> AudioStreamPlayer:
	return music_players[active_music_player_index]


func _get_inactive_music_player() -> AudioStreamPlayer:
	return music_players[1 - active_music_player_index]

func play_sfx(
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0
) -> AudioStreamPlayer:
	if stream == null:
		push_warning("AudioManager.play_sfx received a null stream.")
		return null

	var player := _get_available_sfx_player()

	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

	return player

func play_sfx_random_pitch(
	stream: AudioStream,
	minimum_pitch: float = 0.9,
	maximum_pitch: float = 1.1,
	volume_db: float = 0.0
) -> AudioStreamPlayer:
	var minimum := minf(minimum_pitch, maximum_pitch)
	var maximum := maxf(minimum_pitch, maximum_pitch)

	return play_sfx(
		stream,
		volume_db,
		randf_range(minimum, maximum)
	)

func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player

	return sfx_players[0]

func set_master_volume(linear_volume: float) -> void:
	_set_bus_volume(&"Master", linear_volume)


func set_music_volume(linear_volume: float) -> void:
	_set_bus_volume(&"Music", linear_volume)


func set_sfx_volume(linear_volume: float) -> void:
	_set_bus_volume(&"SFX", linear_volume)


func set_master_muted(muted: bool) -> void:
	_set_bus_muted(&"Master", muted)


func set_music_muted(muted: bool) -> void:
	_set_bus_muted(&"Music", muted)


func set_sfx_muted(muted: bool) -> void:
	_set_bus_muted(&"SFX", muted)


func _set_bus_volume(
	bus_name: StringName,
	linear_volume: float
) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)

	if bus_index == -1:
		push_error('Audio bus "%s" does not exist.' % bus_name)
		return

	var clamped_volume := clampf(linear_volume, 0.0, 1.0)
	var volume_db := SILENT_VOLUME_DB

	if clamped_volume > 0.0:
		volume_db = linear_to_db(clamped_volume)

	AudioServer.set_bus_volume_db(
		bus_index,
		volume_db
	)


func _set_bus_muted(
	bus_name: StringName,
	muted: bool
) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)

	if bus_index == -1:
		push_error('Audio bus "%s" does not exist.' % bus_name)
		return

	AudioServer.set_bus_mute(bus_index, muted)
