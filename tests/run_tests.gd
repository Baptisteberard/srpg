extends SceneTree

# Run with:
# godot --headless --path . --script res://tests/run_tests.gd

var failures: Array[String] = []
var checks_run: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_fe8_map_sprite_import()
	await _test_roster_menu()
	await _test_battle_scene("res://game.tscn", 1, 1)
	await _test_battle_scene("res://game_map2.tscn", 2, 2)
	await _test_reachable_cells()
	_test_equipment()
	_test_progression()
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


func _test_roster_menu() -> void:
	var menu_scene := (load("res://main.tscn") as PackedScene).instantiate() as Main
	root.add_child(menu_scene)
	var all_animated := menu_scene.roster.size() == 7
	for definition in menu_scene.roster:
		all_animated = all_animated and definition.fe8_map_sprite_animation.is_valid()
	_expect(all_animated, "Every selectable unit has a working animation")
	if FE8MapSpriteImporter.source_available():
		var expected_sources := ["Recruit", "Brigand", "Soldier", "Archer M", "Thief", "Fighter", "Knight"]
		var every_sprite_from_sheet := true
		for index in range(expected_sources.size()):
			var animation := menu_scene.roster[index].fe8_map_sprite_animation
			every_sprite_from_sheet = every_sprite_from_sheet and animation == FE8MapSpriteImporter.load_animation(expected_sources[index], "ally")
		_expect(every_sprite_from_sheet, "All seven roster previews use their mapped blocks from the local sheet")
	menu_scene.picker.select(3)
	menu_scene.picker.item_selected.emit(3)
	menu_scene.map2_button.pressed.emit()
	var manager := menu_scene.game_root.find_child("TurnManager", true, false) as TurnManager
	_expect(manager != null and manager.player_units.size() == 2
		and manager.player_units[0].unit_class_name == "Archer"
		and manager.enemy_units.size() == 2
		and manager.enemy_units[0].unit_class_name != manager.enemy_units[1].unit_class_name,
		"Map 2 starts with the selected unit and two distinct roster enemies")
	if manager != null:
		var archer := manager.player_units[0]
		var enemy := manager.enemy_units[0]
		var hud := manager.hud as BattleHud
		manager._select_unit(archer)
		var path: Array[Vector2i] = []
		for cell in manager.selected_reach_dests:
			path = manager._shortest_path_with_turn_bias(archer, archer.cell, cell)
			if not path.is_empty():
				break
		var attack_cell := path.back() as Vector2i if not path.is_empty() else archer.cell
		manager.occ.erase(enemy.cell)
		enemy.set_cell(attack_cell + Vector2i(2, 0), manager.board.cell_to_world(attack_cell + Vector2i(2, 0)))
		manager.occ[enemy.cell] = enemy
		archer.strength = 100
		archer.speed = 100
		archer.dexterity = 100
		enemy.current_hp = 1
		manager.combat_resolver.rng = null
		var presentation: Control = manager.combat_resolver.presentation
		var exchange = manager.combat_resolver
		manager._set_combat_preview(archer, enemy, attack_cell, path)
		manager._clear_hover_preview(true)
		hud.forecast_attack.pressed.emit()
		var deadline := Time.get_ticks_msec() + 5000
		while not presentation.visible and Time.get_ticks_msec() < deadline:
			await process_frame
		_expect(not path.is_empty() and archer.cell == attack_cell and presentation.visible,
			"The forecast Attack button executes its projected movement and starts combat")
		_expect(presentation.visible and enemy.current_hp == 1, "Battle opens before applying strike damage")
		var pack = exchange.presentation.archer_pack
		_expect(pack != null and pack.frames.size() == 31 and not pack.modes[5]["windup"].is_empty()
			and not pack.modes[6]["windup"].is_empty(),
			"Archer combat loads the fan pack and both timed attack sequences")
		while presentation.visible:
			await process_frame
		_expect(not enemy.is_alive() and not manager.enemy_units.has(enemy),
			"Lethal impact updates HP, removes the defeated unit, and closes the presentation")
		while is_instance_valid(enemy):
			await process_frame
	menu_scene.queue_free()
	await process_frame


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
	var identity_label := battle.find_child("UnitIdentityLabel", true, false) as RichTextLabel
	var unit_info_tabs := battle.find_child("UnitInfoTabs", true, false) as TabContainer
	var characteristics_label := battle.find_child("CharacteristicsLabel", true, false) as RichTextLabel
	var equipment_label := battle.find_child("EquipmentLabel", true, false) as RichTextLabel
	var skills_label := battle.find_child("SkillsLabel", true, false) as RichTextLabel
	var skill_action_button := battle.find_child("SkillActionButton", true, false) as Button
	var progression_panel := battle.find_child("ProgressionPanel", true, false) as PanelContainer
	var progression_label := battle.find_child("ProgressionLabel", true, false) as RichTextLabel
	var settings_toggle := battle.find_child("UnitVisualSettingsToggle", true, false) as Button
	var settings_panel := battle.find_child("UnitVisualSettingsPanel", true, false) as PanelContainer
	var size_slider := battle.find_child("UnitSizeSlider", true, false) as HSlider
	var offset_slider := battle.find_child("UnitVerticalOffsetSlider", true, false) as HSlider
	var animation_speed_slider := battle.find_child("UnitAnimationSpeedSlider", true, false) as HSlider
	var movement_speed_slider := battle.find_child("UnitMovementSpeedSlider", true, false) as HSlider
	_expect(board != null and not board.get_used_cells().is_empty(), "%s has a populated board" % scene_path)
	_expect(board != null and board.has_node("TerrainArt") and board.self_modulate.a == 0.0,
		"%s displays the shared pixel terrain over the authored grid" % scene_path)
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
		var equipped_units: Array[Unit] = manager.player_units.duplicate()
		equipped_units.append_array(manager.enemy_units)
		var all_have_loadouts := not equipped_units.is_empty()
		for unit in equipped_units:
			if unit.equipped_weapon == null or unit.equipped_armor == null:
				all_have_loadouts = false
				break
		_expect(all_have_loadouts, "%s equips every field unit with a weapon and armor" % scene_path)
		if expected_players > 1 and expected_enemies > 1:
			_expect(
				manager.player_units[1].equipped_weapon == EquipmentCatalog.LONGBOW \
				and manager.enemy_units[1].equipped_armor == EquipmentCatalog.STEEL_PLATE_HARNESS,
				"%s uses varied field loadouts, including a longbow and steel plate armor" % scene_path
			)

	var unit_tabs_work := false
	if manager != null \
	and hud != null \
	and unit_info_panel != null \
	and identity_label != null \
	and unit_info_tabs != null \
	and characteristics_label != null \
	and equipment_label != null \
	and skills_label != null \
	and not manager.player_units.is_empty():
		hud.focus_unit(manager.player_units[0])
		await process_frame
		var focused_unit: Unit = manager.player_units[0]
		unit_tabs_work = unit_info_panel.visible \
			and identity_label.text.contains(focused_unit.get_display_name()) \
			and identity_label.text.contains(focused_unit.get_class_display_name()) \
			and identity_label.text.contains("Level %d" % focused_unit.level) \
			and identity_label.text.contains("EXP %d/%d" % [focused_unit.experience, Unit.EXPERIENCE_PER_LEVEL]) \
			and unit_info_tabs.get_tab_count() == 3 \
			and unit_info_tabs.get_tab_title(0) == "Characteristics" \
			and unit_info_tabs.get_tab_title(1) == "Equipment" \
			and unit_info_tabs.get_tab_title(2) == "Skills" \
			and characteristics_label.text.count("Growth:") == 5 \
			and not characteristics_label.text.contains("Armor") \
			and not characteristics_label.text.contains("Damage") \
			and equipment_label.text.contains(focused_unit.equipped_weapon.display_name) \
			and equipment_label.text.contains(focused_unit.equipped_armor.display_name) \
			and skills_label.get_parsed_text().contains("Accuracy") \
			and skills_label.get_parsed_text().contains("Avoid") \
			and not skills_label.get_parsed_text().contains("Accuracy =") \
			and skills_label.text.contains('[hint="Accuracy =')
	_expect(unit_tabs_work, "%s shows one unit window with three information tabs" % scene_path)
	if unit_tabs_work:
		unit_info_tabs.current_tab = 1
		await process_frame
		await process_frame
		var equipment_size := unit_info_panel.size
		unit_info_tabs.current_tab = 0
		await process_frame
		await process_frame
		_expect(unit_info_panel.size.y < equipment_size.y,
			"%s shrinks the unit window when switching back to Characteristics" % scene_path)
	var target_odds_work := false
	if manager != null and hud != null and skills_label != null \
	and not manager.player_units.is_empty() and not manager.enemy_units.is_empty():
		var odds_attacker: Unit = manager.player_units[0]
		var odds_defender: Unit = manager.enemy_units[0]
		hud.focus_unit(odds_attacker)
		hud.show_combat_preview(odds_attacker, odds_defender, odds_defender.cell + Vector2i.RIGHT)
		var forecast_text := hud.forecast_label.get_parsed_text()
		target_odds_work = hud.forecast_panel.visible and not unit_info_panel.visible \
			and hud.forecast_cards[0]["hp"].text.contains("→") \
			and hud.forecast_cards[1]["weapon"].text == odds_defender.equipped_weapon.display_name \
			and forecast_text.contains("Dmg %d" % odds_attacker.get_physical_damage_against(odds_defender)) \
			and forecast_text.contains("Hit %d%%" % odds_attacker.get_hit_chance_against(odds_defender)) \
			and forecast_text.contains("Crit %d%%" % odds_attacker.get_critical_chance_against(odds_defender)) \
			and not forecast_text.contains("clamp") \
			and hud.forecast_label.text.contains('[hint="Damage =')
		hud.clear_combat_preview()
		target_odds_work = target_odds_work and not hud.forecast_panel.visible and unit_info_panel.visible
	_expect(target_odds_work, "%s displays final Hit and Crit chances against the previewed target" % scene_path)
	if scene_path == "res://game.tscn" and manager != null and board != null:
		var forest_cell := Vector2i(9999, 9999)
		var open_cell := Vector2i(9999, 9999)
		for board_cell in board.get_used_cells():
			if board.is_forest(board_cell) and forest_cell.x == 9999:
				forest_cell = board_cell
			elif not board.is_forest(board_cell) and open_cell.x == 9999:
				open_cell = board_cell
		var terrain_unit: Unit = manager.player_units[0]
		var original_cell := terrain_unit.cell
		terrain_unit.cell = open_cell
		var open_evasion := terrain_unit.get_evasion()
		terrain_unit.cell = forest_cell
		var forest_evasion := terrain_unit.get_evasion()
		terrain_unit.cell = original_cell
		var terrain_attacker := Unit.new()
		var terrain_defender := Unit.new()
		terrain_attacker.set_stats(20, 5, 5, 10, 0, 0)
		terrain_attacker.equip_weapon(EquipmentCatalog.BASIC_AXE)
		terrain_defender.set_stats(20, 5, 5, 0, 0, 0)
		terrain_defender.combat_board = board
		terrain_defender.cell = open_cell
		var open_hit := terrain_attacker.get_hit_chance_against(terrain_defender)
		var projected_hit := terrain_attacker.get_hit_chance_against(terrain_defender, forest_cell)
		terrain_defender.cell = forest_cell
		var forest_hit := terrain_attacker.get_hit_chance_against(terrain_defender)
		_expect(
			forest_cell.x != 9999 and open_cell.x != 9999 \
				and board.get_terrain_avoid(forest_cell) == Board.FOREST_AVOID \
				and forest_evasion == open_evasion + Board.FOREST_AVOID \
				and forest_hit == open_hit - Board.FOREST_AVOID \
				and projected_hit == forest_hit,
			"Map 1 forest tiles grant +%d Evasion" % Board.FOREST_AVOID
		)
		terrain_attacker.free()
		terrain_defender.free()

	var self_heal_works := false
	if manager != null and hud != null and unit_info_tabs != null and skill_action_button != null \
	and not manager.player_units.is_empty():
		var healer: Unit = manager.player_units[0]
		healer.take_damage(8)
		var hp_before_heal := healer.current_hp
		await manager._on_cell_clicked(healer.cell)
		var start := healer.cell
		if not manager.selected_reach_dests.is_empty():
			await manager._on_cell_clicked(manager.selected_reach_dests[0])
		var moved_before_healing := healer.cell != start and manager.selected == healer and not healer.has_acted
		unit_info_tabs.current_tab = 2
		await process_frame
		var expected_healing := healer.get_healing_amount(SkillCatalog.HEAL)
		skill_action_button.pressed.emit()
		await process_frame
		self_heal_works = moved_before_healing and healer.has_active_skill(SkillCatalog.HEAL) \
			and skill_action_button.visible \
			and healer.current_hp == mini(healer.health, hp_before_heal + expected_healing) \
			and healer.has_acted
	_expect(self_heal_works, "%s lets the primary player move, use Heal, and spend the action" % scene_path)
	if manager != null:
		manager.end_turn_button.pressed.emit()
		var deadline := Time.get_ticks_msec() + 8000
		while manager.phase == TurnManager.Phase.ENEMY and Time.get_ticks_msec() < deadline:
			await process_frame
		_expect(manager.phase == TurnManager.Phase.PLAYER and not manager.end_turn_button.disabled,
			"%s runs the enemy phase and returns control to the player" % scene_path)
	var progression_ui_works := false
	if hud != null \
	and manager != null \
	and progression_panel != null \
	and progression_label != null \
	and not manager.player_units.is_empty():
		hud.show_progression_result(manager.player_units[0], 30, [])
		await process_frame
		progression_ui_works = progression_panel.visible \
			and progression_label.text.contains("gained 30 EXP")
	_expect(progression_ui_works, "%s displays EXP and level-up results" % scene_path)

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
	_expect(attacker.get_hit_chance_against(defender) == 60, "Hit chance uses Dexterity minus target Speed")
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


