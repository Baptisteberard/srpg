extends SceneTree

# Run with:
# godot --headless --path . --script res://tests/run_tests.gd

var failures: Array[String] = []
var checks_run: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_fe8_map_sprite_import()
	await _test_battle_scene("res://game.tscn", 1, 1)
	await _test_battle_scene("res://game_map2.tscn", 2, 2)
	await _test_reachable_cells()
	_test_combat_basics()
	await _test_hp_damage_effects()

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
	var manager: TurnManager = battle.find_child("TurnManager", true, false) as TurnManager
	var hud := battle.find_child("UI", true, false) as BattleHud
	var unit_info_panel := battle.find_child("UnitStatsPanel", true, false) as PanelContainer
	var unit_info_tabs := battle.find_child("UnitInfoTabs", true, false) as TabContainer
	var equipment_label := battle.find_child("EquipmentLabel", true, false) as RichTextLabel
	var skills_label := battle.find_child("SkillsLabel", true, false) as RichTextLabel
	var settings_toggle := battle.find_child("UnitVisualSettingsToggle", true, false) as Button
	var settings_panel := battle.find_child("UnitVisualSettingsPanel", true, false) as PanelContainer
	var size_slider := battle.find_child("UnitSizeSlider", true, false) as HSlider
	var offset_slider := battle.find_child("UnitVerticalOffsetSlider", true, false) as HSlider
	var animation_speed_slider := battle.find_child("UnitAnimationSpeedSlider", true, false) as HSlider
	var movement_speed_slider := battle.find_child("UnitMovementSpeedSlider", true, false) as HSlider
	_expect(board != null and not board.get_used_cells().is_empty(), "%s has a populated board" % scene_path)
	_expect(manager != null, "%s has a TurnManager" % scene_path)
	if manager != null:
		_expect(manager.player_units.size() == expected_players, "%s spawns %d player units" % [scene_path, expected_players])
		_expect(manager.enemy_units.size() == expected_enemies, "%s spawns %d enemy units" % [scene_path, expected_enemies])
		if FE8MapSpriteImporter.source_available():
			var animated_units: Array[Unit] = manager.player_units.duplicate()
			animated_units.append_array(manager.enemy_units)
			var all_use_fe8_visuals := true
			for unit in animated_units:
				if not unit.has_fe8_map_sprite_animation():
					all_use_fe8_visuals = false
					break
			_expect(all_use_fe8_visuals, "%s uses FE8 map-sprite animations for every unit" % scene_path)

	var unit_tabs_work := false
	if manager != null \
	and hud != null \
	and unit_info_panel != null \
	and unit_info_tabs != null \
	and equipment_label != null \
	and skills_label != null \
	and not manager.player_units.is_empty():
		hud.focus_unit(manager.player_units[0])
		await process_frame
		unit_tabs_work = unit_info_panel.visible \
			and unit_info_tabs.get_tab_count() == 3 \
			and unit_info_tabs.get_tab_title(0) == "Characteristics" \
			and unit_info_tabs.get_tab_title(1) == "Equipment" \
			and unit_info_tabs.get_tab_title(2) == "Skills" \
			and not equipment_label.text.is_empty() \
			and not skills_label.text.is_empty()
	_expect(unit_tabs_work, "%s shows one unit window with three information tabs" % scene_path)

	var visual_settings_work := false
	if manager != null \
	and settings_toggle != null \
	and settings_panel != null \
	and size_slider != null \
	and offset_slider != null \
	and animation_speed_slider != null \
	and movement_speed_slider != null:
		var defaults_work := is_equal_approx(manager.unit_visual_size_multiplier, 0.75) \
			and is_equal_approx(manager.unit_visual_vertical_offset, -24.0) \
			and is_equal_approx(manager.unit_animation_speed_multiplier, 1.0) \
			and is_equal_approx(manager.unit_movement_speed_multiplier, 1.0) \
			and is_equal_approx(manager.get_move_step_time(), 0.12)
		var menu_starts_closed := not settings_panel.visible
		settings_toggle.button_pressed = true
		await process_frame
		var menu_opens := settings_panel.visible
		settings_toggle.button_pressed = false
		await process_frame
		var menu_closes := not settings_panel.visible
		size_slider.value = 1.25
		offset_slider.value = -12.0
		animation_speed_slider.value = 1.5
		movement_speed_slider.value = 0.5
		await process_frame
		var all_units: Array[Unit] = manager.player_units.duplicate()
		all_units.append_array(manager.enemy_units)
		visual_settings_work = defaults_work \
			and menu_starts_closed \
			and menu_opens \
			and menu_closes \
			and not all_units.is_empty()
		for unit in all_units:
			if not is_equal_approx(unit.visual_size_multiplier, 1.25) \
			or not is_equal_approx(unit._get_sprite().position.y, -12.0) \
			or not is_equal_approx(unit.animation_speed_multiplier, 1.5) \
			or not is_equal_approx(unit._get_sprite().speed_scale, 1.5):
				visual_settings_work = false
				break
		visual_settings_work = visual_settings_work \
			and is_equal_approx(manager.unit_movement_speed_multiplier, 0.5) \
			and is_equal_approx(manager.get_move_step_time(), 0.24)
	_expect(
		settings_toggle != null \
		and settings_panel != null \
		and size_slider != null \
		and offset_slider != null \
		and animation_speed_slider != null \
		and movement_speed_slider != null \
		and visual_settings_work,
		"%s has working unit display, animation-speed, and movement-speed controls" % scene_path
	)

	battle.queue_free()
	await process_frame


