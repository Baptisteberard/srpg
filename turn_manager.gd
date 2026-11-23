# TurnManager.gd
extends Node
class_name TurnManager

const GridNavigatorScript = preload("res://battle/grid_navigator.gd")
const UnitDefinitionScript = preload("res://units/unit_definition.gd")
const BattleHudScript = preload("res://ui/battle_hud.gd")
const CombatResolverScript = preload("res://battle/combat_resolver.gd")
const BattlePresentation = preload("res://battle/battle_presentation.gd")
const EnemyAIScript = preload("res://battle/enemy_ai.gd")
const BASE_MOVE_STEP_TIME: float = 0.12

enum Phase { PLAYER, ENEMY }
enum ActionState { IDLE, MOVING, COMBAT, ENEMY_TURN }

@export var board_path: NodePath
@export var phase_label_path: NodePath
@export var end_turn_button_path: NodePath
@export var hud_path: NodePath
@export var unit_scene: PackedScene
@export var player_unit_count: int = 1
@export var enemy_unit_count: int = 1
@export_group("Unit Definitions")
@export var default_unit_definition: UnitStats
@export var player_unit_definitions: Array[UnitStats] = []
@export var enemy_unit_definitions: Array[UnitStats] = []
@export_group("Visuals")
@export var player_unit_color: Color = Color8(51, 153, 255, 255)
@export var enemy_unit_color: Color = Color8(255, 51, 51, 255)

var board: Board
var phase_label: Label
var end_turn_button: Button
var hud

var phase: Phase = Phase.PLAYER
var action_state: ActionState = ActionState.IDLE

var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []
var selected: Unit = null
var selected_has_moved: bool = false
var selected_reach_dests: Array[Vector2i] = []
var selected_reach_prev: Dictionary = {}
var selected_origin_cell: Vector2i = Vector2i.ZERO
var selected_last_move_path: Array[Vector2i] = []
var has_hovered_dest: bool = false
var hovered_dest: Vector2i = Vector2i.ZERO
var hovered_move_path: Array[Vector2i] = []
var forecast_move_path: Array[Vector2i] = []
var cursor_follow_active: bool = false
var cursor_follow_last: Vector2i = Vector2i.ZERO
var cursor_follow_steps: Array[Vector2i] = []
var occ: Dictionary = {} # Dictionary[Vector2i, Unit]
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var grid_navigator = GridNavigatorScript.new()
var combat_resolver = CombatResolverScript.new()
var enemy_ai = EnemyAIScript.new()
var unit_visual_size_multiplier: float = 0.75
var unit_visual_vertical_offset: float = -24.0
var unit_animation_speed_multiplier: float = 1.0
var unit_movement_speed_multiplier: float = 1.0

@export var highlight_path: NodePath
var highlight: HighlightMap

func _ready() -> void:
	rng.randomize()
	combat_resolver.configure(rng)
	enemy_ai.configure(rng)
	combat_resolver.unit_defeated.connect(_remove_unit)
	combat_resolver.combat_state_changed.connect(_refresh_stats_panel)

	board = get_node_or_null(board_path) as Board
	if board == null:
		push_error("TurnManager: board_path is not set to a Board node. Drag Board into board_path in the Inspector.")
		return
	grid_navigator.configure(board, occ)

	phase_label = get_node_or_null(phase_label_path) as Label
	end_turn_button = get_node_or_null(end_turn_button_path) as Button
	hud = get_node_or_null(hud_path)
	if hud == null or hud.get_script() != BattleHudScript:
		push_error("TurnManager: hud_path is not set to the shared BattleHud node.")
		return
	if not hud.skill_requested.is_connected(_on_skill_requested):
		hud.skill_requested.connect(_on_skill_requested)
	hud.forecast_attack_requested.connect(_on_forecast_attack_requested)
	var battle_layer := CanvasLayer.new()
	battle_layer.layer = 20
	add_child(battle_layer)
	var presentation := BattlePresentation.new()
	battle_layer.add_child(presentation)
	combat_resolver.presentation = presentation
	highlight = get_node_or_null(highlight_path) as HighlightMap
	if highlight != null:
		highlight.configure_from_board(board)

	end_turn_button.pressed.connect(_on_end_turn_pressed)
	board.cell_clicked.connect(_on_cell_clicked)

	_spawn_start_units()
	_start_player_phase()

