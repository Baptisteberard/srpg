extends Node
class_name BattleRuntime

const UnitDefinitionScript = preload("res://units/unit_definition.gd")

@export var player_unit_count: int = 1
@export var enemy_unit_count: int = 1
@export var default_unit_definition: UnitStats
@export var player_unit_definitions: Array[UnitStats] = []
@export var enemy_unit_definitions: Array[UnitStats] = []


func _enter_tree() -> void:
	# Parent _enter_tree runs before the manager's _ready, so encounter data is
	# in place before units are spawned.
	_apply_local_fe8_prototype_definitions()
	var manager: TurnManager = get_node_or_null("TurnManager") as TurnManager
	if manager == null:
		push_error("BattleRuntime: shared TurnManager child is missing.")
		return
	manager.player_unit_count = maxi(0, player_unit_count)
	manager.enemy_unit_count = maxi(0, enemy_unit_count)
	manager.default_unit_definition = default_unit_definition
	manager.player_unit_definitions = player_unit_definitions
	manager.enemy_unit_definitions = enemy_unit_definitions


func _apply_local_fe8_prototype_definitions() -> void:
	if not FE8MapSpriteImporter.source_available():
		return

	if player_unit_definitions.is_empty():
		var recruit_animation := FE8MapSpriteImporter.load_animation("Recruit", "ally")
		if recruit_animation != null:
			var recruit_definition := _make_fe8_definition("Recruit", recruit_animation)
			for _index in range(maxi(0, player_unit_count)):
				player_unit_definitions.append(recruit_definition)

	if enemy_unit_definitions.is_empty():
		var brigand_animation := FE8MapSpriteImporter.load_animation("Brigand", "enemy")
		if brigand_animation != null:
			var brigand_definition := _make_fe8_definition("Brigand", brigand_animation)
			for _index in range(maxi(0, enemy_unit_count)):
				enemy_unit_definitions.append(brigand_definition)


func _make_fe8_definition(class_name_value: String, animation: FE8MapSpriteAnimation) -> UnitStats:
	var definition := UnitDefinitionScript.new() as UnitStats
	definition.display_name = ""
	definition.unit_class_name = class_name_value
	definition.fe8_map_sprite_animation = animation
	return definition


func _ready() -> void:
	var hud: BattleHud = get_node_or_null("UI") as BattleHud
	var hp_overlay: UnitHpOverlay = get_node_or_null("HpOverlay") as UnitHpOverlay
	var manager: TurnManager = get_node_or_null("TurnManager") as TurnManager
	if hud == null or hp_overlay == null or manager == null:
		push_error("BattleRuntime: HUD, HP overlay, or TurnManager child is missing.")
		return
	if not hud.damage_preview_changed.is_connected(hp_overlay.set_damage_previews):
		hud.damage_preview_changed.connect(hp_overlay.set_damage_previews)
	if not hud.unit_visual_settings_changed.is_connected(manager.set_unit_visual_settings):
		hud.unit_visual_settings_changed.connect(manager.set_unit_visual_settings)
	if not hud.unit_animation_settings_changed.is_connected(manager.set_unit_animation_settings):
		hud.unit_animation_settings_changed.connect(manager.set_unit_animation_settings)
	manager.set_unit_visual_settings(hud.unit_size_multiplier, hud.unit_vertical_offset)
	manager.set_unit_animation_settings(
		hud.unit_animation_speed_multiplier,
		hud.unit_movement_speed_multiplier
	)