func _test_fe8_map_sprite_import() -> void:
	if not FE8MapSpriteImporter.source_available():
		_expect(
			FE8MapSpriteImporter.load_animation("Recruit", "ally") == null,
			"Missing local FE8 art cleanly preserves the fallback visuals"
		)
		return

	var recruit := FE8MapSpriteImporter.load_animation("Recruit", "ally")
	var brigand := FE8MapSpriteImporter.load_animation("Brigand", "enemy")
	_expect(
		recruit != null and brigand != null and recruit.is_valid() and brigand.is_valid(),
		"The local FE8 sheet imports Recruit and enemy-palette Brigand animations"
	)
	if recruit == null or brigand == null:
		return
	_expect(
		recruit.sprite_frames.get_frame_count(FE8MapSpriteAnimation.IDLE_PRIMARY) == 3 \
		and recruit.sprite_frames.get_frame_count(FE8MapSpriteAnimation.IDLE_SECONDARY) == 3 \
		and recruit.sprite_frames.get_frame_count(FE8MapSpriteAnimation.WALK_LEFT) == 4 \
		and recruit.sprite_frames.get_frame_count(FE8MapSpriteAnimation.WALK_RIGHT) == 4 \
		and recruit.sprite_frames.get_frame_count(FE8MapSpriteAnimation.WALK_DOWN) == 4 \
		and recruit.sprite_frames.get_frame_count(FE8MapSpriteAnimation.WALK_UP) == 4 \
		and brigand.sprite_frames.has_animation(FE8MapSpriteAnimation.WALK_LEFT) \
		and FE8MapSpriteImporter.MOVEMENT_SOURCE_ROW_OFFSETS == [0, 1, 2, -1],
		"FE8 idles have three frames and movement reads its fourth frame above"
	)
	var brigand_image := brigand.compact_texture.get_image()
	var contains_enemy_red := false
	for y in range(brigand_image.get_height()):
		for x in range(brigand_image.get_width()):
			if brigand_image.get_pixel(x, y).is_equal_approx(Color8(224, 16, 16)):
				contains_enemy_red = true
				break
		if contains_enemy_red:
			break
	_expect(
		brigand.faction_palette == "enemy" \
		and brigand_image.get_used_rect().has_area() \
		and is_zero_approx(brigand_image.get_pixel(0, 0).a) \
		and contains_enemy_red,
		"FE8 enemy palette conversion produces red sprites with transparent backgrounds"
	)


func _test_reachable_cells() -> void:
	var packed: PackedScene = load("res://game.tscn") as PackedScene
	if packed == null:
		_expect(false, "Map 1 is available for movement checks")
		return

	var battle: Node = packed.instantiate()
	root.add_child(battle)
	await process_frame

	var manager: TurnManager = battle.find_child("TurnManager", true, false) as TurnManager
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

	var one_step_destination: Vector2i = mover.cell
	for value in destinations:
		var candidate: Vector2i = value
		if int(distances[candidate]) == 1:
			one_step_destination = candidate
			break
	var origin: Vector2i = mover.cell
	_expect(one_step_destination != origin, "A starting player has a one-step destination")
	if one_step_destination != origin:
		var one_step_path: Array[Vector2i] = [one_step_destination]
		await manager._move_unit(mover, one_step_path)
		_expect(
			mover.cell == one_step_destination \
			and manager.occ.get(one_step_destination) == mover \
			and not manager.occ.has(origin),
			"Awaited movement updates the unit and occupancy atomically"
		)

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
	var forecast: Dictionary = CombatResolver.forecast(attacker, defender, attacker.cell)
	_expect(
		not bool(forecast["attacker_strikes_first"]) \
		and int(forecast["attacker_hp_after"]) == 12 \
		and int(forecast["defender_hp_after"]) == 8,
		"Combat forecast follows initiative and includes counterattack damage"
	)
	var damage: int = defender.take_damage(attacker.get_physical_damage())
	_expect(damage == 12 and defender.current_hp == 8, "A successful strike applies physical damage")

	attacker.free()
	defender.free()


func _test_hp_damage_effects() -> void:
	var overlay: UnitHpOverlay = UnitHpOverlay.new()
	root.add_child(overlay)
	var packed: PackedScene = load("res://unit.tscn") as PackedScene
	var unit: Unit = packed.instantiate() as Unit
	unit.set_stats(20, 5, 5, 100, 0, 0)
	root.add_child(unit)
	await process_frame

	unit.take_damage(5)
	_expect(overlay._damage_trails.has(unit), "Taking damage starts a delayed white HP trail")
	unit.take_damage(15)
	_expect(not overlay._death_effects.is_empty(), "Lethal damage preserves a fading death-bar effect")
	await unit.play_death_fade(0.01)
	_expect(
		is_zero_approx(unit.modulate.a) and not unit.input_pickable,
		"A defeated unit fades out and stops accepting input before removal"
	)

	unit.queue_free()
	overlay.queue_free()
	await process_frame


func _expect(condition: bool, description: String) -> void:
	checks_run += 1
	if not condition:
		failures.append(description)
