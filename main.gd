extends Node2D
class_name Main

const Roster = preload("res://units/unit_roster.gd")

@export var map1_scene: PackedScene
@export var map2_scene: PackedScene

@onready var game_root: Node = $GameRoot
@onready var menu: CanvasLayer = $Menu
@onready var map1_button: Button = $Menu/Panel/VBox/Map1Button
@onready var map2_button: Button = $Menu/Panel/VBox/Map2Button
@onready var picker: OptionButton = $Menu/Panel/VBox/UnitPicker
@onready var details: Label = $Menu/Panel/VBox/UnitDetails
@onready var preview: AnimatedSprite2D = $Menu/Panel/VBox/SpritePreview/Sprite
var roster: Array[UnitStats] = []

func _ready() -> void:
	for index in range(Roster.ENTRIES.size()):
		var definition := Roster.create(index, false)
		roster.append(definition)
		picker.add_item(definition.unit_class_name)
	picker.select(0)
	picker.item_selected.connect(_show_unit)
	_show_unit(0)
	map1_button.pressed.connect(func() -> void:
		_start_map(map1_scene)
	)
	map2_button.pressed.connect(func() -> void:
		_start_map(map2_scene)
	)

func _show_unit(index: int) -> void:
	var unit := roster[index]
	preview.sprite_frames = unit.fe8_map_sprite_animation.sprite_frames
	preview.play(FE8MapSpriteAnimation.IDLE_PRIMARY)
	details.text = "%s • %s Attack\n%s armor\n\nStat                     Base / Growth\nHealth                   %d / %d%%\nStrength                %d / %d%%\nSpeed                    %d / %d%%\nDexterity               %d / %d%%\nIntellect                 %d / %d%%" % [
		unit.equipped_weapon.display_name, unit.equipped_weapon.weapon_type,
		unit.equipped_armor.display_name,
		unit.health, unit.health_growth_rate, unit.strength, unit.strength_growth_rate,
		unit.speed, unit.speed_growth_rate, unit.dexterity, unit.dexterity_growth_rate,
		unit.intellect, unit.intellect_growth_rate,
	]

func _start_map(scene: PackedScene) -> void:
	if scene == null:
		push_error("Main: requested map scene is null.")
		return

	for child in game_root.get_children():
		child.queue_free()

	var game: Node = scene.instantiate()
	var runtime := game.get_node("BattleRuntime") as BattleRuntime
	var chosen := picker.selected
	runtime.player_unit_definitions = [roster[chosen]]
	for slot in range(1, runtime.player_unit_count):
		runtime.player_unit_definitions.append(roster[(chosen + slot) % roster.size()])
	var enemy_choices := range(roster.size())
	enemy_choices.shuffle()
	runtime.enemy_unit_definitions = []
	for slot in range(runtime.enemy_unit_count):
		runtime.enemy_unit_definitions.append(Roster.create(enemy_choices[slot % enemy_choices.size()], true))
	game_root.add_child(game)
	menu.visible = false