func _process(_delta: float) -> void:
	_update_hover_preview()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_RIGHT \
	and event.pressed:
		if _handle_right_click_cancel():
			get_viewport().set_input_as_handled()

func _spawn_start_units() -> void:
	var player_tex: Texture2D = _make_circle_texture(player_unit_color)
	var enemy_tex: Texture2D = _make_circle_texture(enemy_unit_color)

	var spawns: Dictionary = _find_auto_spawns(player_unit_count, enemy_unit_count)
	var player_starts: Array[Vector2i] = []
	var enemy_starts: Array[Vector2i] = []
	for c in spawns["players"]:
		player_starts.append(c)
	for c in spawns["enemies"]:
		enemy_starts.append(c)

	for i in range(player_starts.size()):
		var player_cell: Vector2i = player_starts[i]
		_add_unit(Unit.Faction.PLAYER, player_cell, player_tex, _definition_for(Unit.Faction.PLAYER, i))
	for i in range(enemy_starts.size()):
		var enemy_cell: Vector2i = enemy_starts[i]
		_add_unit(Unit.Faction.ENEMY, enemy_cell, enemy_tex, _definition_for(Unit.Faction.ENEMY, i))

func _find_auto_spawns(player_count: int, enemy_count: int) -> Dictionary:
	var walkable: Array[Vector2i] = []
	for c in board.get_used_cells():
		var cell: Vector2i = c
		if not board.is_blocked(cell):
			walkable.append(cell)

	walkable.sort_custom(func(a, b):
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)

	var safe_player_count: int = player_count if player_count > 0 else 0
	var safe_enemy_count: int = enemy_count if enemy_count > 0 else 0
	var needed: int = safe_player_count + safe_enemy_count
	if walkable.size() < needed:
		push_error("TurnManager: not enough walkable cells to place all start units.")

	var players: Array[Vector2i] = []
	var enemies: Array[Vector2i] = []
	var used: Dictionary = {}

	for i in range(min(safe_player_count, walkable.size())):
		var pcell: Vector2i = walkable[i]
		players.append(pcell)
		used[pcell] = true

	for i in range(walkable.size() - 1, -1, -1):
		if enemies.size() >= safe_enemy_count:
			break
		var ecell: Vector2i = walkable[i]
		if used.has(ecell):
			continue
		enemies.append(ecell)
		used[ecell] = true

	if players.size() < safe_player_count or enemies.size() < safe_enemy_count:
		push_error("TurnManager: spawn placement incomplete for requested unit counts.")

	return {"players": players, "enemies": enemies}

func _definition_for(faction: Unit.Faction, spawn_index: int) -> UnitStats:
	var overrides: Array[UnitStats] = player_unit_definitions
	if faction == Unit.Faction.ENEMY:
		overrides = enemy_unit_definitions
	if spawn_index >= 0 and spawn_index < overrides.size() and overrides[spawn_index] != null:
		return overrides[spawn_index]
	if default_unit_definition != null:
		return default_unit_definition
	return UnitDefinitionScript.new() as UnitStats

func _add_unit(faction: Unit.Faction, cell: Vector2i, tex: Texture2D, definition: UnitStats = null) -> void:
	var u: Unit = unit_scene.instantiate()
	u.faction = faction
	var auto_name: String = "Ally %d" % [player_units.size() + 1]
	if faction == Unit.Faction.ENEMY:
		auto_name = "Enemy %d" % [enemy_units.size() + 1]
	if u.unit_name.strip_edges() == "":
		u.set_display_name(auto_name)
	if definition != null:
		u.apply_definition(definition, true)
		if definition.display_name.strip_edges() == "":
			u.set_display_name(auto_name)
	u.set_tile_size(board.tile_set.tile_size)
	u.set_visual_settings(unit_visual_size_multiplier, unit_visual_vertical_offset)
	u.set_animation_speed_multiplier(unit_animation_speed_multiplier)
	if definition == null \
	or (definition.texture == null and definition.fe8_map_sprite_animation == null):
		u.set_texture(tex)
	u.clicked.connect(_on_unit_clicked)

	var world_parent: Node = board
	var board_parent: Node = board.get_parent()
	if board_parent != null:
		var depth_sort: Node = board_parent.get_node_or_null("DepthSort")
		if depth_sort is Node2D and (depth_sort as Node2D).y_sort_enabled:
			world_parent = depth_sort
		elif board_parent is Node2D and (board_parent as Node2D).y_sort_enabled:
			world_parent = board_parent
	world_parent.add_child(u)
	u.combat_board = board
	u.set_cell(cell, board.cell_to_world(cell))
	occ[cell] = u

	if faction == Unit.Faction.PLAYER:
		player_units.append(u)
	else:
		enemy_units.append(u)