func _test_equipment() -> void:
	var weapons := EquipmentCatalog.all_weapons()
	var armor_catalog := EquipmentCatalog.all_armor()
	_expect(
		weapons.size() == 7 \
		and armor_catalog.size() == 6 \
		and EquipmentCatalog.BASIC_SWORD.display_name == "Basic Sword" \
		and EquipmentCatalog.BASIC_AXE.display_name == "Basic Axe" \
		and EquipmentCatalog.MAIL_HAUBERK.armor_value == 5 \
		and EquipmentCatalog.MAIL_HAUBERK.weight == 7 \
		and EquipmentCatalog.STEEL_PLATE_HARNESS.armor_value == 10 \
		and EquipmentCatalog.STEEL_PLATE_HARNESS.weight == 14,
		"The equipment catalog loads seven weapons and six medieval armor types"
	)

	var attacker := Unit.new()
	attacker.set_stats(20, 10, 10, 80, 0, 0)
	attacker.equip_weapon(EquipmentCatalog.BASIC_SWORD)
	attacker.equip_armor(EquipmentCatalog.MAIL_HAUBERK)
	var defender := Unit.new()
	defender.set_stats(20, 8, 6, 70, 0, 0)
	defender.equip_weapon(EquipmentCatalog.BASIC_AXE)
	defender.equip_armor(EquipmentCatalog.STEEL_PLATE_HARNESS)
	_expect(
		attacker.get_total_weight() == 11 \
		and attacker.get_weight_penalty() == 1 \
		and attacker.get_battle_speed() == 9,
		"Weapon and armor weight produce a Strength-based Battle Speed penalty"
	)
	_expect(
		attacker.get_physical_damage() == 15 \
		and defender.get_armor_value() == 10 \
		and attacker.get_physical_damage_against(defender) == 5 \
		and attacker.get_physical_damage_against(defender, true) == 10,
		"Weapon damage adds to Strength and Armor reduces final damage"
	)
	var accuracy_target := Unit.new()
	accuracy_target.set_stats(20, 5, 5, 0, 0, 0)
	attacker.set_stats(20, 10, 10, 40, 3, 0)
	attacker.equip_weapon(EquipmentCatalog.DAGGER)
	attacker.flat_hit_modifier = -5
	attacker.flat_crit_modifier = 3
	accuracy_target.flat_evasion_modifier = 2
	_expect(
		attacker.get_accuracy() == 130 \
		and attacker.get_hit_chance_against(accuracy_target) == 100 \
		and attacker.get_critical_chance_against(accuracy_target) == 19,
		"Accuracy and critical chance use weapon bases, Dexterity, target Evasion, and their upper clamps"
	)
	attacker.flat_hit_modifier = -500
	_expect(
		attacker.get_hit_chance_against(accuracy_target) == 0,
		"Accuracy can fall to 0%, so sufficiently inaccurate attacks always miss"
	)
	attacker.current_hp = 10
	_expect(
		attacker.get_healing_amount(SkillCatalog.HEAL) == 8 \
		and attacker.heal(attacker.get_healing_amount(SkillCatalog.HEAL)) == 8 \
		and attacker.current_hp == 18,
		"Heal restores Intellect plus Skill Healing Power without exceeding maximum HP"
	)
	accuracy_target.free()
	attacker.set_stats(20, 10, 10, 80, 0, 0)
	attacker.flat_hit_modifier = 0
	attacker.flat_crit_modifier = 0
	attacker.equip_weapon(EquipmentCatalog.BASIC_SWORD)
	attacker.faction = Unit.Faction.PLAYER
	defender.faction = Unit.Faction.ENEMY
	attacker.cell = Vector2i.ZERO
	defender.cell = Vector2i.RIGHT
	var equipment_forecast := CombatResolver.forecast(attacker, defender, attacker.cell)
	_expect(
		int(equipment_forecast["defender_hp_after"]) == 15 \
		and int(equipment_forecast["attacker_hp_after"]) == 10,
		"Combat forecasts use weapon damage and both units' equipped Armor"
	)
	attacker.equip_weapon(EquipmentCatalog.LONGBOW)
	_expect(
		not attacker.can_attack_from_cell(Vector2i.ZERO, Vector2i.RIGHT) \
		and attacker.can_attack_from_cell(Vector2i.ZERO, Vector2i(2, 0)) \
		and attacker.can_attack_from_cell(Vector2i.ZERO, Vector2i(3, 0)),
		"Weapon minimum and maximum ranges control valid attacks"
	)
	attacker.free()
	defender.free()


