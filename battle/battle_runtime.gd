extends Node
class_name BattleRuntime

@export var player_unit_count: int = 1
@export var enemy_unit_count: int = 1
@export var default_unit_definition: UnitStats
@export var player_unit_definitions: Array[UnitStats] = []
@export var enemy_unit_definitions: Array[UnitStats] = []


func _enter_tree() -> void:
	# Parent _enter_tree runs before the manager's _ready, so encounter data is
	# in place before units are spawned.
	var manager: TurnManager = get_node_or_null("TurnManager") as TurnManager
	if manager == null:
		push_error("BattleRuntime: shared TurnManager child is missing.")
		return
	manager.player_unit_count = maxi(0, player_unit_count)
	manager.enemy_unit_count = maxi(0, enemy_unit_count)
	manager.default_unit_definition = default_unit_definition
	manager.player_unit_definitions = player_unit_definitions
	manager.enemy_unit_definitions = enemy_unit_definitions
