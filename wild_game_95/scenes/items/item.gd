class_name Item
extends Node3D

enum ItemType {
	POTION,
	SMOKE,
	BOMB,
	ARROW
}

@export var ITEM_TYPE: ItemType
@export var sprite: Texture2D = preload("res://icon.svg")
var in_pickup_area: bool = false

func _ready() -> void:
	if sprite != null:
		$Sprite3D.texture = sprite



func _process(delta: float) -> void:
	if Input.is_action_just_pressed("interact") && in_pickup_area:
		match ITEM_TYPE:
			ItemType.POTION:
				GameState.inventory.potions += 1
			ItemType.SMOKE:
				GameState.inventory.smoke_bombs += 1
			ItemType.BOMB:
				GameState.inventory.bombs += 1
			ItemType.ARROW:
				GameState.player.arrows += 1
		queue_free()

func _on_area_3d_area_exited(area: Area3D) -> void:
	in_pickup_area = false


func _on_area_3d_area_entered(area: Area3D) -> void:
	in_pickup_area = true
