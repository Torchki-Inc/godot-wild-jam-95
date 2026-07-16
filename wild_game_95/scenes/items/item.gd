class_name Item
extends Node3D

enum ItemType {
	POTION,
	SMOKE,
	BOMB,
	ARROW,
	KEY,
}

@export var ITEM_TYPE: ItemType
@export var sprite: Texture2D = preload("res://icon.svg")
@export var key_id: String = ""

@export var item_name: String = ""

var in_pickup_area: bool = false

func _ready() -> void:
	if sprite != null:
		$Sprite3D.texture = sprite

	if item_name == "":
		_set_name()



func _process(delta: float) -> void:
	if Input.is_action_just_pressed("interact") && in_pickup_area:
		on_pickup()


func on_pickup() -> void:
	match ITEM_TYPE:
		ItemType.POTION:
			GameState.inventory.potions += 1
		ItemType.SMOKE:
			GameState.inventory.smoke_bombs += 1
		ItemType.BOMB:
			GameState.inventory.bombs += 1
		ItemType.ARROW:
			GameState.player.arrows += 1
		ItemType.KEY:
			GameState.add_key(key_id)
	MessageManager.show_message("item_pickup", {"item": item_name} )
	queue_free()

func _set_name() -> void:
	var names := {
		ItemType.POTION: "Potion",
		ItemType.SMOKE: "Smoke Bomb",
		ItemType.BOMB: "Bomb",
		ItemType.ARROW: "Arrow",
		ItemType.KEY: "Key",
	}

	item_name = names.get(ITEM_TYPE, "Unknown")

func _on_area_3d_area_exited(area: Area3D) -> void:
	in_pickup_area = false


func _on_area_3d_area_entered(area: Area3D) -> void:
	in_pickup_area = true