func _test_progression() -> void:
	var unit := Unit.new()
	unit.set_stats(20, 5, 5, 10, 0, 0)
	unit.level = 1
	unit.experience = 90
	unit.health_growth_rate = 100
	unit.strength_growth_rate = 200
	unit.speed_growth_rate = 0
	unit.dexterity_growth_rate = 300
	unit.intellect_growth_rate = 100
	var random_source := RandomNumberGenerator.new()
	random_source.seed = 12345
	var results := unit.gain_experience(210, random_source)
	_expect(
		results.size() == 3 \
		and unit.level == 4 \
		and unit.experience == 0,
		"EXP carries over and can grant multiple levels"
	)
	_expect(
		unit.health == 23 \
		and unit.current_hp == 23 \
		and unit.strength == 11 \
		and unit.speed == 5 \
		and unit.dexterity == 19 \
		and unit.intellect == 3,
		"Level-up rolls apply guaranteed gains, including growth rates above 100%"
	)

	var defeated := Unit.new()
	unit.level = 5
	defeated.level = 7
	_expect(
		Unit.calculate_kill_experience(unit, defeated) == 40,
		"Kill EXP scales with the level difference"
	)
	unit.level = 1
	defeated.level = 20
	var maximum_exp := Unit.calculate_kill_experience(unit, defeated)
	unit.level = 20
	defeated.level = 1
	var minimum_exp := Unit.calculate_kill_experience(unit, defeated)
	_expect(maximum_exp == 60 and minimum_exp == 10, "Kill EXP stays between 10 and 60")
	unit.free()
	defeated.free()


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
