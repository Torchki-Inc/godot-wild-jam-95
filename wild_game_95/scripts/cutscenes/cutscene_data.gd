class_name CutsceneData
extends Resource

@export var slides: Array[CutsceneSlide] = []

@export_category("Options")
@export var allow_skipping := true
@export var pause_game := true
