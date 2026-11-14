extends SceneTree

# Run with:
# godot --headless --path . --script res://tests/run_tests.gd

var failures: Array[String] = []
var checks_run: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_battle_scene("res://game.tscn", 1, 1)
	await _test_battle_scene("res://game_map2.tscn", 2, 2)
	await _test_reachable_cells()
	_test_combat_basics()

	if failures.is_empty():
		print("PASS: %d SRPG checks" % checks_run)
		quit(0)
		return

	for failure in failures:
		push_error("FAIL: %s" % failure)
	print("FAIL: %d of %d SRPG checks failed" % [failures.size(), checks_run])
	quit(1)


func _test_battle_scene(scene_path: String, expected_players: int, expected_enemies: int) -> void:
	var packed: PackedScene = load(scene_path) as PackedScene
	_expect(packed != null, "%s loads as a PackedScene" % scene_path)
	if packed == null:
		return

	var battle: Node = packed.instantiate()
	root.add_child(battle)
	await process_frame

	var board: Board = battle.get_node_or_null("Board") as Board
	var manager: TurnManager = battle.get_node_or_null("TurnManager") as TurnManager
	_expect(board != null and not board.get_used_cells().is_empty(), "%s has a populated board" % scene_path)
	_expect(manager != null, "%s has a TurnManager" % scene_path)
	if manager != null:
		_expect(manager.player_units.size() == expected_players, "%s spawns %d player units" % [scene_path, expected_players])
		_expect(manager.enemy_units.size() == expected_enemies, "%s spawns %d enemy units" % [scene_path, expected_enemies])

	battle.queue_free()
	await process_frame


func _test_reachable_cells() -> void:
	var packed: PackedScene = load("res://game.tscn") as PackedScene
	if packed == null:
		_expect(false, "Map 1 is available for movement checks")
		return

	var battle: Node = packed.instantiate()
	root.add_child(battle)
	await process_frame

	var manager: TurnManager = battle.get_node("TurnManager") as TurnManager
	var mover: Unit = manager.player_units[0]
	var reach: Dictionary = manager._reachable_destinations_for(mover)
	var bfs: Dictionary = manager._bfs_from(mover)
	var distances: Dictionary = bfs["dist"]
	var destinations: Array = reach["dests"]

	_expect(not destinations.is_empty(), "A starting player has reachable destinations")
	var valid: bool = true
	for value in destinations:
		var cell: Vector2i = value
		if manager.occ.has(cell) or manager.board.is_blocked(cell):
			valid = false
			break
		if not distances.has(cell) or int(distances[cell]) > mover.move_range:
			valid = false
			break
	_expect(valid, "Reachable destinations are empty, walkable, and within movement range")

	battle.queue_free()
	await process_frame


func _test_combat_basics() -> void:
	var attacker: Unit = Unit.new()
	var defender: Unit = Unit.new()
	attacker.faction = Unit.Faction.PLAYER
	defender.faction = Unit.Faction.ENEMY
	attacker.set_stats(20, 12, 3, 80, 0, 0)
	defender.set_stats(20, 8, 20, 70, 0, 0)
	attacker.cell = Vector2i.ZERO
	defender.cell = Vector2i.RIGHT

	_expect(attacker.can_attack(defender), "Opposing adjacent units can attack")
	_expect(attacker.get_hit_chance_against(defender) == 60, "Hit chance uses precision minus target speed")
	var damage: int = defender.take_damage(attacker.get_physical_damage())
	_expect(damage == 12 and defender.current_hp == 8, "A successful strike applies physical damage")

	attacker.free()
	defender.free()


func _expect(condition: bool, description: String) -> void:
	checks_run += 1
	if not condition:
		failures.append(description)
