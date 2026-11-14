extends Node2D
class_name Main

@export var map1_scene: PackedScene
@export var map2_scene: PackedScene

@onready var game_root: Node = $GameRoot
@onready var menu: CanvasLayer = $Menu
@onready var map1_button: Button = $Menu/Panel/VBox/Map1Button
@onready var map2_button: Button = $Menu/Panel/VBox/Map2Button

func _ready() -> void:
	map1_button.pressed.connect(func() -> void:
		_start_map(map1_scene)
	)
	map2_button.pressed.connect(func() -> void:
		_start_map(map2_scene)
	)

func _start_map(scene: PackedScene) -> void:
	if scene == null:
		push_error("Main: requested map scene is null.")
		return

	for child in game_root.get_children():
		child.queue_free()

	var game: Node = scene.instantiate()
	game_root.add_child(game)
	menu.visible = false
