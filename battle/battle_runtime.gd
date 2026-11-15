extends Node
class_name BattleRuntime

const UnitDefinitionScript = preload("res://units/unit_definition.gd")
const EquipmentCatalogScript = preload("res://equipment/equipment_catalog.gd")
const SkillCatalogScript = preload("res://skills/skill_catalog.gd")

@export var player_unit_count: int = 1
@export var enemy_unit_count: int = 1
@export var default_unit_definition: UnitStats
@export var player_unit_definitions: Array[UnitStats] = []
@export var enemy_unit_definitions: Array[UnitStats] = []


func _enter_tree() -> void:
	# Parent _enter_tree runs before the manager's _ready, so encounter data is
	# in place before units are spawned.
	_apply_prototype_definitions()
	var manager: TurnManager = get_node_or_null("TurnManager") as TurnManager
	if manager == null:
		push_error("BattleRuntime: shared TurnManager child is missing.")
		return
	manager.player_unit_count = maxi(0, player_unit_count)
	manager.enemy_unit_count = maxi(0, enemy_unit_count)
	manager.default_unit_definition = default_unit_definition
	manager.player_unit_definitions = player_unit_definitions
	manager.enemy_unit_definitions = enemy_unit_definitions


func _apply_prototype_definitions() -> void:
	if player_unit_definitions.is_empty():
		var recruit_animation: FE8MapSpriteAnimation = null
		if FE8MapSpriteImporter.source_available():
			recruit_animation = FE8MapSpriteImporter.load_animation("Recruit", "ally")
		for index in range(maxi(0, player_unit_count)):
			player_unit_definitions.append(
				_make_prototype_definition("Recruit", recruit_animation, index)
			)

	if enemy_unit_definitions.is_empty():
		var brigand_animation: FE8MapSpriteAnimation = null
		if FE8MapSpriteImporter.source_available():
			brigand_animation = FE8MapSpriteImporter.load_animation("Brigand", "enemy")
		for index in range(maxi(0, enemy_unit_count)):
			enemy_unit_definitions.append(
				_make_prototype_definition("Brigand", brigand_animation, index)
			)


func _make_prototype_definition(
	class_name_value: String,
	animation: FE8MapSpriteAnimation,
	loadout_index: int
) -> UnitStats:
	var definition := UnitDefinitionScript.new() as UnitStats
	definition.display_name = ""
	definition.unit_class_name = class_name_value
	if class_name_value == "Recruit":
		definition.health = 20
		definition.strength = 12
		definition.speed = 8
		definition.dexterity = 80
		definition.health_growth_rate = 70
		definition.strength_growth_rate = 40
		definition.speed_growth_rate = 50
		definition.dexterity_growth_rate = 55
		definition.intellect_growth_rate = 10
		_apply_recruit_loadout(definition, loadout_index)
	elif class_name_value == "Brigand":
		definition.health = 24
		definition.strength = 14
		definition.speed = 5
		definition.dexterity = 65
		definition.health_growth_rate = 80
		definition.strength_growth_rate = 60
		definition.speed_growth_rate = 30
		definition.dexterity_growth_rate = 35
		definition.intellect_growth_rate = 5
		_apply_brigand_loadout(definition, loadout_index)
	definition.fe8_map_sprite_animation = animation
	return definition


func _apply_recruit_loadout(definition: UnitStats, loadout_index: int) -> void:
	match loadout_index % 4:
		0:
			definition.equipped_weapon = EquipmentCatalogScript.BASIC_SWORD
			definition.equipped_armor = EquipmentCatalogScript.MAIL_HAUBERK
			definition.active_skills = [SkillCatalogScript.HEAL]
		1:
			definition.equipped_weapon = EquipmentCatalogScript.LONGBOW
			definition.equipped_armor = EquipmentCatalogScript.BRIGANDINE
		2:
			definition.equipped_weapon = EquipmentCatalogScript.BASIC_SPEAR
			definition.equipped_armor = EquipmentCatalogScript.LAMELLAR_ARMOR
		_:
			definition.equipped_weapon = EquipmentCatalogScript.DAGGER
			definition.equipped_armor = EquipmentCatalogScript.PADDED_GAMBESON


func _apply_brigand_loadout(definition: UnitStats, loadout_index: int) -> void:
	match loadout_index % 4:
		0:
			definition.equipped_weapon = EquipmentCatalogScript.BASIC_AXE
			definition.equipped_armor = EquipmentCatalogScript.PADDED_GAMBESON
		1:
			definition.equipped_weapon = EquipmentCatalogScript.WAR_HAMMER
			definition.equipped_armor = EquipmentCatalogScript.STEEL_PLATE_HARNESS
		2:
			definition.equipped_weapon = EquipmentCatalogScript.MACE
			definition.equipped_armor = EquipmentCatalogScript.COAT_OF_PLATES
		_:
			definition.equipped_weapon = EquipmentCatalogScript.BASIC_SPEAR
			definition.equipped_armor = EquipmentCatalogScript.LAMELLAR_ARMOR


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
