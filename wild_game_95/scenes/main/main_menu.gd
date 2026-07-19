extends Control

@export var game_scene: PackedScene

@onready var menu_buttons: VBoxContainer = %MenuButtons
@onready var start_button: BaseButton = %StartButton
@onready var settings_menu: Control = %SettingsMenu


func _ready() -> void:
	GameState.set_state(GameState.State.MENU)

	settings_menu.closed.connect(
		_on_settings_menu_closed
	)

	start_button.grab_focus()


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_packed(game_scene)


func _on_settings_button_pressed() -> void:
	menu_buttons.hide()
	settings_menu.open()


func _on_settings_menu_closed() -> void:
	menu_buttons.show()
	%SettingsButton.grab_focus()


func _on_quit_button_pressed() -> void:
	get_tree().quit()
