extends Node
class_name BattleRuntime

const TerrainArt = preload("res://tiles/terrain_art.gd")

const Roster = preload("res://units/unit_roster.gd")

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
	# Opening a map directly uses the same class definitions as the roster menu.
	if player_unit_definitions.is_empty():
		var ally_classes := [0, 3, 2, 4]
		for index in range(maxi(0, player_unit_count)):
			player_unit_definitions.append(Roster.create(ally_classes[index % ally_classes.size()], false))

	if enemy_unit_definitions.is_empty():
		var enemy_classes := [1, 6, 5, 2]
		for index in range(maxi(0, enemy_unit_count)):
			enemy_unit_definitions.append(Roster.create(enemy_classes[index % enemy_classes.size()], true))


func _ready() -> void:
	var board := get_parent().get_node_or_null("Board") as Board
	if board != null:
		# The authored TileMaps remain the source for movement and terrain rules.
		for layer_path in ["DepthSort/BackLayer", "DepthSort/FrontLayer", "TreeLayer"]:
			var old_art := get_parent().get_node_or_null(layer_path) as TileMapLayer
			if old_art != null:
				old_art.hide()
		var terrain := TerrainArt.new()
		terrain.name = "TerrainArt"
		terrain.board = board
		terrain.z_index = -1
		# Hide only the board's own tiles. Its unit children keep their colors.
		board.self_modulate.a = 0.0
		board.add_child(terrain)
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