func set_unit_visual_settings(size_multiplier: float, vertical_offset: float) -> void:
	unit_visual_size_multiplier = clampf(size_multiplier, 0.5, 2.0)
	unit_visual_vertical_offset = clampf(vertical_offset, -64.0, 64.0)
	var all_units: Array[Unit] = player_units.duplicate()
	all_units.append_array(enemy_units)
	for unit in all_units:
		if unit != null and is_instance_valid(unit):
			unit.set_visual_settings(unit_visual_size_multiplier, unit_visual_vertical_offset)

func set_unit_animation_settings(animation_speed_multiplier: float, movement_speed_multiplier: float) -> void:
	unit_animation_speed_multiplier = clampf(animation_speed_multiplier, 0.25, 3.0)
	unit_movement_speed_multiplier = clampf(movement_speed_multiplier, 0.25, 2.0)
	var all_units: Array[Unit] = player_units.duplicate()
	all_units.append_array(enemy_units)
	for unit in all_units:
		if unit != null and is_instance_valid(unit):
			unit.set_animation_speed_multiplier(unit_animation_speed_multiplier)

func get_move_step_time() -> float:
	return BASE_MOVE_STEP_TIME / unit_movement_speed_multiplier

func _start_player_phase() -> void:
	highlight.clear_cells()
	_clear_hover_preview()
	phase = Phase.PLAYER
	phase_label.text = "Player Turn"
	end_turn_button.disabled = false
	action_state = ActionState.IDLE

	for u in player_units:
		u.has_acted = false

	selected = null
	selected_has_moved = false
	_reset_cursor_follow()
	_update_selection()

func _start_enemy_phase() -> void:
	highlight.clear_cells()
	_clear_hover_preview()
	phase = Phase.ENEMY
	phase_label.text = "Enemy Turn"
	end_turn_button.disabled = true
	selected = null
	selected_has_moved = false
	_reset_cursor_follow()
	_update_selection()

	_run_enemy_phase()

func _on_end_turn_pressed() -> void:
	if phase != Phase.PLAYER or _is_busy():
		return
	_start_enemy_phase()

func _on_unit_clicked(u: Unit) -> void:
	_focus_unit(u)
	if _is_busy():
		return
	if phase != Phase.PLAYER:
		return
	if u.faction != Unit.Faction.PLAYER:
		return
	if u.has_acted:
		return
	if selected_has_moved:
		if selected == u:
			_finish_selected_action()
		return

	_select_unit(u)

func _update_selection() -> void:
	for u in player_units:
		u.set_selected(u == selected)
	_refresh_highlight()

func _on_cell_clicked(cell: Vector2i) -> void:
	if _is_busy():
		return
	if phase != Phase.PLAYER:
		return

	# Tile-click selection: select a player unit standing on the clicked cell.
	if occ.has(cell):
		var clicked_unit: Unit = occ[cell]
		if clicked_unit != null:
			_focus_unit(clicked_unit)
		if clicked_unit != null \
		and clicked_unit.faction == Unit.Faction.PLAYER \
		and not clicked_unit.has_acted:
			if selected_has_moved and selected != clicked_unit:
				return
			if selected_has_moved and selected == clicked_unit:
				_finish_selected_action()
				return
			_select_unit(clicked_unit)
			return
		if clicked_unit != null and clicked_unit.faction == Unit.Faction.ENEMY:
			# Combat intent has priority over simple enemy selection.
			if selected != null and not selected.has_acted:
				# If a move+attack route is possible (including hovered route), prefer it.
				# This allows flanking/reposition attacks even when already adjacent.
				if not selected_has_moved:
					var handled: bool = await _try_move_then_attack(selected, clicked_unit)
					if handled:
						return
				if selected.can_attack(clicked_unit):
					action_state = ActionState.COMBAT
					await _resolve_attack(selected, clicked_unit)
					_finish_selected_action()
					action_state = ActionState.IDLE
					return

			# If no combat command was possible, enemy click acts as pure focus/select.
			if selected != null and not selected_has_moved:
				_clear_selection()
			return
	else:
		if _is_empty_click_unselect(cell):
			if selected != null:
				if selected_has_moved:
					_finish_selected_action()
				else:
					_clear_selection()
			_focus_unit(null)
			return

	if selected == null or selected.has_acted:
		return
	if selected_has_moved:
		if cell == selected.cell:
			_finish_selected_action()
		return

	if selected_reach_dests.is_empty():
		_refresh_highlight()

	if not selected_reach_dests.has(cell):
		return

	var path: Array[Vector2i] = _shortest_path_with_turn_bias(selected, selected.cell, cell)
	if path.is_empty():
		path = _reconstruct_path(selected_reach_prev, selected.cell, cell)
	if has_hovered_dest and hovered_dest == cell and not hovered_move_path.is_empty():
		path = hovered_move_path.duplicate()

	highlight.clear_cells()
	_clear_hover_preview()
	_reset_cursor_follow()
	action_state = ActionState.MOVING
	await _move_unit(selected, path)
	selected_has_moved = true
	selected_last_move_path = path.duplicate()
	_update_selection()
	if selected != null and not _has_post_move_action(selected):
		_finish_selected_action()
	action_state = ActionState.IDLE

func _has_post_move_action(unit: Unit) -> bool:
	if _has_attackable_enemy(unit):
		return true
	if unit.current_hp < unit.health:
		for skill in unit.active_skills:
			if skill != null and skill.is_healing_skill():
				return true
	return false

func _run_enemy_phase() -> void:
	action_state = ActionState.ENEMY_TURN
	var acting_units: Array[Unit] = enemy_units.duplicate()
	for enemy in acting_units:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue

		var target: Unit = _pick_adjacent_opponent(enemy)
		if target != null:
			await _resolve_attack(enemy, target)
			continue

		var move_choice: Dictionary = enemy_ai.choose_move(enemy, grid_navigator)
		if move_choice.is_empty():
			continue
		await _move_unit(enemy, move_choice["path"])

		if is_instance_valid(enemy) and enemy.is_alive():
			target = _pick_adjacent_opponent(enemy)
			if target != null:
				await _resolve_attack(enemy, target)

	_start_player_phase()

func _move_unit(u: Unit, path: Array[Vector2i]) -> void:
	occ.erase(u.cell)
	await u.move_along(path, board, get_move_step_time())
	if is_instance_valid(u):
		occ[u.cell] = u

func _cell_is_free(cell: Vector2i) -> bool:
	return not occ.has(cell)

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _make_circle_texture(color: Color) -> Texture2D:
	var s: int = 64
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color8(0, 0, 0, 0))

	var center: Vector2 = Vector2(s / 2.0, s / 2.0)
	var r: float = s * 0.33

	for y in range(s):
		for x in range(s):
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			if p.distance_to(center) <= r:
				img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)
	
func _refresh_highlight() -> void:
	if phase != Phase.PLAYER or selected == null:
		highlight.clear_cells()
		selected_reach_dests.clear()
		selected_reach_prev.clear()
		_clear_hover_preview()
		return
	if selected_has_moved:
		var attack_after_move: Array[Vector2i] = _attack_tiles_for_turn(selected, false)
		highlight.show_cells([])
		highlight.show_attack_cells(attack_after_move)
		selected_reach_dests.clear()
		selected_reach_prev.clear()
		_clear_hover_preview()
		return

	var reach: Dictionary = _reachable_destinations_for(selected)
	var attack_cells: Array[Vector2i] = _attack_tiles_for_turn(selected, true)
	selected_reach_dests.clear()
	for c in reach["dests"]:
		selected_reach_dests.append(c)
	selected_reach_prev = reach["prev"]

	var move_cells_set: Dictionary = {}
	for c in selected_reach_dests:
		move_cells_set[c] = true
	var attack_cells_display: Array[Vector2i] = []
	for c in attack_cells:
		if not move_cells_set.has(c):
			attack_cells_display.append(c)

	highlight.show_cells(selected_reach_dests)
	highlight.show_attack_cells(attack_cells_display)
	_clear_hover_preview()

func _update_hover_preview() -> void:
	if highlight == null or board == null:
		return
	if phase != Phase.PLAYER or _is_busy() or selected == null or selected.has_acted:
		_clear_hover_preview()
		return

	if hud.is_pointer_over_forecast():
		_clear_hover_preview(true)
		return

	var cell: Vector2i = board.world_to_cell(board.get_global_mouse_position())
	var hover_path: Array[Vector2i] = []
	var should_hover: bool = false

	# Movement hover (blue tiles) before moving.
	if not selected_has_moved and selected_reach_dests.has(cell):
		should_hover = true
		hover_path = _build_cursor_follow_path(cell)
		hovered_move_path = hover_path.duplicate()
	# Attack hover (red tiles) on enemy cells.
	elif occ.has(cell):
		var occupant: Unit = occ[cell]
		if occupant != null and occupant.faction != selected.faction and occupant.is_alive():
			if selected_has_moved:
				if selected.can_attack(occupant):
					should_hover = true
					hover_path = []
					_set_combat_preview(selected, occupant, selected.cell, hover_path)
			else:
				var choice: Dictionary = _build_attack_choice_from_path(selected, occupant, hovered_move_path)
				if choice.is_empty():
					choice = _find_attack_position(selected, occupant)
				if not choice.is_empty():
					should_hover = true
					hover_path = choice["path"]
					_set_combat_preview(selected, occupant, choice["cell"], hover_path)

	if not should_hover:
		_clear_hover_preview(hud.should_keep_forecast())
		return
	if not occ.has(cell) and not hud.should_keep_forecast():
		_clear_combat_preview()

	if has_hovered_dest and hovered_dest == cell:
		return

	has_hovered_dest = true
	hovered_dest = cell
	var preview: Array[Vector2i] = [selected.cell]
	for step in hover_path:
		preview.append(step)
	highlight.set_hover_cell(cell)
	highlight.set_preview_path(preview)

func _clear_hover_preview(keep_forecast: bool = false) -> void:
	var had_hover: bool = has_hovered_dest
	has_hovered_dest = false
	hovered_dest = Vector2i.ZERO
	hovered_move_path.clear()
	if not keep_forecast:
		_clear_combat_preview()
	if highlight != null:
		if had_hover:
			highlight.clear_hover_cell()
		highlight.clear_preview_path()
	
func _cell_walkable_for_mover(cell: Vector2i, mover: Unit) -> bool:
	return grid_navigator.cell_walkable_for(cell, mover)

func _bfs_from(mover: Unit) -> Dictionary:
	return grid_navigator.reachable_from(mover)

func _reconstruct_path(prev: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return grid_navigator.reconstruct_path(prev, start, goal)

func _shortest_path_with_turn_bias(mover: Unit, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return grid_navigator.shortest_path(mover, start, goal)

func _reachable_destinations_for(mover: Unit) -> Dictionary:
	return grid_navigator.reachable_destinations(mover)

func _select_unit(u: Unit) -> void:
	if u == null:
		return
	selected = u
	selected_has_moved = false
	selected_origin_cell = u.cell
	selected_last_move_path.clear()
	_reset_cursor_follow()
	_clear_hover_preview()
	_update_selection()

func _clear_selection() -> void:
	selected = null
	selected_has_moved = false
	selected_origin_cell = Vector2i.ZERO
	selected_last_move_path.clear()
	_reset_cursor_follow()
	_update_selection()

func _finish_selected_action() -> void:
	if selected == null:
		return
	selected.has_acted = true
	selected = null
	selected_has_moved = false
	selected_origin_cell = Vector2i.ZERO
	selected_last_move_path.clear()
	_reset_cursor_follow()
	_update_selection()

func _has_attackable_enemy(attacker: Unit) -> bool:
	return _pick_adjacent_opponent(attacker) != null

func _pick_adjacent_opponent(attacker: Unit) -> Unit:
	if attacker == null or not attacker.is_alive():
		return null
	var targets: Array[Unit] = []
	if attacker.faction == Unit.Faction.ENEMY:
		targets = player_units
	else:
		targets = enemy_units
	for t in targets:
		if attacker.can_attack(t):
			return t
	return null

func _resolve_attack(attacker: Unit, defender: Unit) -> void:
	await combat_resolver.resolve(attacker, defender)

func _on_skill_requested(unit: Unit, skill: SkillDefinition) -> void:
	if phase != Phase.PLAYER or _is_busy():
		return
	if unit == null or not is_instance_valid(unit) or unit != selected:
		return
	if unit.has_acted or not unit.is_alive() or not unit.has_active_skill(skill):
		return
	if skill == null or not skill.is_healing_skill() or unit.current_hp >= unit.health:
		return
	action_state = ActionState.COMBAT
	unit.heal(unit.get_healing_amount(skill))
	_finish_selected_action()
	_refresh_stats_panel()
	action_state = ActionState.IDLE

func _remove_unit(u: Unit, victor: Unit = null) -> void:
	if u == null:
		return
	if victor != null and is_instance_valid(victor) and victor != u and victor.is_alive():
		var experience_gained := Unit.calculate_kill_experience(victor, u)
		var level_results := victor.gain_experience(experience_gained, rng)
		if hud != null:
			hud.show_progression_result(victor, experience_gained, level_results)
	occ.erase(u.cell)
	player_units.erase(u)
	enemy_units.erase(u)

	if selected == u:
		selected = null
		selected_has_moved = false
	if hud != null:
		hud.forget_unit(u)

	_update_selection()
	_refresh_stats_panel()

	# The unit stops participating immediately, but remains visible long enough
	# for its death fade to finish before the node is freed.
	if is_instance_valid(u):
		await u.play_death_fade()
	if is_instance_valid(u):
		u.queue_free()

func _attackable_enemy_cells(attacker: Unit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if attacker == null or not attacker.is_alive():
		return out
	var targets: Array[Unit] = []
	if attacker.faction == Unit.Faction.ENEMY:
		targets = player_units
	else:
		targets = enemy_units
	for t in targets:
		if attacker.can_attack(t):
			out.append(t.cell)
	return out

func _attack_tiles_for_turn(attacker: Unit, include_move_range: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if attacker == null or not attacker.is_alive() or board == null:
		return out

	var stand_cells: Array[Vector2i] = []
	if include_move_range:
		stand_cells = _stand_cells_for_turn(attacker)
	else:
		stand_cells = [attacker.cell]

	var uniq: Dictionary = {}
	var r: int = maxi(1, attacker.attack_range)
	var minimum_range: int = maxi(1, attacker.minimum_attack_range)
	for stand in stand_cells:
		var base_cell: Vector2i = stand
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var md: int = abs(dx) + abs(dy)
				if md < minimum_range or md > r:
					continue
				var c: Vector2i = base_cell + Vector2i(dx, dy)
				if not board.in_bounds(c):
					continue
				if board.is_blocked(c):
					continue
				uniq[c] = true

	for c in uniq.keys():
		var out_cell: Vector2i = c
		if out_cell == attacker.cell:
			continue
		out.append(out_cell)

	out.sort_custom(func(a, b):
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return out

func _stand_cells_for_turn(attacker: Unit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if attacker == null or not attacker.is_alive():
		return out

	var bfs: Dictionary = _bfs_from(attacker)
	var dist: Dictionary = bfs["dist"]
	for c in dist.keys():
		var cell: Vector2i = c
		if cell != attacker.cell and occ.has(cell):
			continue
		out.append(cell)
	return out

func _try_move_then_attack(attacker: Unit, defender: Unit, choice: Dictionary = {}) -> bool:
	if attacker == null or defender == null:
		return false
	if not attacker.is_alive() or not defender.is_alive():
		return false
	if attacker.faction == defender.faction:
		return false
	if selected_has_moved:
		return false

	if choice.is_empty():
		choice = _find_hovered_attack_choice(attacker, defender)
	if choice.is_empty():
		choice = _find_attack_position(attacker, defender)
	if choice.is_empty():
		return false

	var move_cell: Vector2i = choice["cell"]
	var path: Array[Vector2i] = choice["path"]

	_reset_cursor_follow()

	if move_cell == attacker.cell:
		action_state = ActionState.COMBAT
		await _resolve_attack(attacker, defender)
		_finish_selected_action()
		action_state = ActionState.IDLE
		return true

	highlight.clear_cells()
	_clear_hover_preview()
	selected_last_move_path = path.duplicate()
	action_state = ActionState.MOVING
	await _move_unit(attacker, path)
	selected_has_moved = true
	# This command is already committed to a specific target: keep overlays
	# hidden between movement and impact.
	highlight.show_cells([])
	highlight.show_attack_cells([])
	_clear_hover_preview()

	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		if selected != null and not _has_attackable_enemy(selected):
			_finish_selected_action()
		elif selected != null:
			_update_selection()
		action_state = ActionState.IDLE
		return true

	if attacker.is_alive() and defender.is_alive() and attacker.can_attack(defender):
		action_state = ActionState.COMBAT
		await _resolve_attack(attacker, defender)
		_finish_selected_action()
		action_state = ActionState.IDLE
		return true

	if selected != null and not _has_attackable_enemy(selected):
		_finish_selected_action()
	elif selected != null:
		_update_selection()
	action_state = ActionState.IDLE
	return true

func _find_hovered_attack_choice(attacker: Unit, defender: Unit) -> Dictionary:
	if attacker == null or defender == null:
		return {}
	if not has_hovered_dest or hovered_dest != defender.cell:
		return {}
	return _build_attack_choice_from_path(attacker, defender, hovered_move_path)

func _build_attack_choice_from_path(attacker: Unit, defender: Unit, path_candidate: Array[Vector2i]) -> Dictionary:
	if attacker == null or defender == null:
		return {}

	var path: Array[Vector2i] = path_candidate.duplicate()
	var stand_cell: Vector2i = attacker.cell
	if not path.is_empty():
		stand_cell = path[path.size() - 1]
		if path.size() > attacker.move_range:
			return {}
		if not _path_is_valid_for_mover(attacker, path, stand_cell):
			return {}

	if stand_cell != attacker.cell and occ.has(stand_cell):
		return {}
	if not attacker.can_attack_from_cell(stand_cell, defender.cell):
		return {}

	return {"cell": stand_cell, "path": path}

func _find_attack_position(attacker: Unit, defender: Unit) -> Dictionary:
	var bfs: Dictionary = _bfs_from(attacker)
	var dist: Dictionary = bfs["dist"]
	var prev: Dictionary = bfs["prev"]

	var found: bool = false
	var best_cell: Vector2i = attacker.cell
	var best_dist: int = 1_000_000

	for c in dist.keys():
		var cell: Vector2i = c
		var d: int = dist[cell]
		if d > attacker.move_range:
			continue
		if cell != attacker.cell and occ.has(cell):
			continue
		if not attacker.can_attack_from_cell(cell, defender.cell):
			continue
		if not found or d < best_dist or (d == best_dist and _cell_precedes(cell, best_cell)):
			found = true
			best_cell = cell
			best_dist = d

	if not found:
		return {}

	var path: Array[Vector2i] = _shortest_path_with_turn_bias(attacker, attacker.cell, best_cell)
	if path.is_empty():
		path = _reconstruct_path(prev, attacker.cell, best_cell)
	return {"cell": best_cell, "path": path}

func _cell_precedes(a: Vector2i, b: Vector2i) -> bool:
	if a.y == b.y:
		return a.x < b.x
	return a.y < b.y

func _build_cursor_follow_path(target: Vector2i) -> Array[Vector2i]:
	if selected == null:
		return []
	var fallback: Array[Vector2i] = _shortest_path_with_turn_bias(selected, selected.cell, target)
	if fallback.is_empty():
		fallback = _reconstruct_path(selected_reach_prev, selected.cell, target)
	if target == selected.cell:
		_reset_cursor_follow()
		return []
	if not selected_reach_dests.has(target):
		return fallback

	if not cursor_follow_active:
		cursor_follow_active = true
		cursor_follow_last = selected.cell
		cursor_follow_steps.clear()

	if target != cursor_follow_last:
		var segment: Array[Vector2i] = _shortest_preview_path(selected, cursor_follow_last, target)
		if segment.is_empty():
			cursor_follow_steps = fallback.duplicate()
		else:
			var traced_candidate: Array[Vector2i] = cursor_follow_steps.duplicate()
			for step in segment:
				traced_candidate.append(step)

			# Fire Emblem-like rule: traced path cannot visit a tile twice.
			# If the cursor trace loops/backtracks onto an already used tile,
			# invalidate it and fall back to shortest path for this target.
			if _path_has_repeated_tiles(selected.cell, traced_candidate):
				cursor_follow_steps = fallback.duplicate()
			else:
				cursor_follow_steps = traced_candidate
		cursor_follow_last = target

	if cursor_follow_steps.size() > selected.move_range \
	or not _path_is_valid_for_mover(selected, cursor_follow_steps, target):
		cursor_follow_steps = fallback.duplicate()
		cursor_follow_last = target

	return cursor_follow_steps.duplicate()

func _shortest_preview_path(mover: Unit, from: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return _shortest_path_with_turn_bias(mover, from, goal)

func _path_is_valid_for_mover(mover: Unit, path: Array[Vector2i], goal: Vector2i) -> bool:
	if mover == null:
		return false
	if path.is_empty():
		return goal == mover.cell
	if path[path.size() - 1] != goal:
		return false

	var cur: Vector2i = mover.cell
	for step in path:
		if abs(step.x - cur.x) + abs(step.y - cur.y) != 1:
			return false
		if not _cell_walkable_for_mover(step, mover):
			return false
		cur = step
	return true

func _path_has_repeated_tiles(start: Vector2i, path: Array[Vector2i]) -> bool:
	var seen: Dictionary = {start: true}
	for c in path:
		var cell: Vector2i = c
		if seen.has(cell):
			return true
		seen[cell] = true
	return false

func _reset_cursor_follow() -> void:
	cursor_follow_active = false
	cursor_follow_last = Vector2i.ZERO
	cursor_follow_steps.clear()

func _is_busy() -> bool:
	return action_state != ActionState.IDLE

func _focus_unit(u: Unit) -> void:
	hud.focus_unit(u)

func _set_combat_preview(attacker: Unit, defender: Unit, attacker_cell: Vector2i, path: Array[Vector2i]) -> void:
	forecast_move_path = path.duplicate()
	hud.show_combat_preview(attacker, defender, attacker_cell)

func _on_forecast_attack_requested(attacker: Unit, defender: Unit, attack_cell: Vector2i) -> void:
	if phase != Phase.PLAYER or _is_busy() or not is_instance_valid(attacker) or not is_instance_valid(defender):
		return
	if attacker != selected or attacker.has_acted or occ.get(defender.cell) != defender:
		return
	if selected_has_moved:
		if attack_cell == attacker.cell and attacker.can_attack(defender):
			await _on_cell_clicked(defender.cell)
		return
	var choice := _build_attack_choice_from_path(attacker, defender, forecast_move_path)
	if choice.get("cell") == attack_cell:
		await _try_move_then_attack(attacker, defender, choice)

func _clear_combat_preview() -> void:
	forecast_move_path.clear()
	hud.clear_combat_preview()

func _refresh_stats_panel() -> void:
	hud.refresh()

func _is_empty_click_unselect(cell: Vector2i) -> bool:
	if occ.has(cell):
		return false
	if selected != null:
		return not _cell_is_highlighted_for_selection(cell)
	return hud.focused_unit != null

func _cell_is_highlighted_for_selection(cell: Vector2i) -> bool:
	if selected == null:
		return false

	if not selected_has_moved:
		if selected_reach_dests.has(cell):
			return true
		var attack_cells_pre_move: Array[Vector2i] = _attack_tiles_for_turn(selected, true)
		return attack_cells_pre_move.has(cell)

	var attack_cells_post_move: Array[Vector2i] = _attack_tiles_for_turn(selected, false)
	return attack_cells_post_move.has(cell)

func _handle_right_click_cancel() -> bool:
	if phase != Phase.PLAYER or _is_busy():
		return false

	if selected != null:
		if selected_has_moved and _has_post_move_action(selected):
			if _undo_selected_move():
				return true
		_clear_selection()
		_focus_unit(null)
		return true

	if hud.focused_unit != null:
		_focus_unit(null)
		return true

	return false

func _undo_selected_move() -> bool:
	if selected == null:
		return false
	if not selected_has_moved:
		return false
	if not _has_post_move_action(selected):
		return false
	if selected_origin_cell == selected.cell:
		return false
	if occ.has(selected_origin_cell):
		return false

	occ.erase(selected.cell)
	selected.set_cell(selected_origin_cell, board.cell_to_world(selected_origin_cell))
	occ[selected.cell] = selected

	selected_has_moved = false
	selected_last_move_path.clear()
	_reset_cursor_follow()
	_clear_hover_preview()
	_update_selection()
	_focus_unit(selected)
	return true
