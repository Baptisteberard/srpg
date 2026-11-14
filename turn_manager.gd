# TurnManager.gd
extends Node
class_name TurnManager

const GridNavigatorScript = preload("res://battle/grid_navigator.gd")
const UnitDefinitionScript = preload("res://units/unit_definition.gd")

enum Phase { PLAYER, ENEMY }

@export var board_path: NodePath
@export var phase_label_path: NodePath
@export var end_turn_button_path: NodePath
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
var stats_panel: PanelContainer
var stats_scroll: ScrollContainer
var stats_label: RichTextLabel
var focused_unit: Unit = null

var phase: Phase = Phase.PLAYER
var busy: bool = false

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
var cursor_follow_active: bool = false
var cursor_follow_last: Vector2i = Vector2i.ZERO
var cursor_follow_steps: Array[Vector2i] = []
var preview_attacker: Unit = null
var preview_defender: Unit = null
var preview_attacker_cell: Vector2i = Vector2i.ZERO

var occ: Dictionary = {} # Dictionary[Vector2i, Unit]
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var grid_navigator = GridNavigatorScript.new()

@export var highlight_path: NodePath
var highlight: HighlightMap

func _ready() -> void:
	rng.randomize()

	board = get_node_or_null(board_path) as Board
	if board == null:
		push_error("TurnManager: board_path is not set to a Board node. Drag Board into board_path in the Inspector.")
		return
	grid_navigator.configure(board, occ)

	phase_label = get_node_or_null(phase_label_path) as Label
	end_turn_button = get_node_or_null(end_turn_button_path) as Button
	highlight = get_node_or_null(highlight_path) as HighlightMap
	if highlight != null:
		highlight.configure_from_board(board)

	end_turn_button.pressed.connect(_on_end_turn_pressed)
	board.cell_clicked.connect(_on_cell_clicked)
	_ensure_stats_ui()

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
	if definition == null or definition.texture == null:
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
	u.set_cell(cell, board.cell_to_world(cell))
	occ[cell] = u

	if faction == Unit.Faction.PLAYER:
		player_units.append(u)
	else:
		enemy_units.append(u)

func _start_player_phase() -> void:
	highlight.clear_cells()
	_clear_hover_preview()
	phase = Phase.PLAYER
	phase_label.text = "Player Turn"
	end_turn_button.disabled = false
	busy = false

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
	if phase != Phase.PLAYER or busy:
		return
	_start_enemy_phase()

func _on_unit_clicked(u: Unit) -> void:
	_focus_unit(u)
	if busy:
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
	if busy:
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
				if not selected_has_moved and _try_move_then_attack(selected, clicked_unit):
					return
				if selected.can_attack(clicked_unit):
					busy = true
					_resolve_attack(selected, clicked_unit, func() -> void:
						_finish_selected_action()
						busy = false
					)
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
	busy = true

	_move_unit(selected, path, func():
		selected_has_moved = true
		selected_last_move_path = path.duplicate()
		_update_selection()
		if selected != null and not _has_attackable_enemy(selected):
			_finish_selected_action()
		busy = false
	)

func _run_enemy_phase() -> void:
	busy = true

	_run_enemies_sequential(0)

func _run_enemies_sequential(index: int) -> void:
	if index >= enemy_units.size():
		busy = false
		_start_player_phase()
		return

	var e: Unit = enemy_units[index]
	if e == null or not is_instance_valid(e) or not e.is_alive():
		_run_enemies_sequential(index + 1)
		return

	var immediate_target: Unit = _pick_adjacent_opponent(e)
	if immediate_target != null:
		_resolve_attack(e, immediate_target, func() -> void:
			var next_index_now: int = _next_enemy_index(index, e)
			_run_enemies_sequential(next_index_now)
		)
		return

	var reach: Dictionary = _reachable_destinations_for(e)
	var options: Array[Vector2i] = reach["dests"]
	var prev: Dictionary = reach["prev"]

	if options.is_empty():
		_run_enemies_sequential(_next_enemy_index(index, e))
		return

	var dest: Vector2i = options[rng.randi_range(0, options.size() - 1)]
	var path: Array[Vector2i] = _shortest_path_with_turn_bias(e, e.cell, dest)
	if path.is_empty():
		path = _reconstruct_path(prev, e.cell, dest)

	_move_unit(e, path, func():
		if e != null and is_instance_valid(e) and e.is_alive():
			var post_move_target: Unit = _pick_adjacent_opponent(e)
			if post_move_target != null:
				_resolve_attack(e, post_move_target, func() -> void:
					var next_index_after_attack: int = _next_enemy_index(index, e)
					_run_enemies_sequential(next_index_after_attack)
				)
				return
		var next_index: int = _next_enemy_index(index, e)
		_run_enemies_sequential(next_index)
	)

func _move_unit(u: Unit, path: Array[Vector2i], done: Callable) -> void:
	# Remove from occupancy while moving
	occ.erase(u.cell)

	u.move_finished.connect(_on_move_finished.bind(done), CONNECT_ONE_SHOT)
	u.move_along(path, board, 0.12)

func _on_move_finished(u: Unit, done: Callable) -> void:
	occ[u.cell] = u
	done.call()

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
	if phase != Phase.PLAYER or busy or selected == null or selected.has_acted:
		_clear_hover_preview()
		return

	var cell: Vector2i = board.world_to_cell(board.get_global_mouse_position())
	var hover_path: Array[Vector2i] = []
	var should_hover: bool = false

	# Movement hover (blue tiles) before moving.
	if not selected_has_moved and selected_reach_dests.has(cell):
		should_hover = true
		hover_path = _build_cursor_follow_path(cell)
		hovered_move_path = hover_path.duplicate()
		_clear_combat_preview()
	# Attack hover (red tiles) on enemy cells.
	elif occ.has(cell):
		var occupant: Unit = occ[cell]
		if occupant != null and occupant.faction != selected.faction and occupant.is_alive():
			if selected_has_moved:
				if selected.can_attack(occupant):
					should_hover = true
					hover_path = []
					_set_combat_preview(selected, occupant, selected.cell)
			else:
				var choice: Dictionary = _build_attack_choice_from_path(selected, occupant, hovered_move_path)
				if choice.is_empty():
					choice = _find_attack_position(selected, occupant)
				if not choice.is_empty():
					should_hover = true
					hover_path = choice["path"]
					_set_combat_preview(selected, occupant, choice["cell"])
				else:
					_clear_combat_preview()
		else:
			_clear_combat_preview()
	else:
		_clear_combat_preview()

	if not should_hover:
		_clear_hover_preview()
		return

	if has_hovered_dest and hovered_dest == cell:
		return

	has_hovered_dest = true
	hovered_dest = cell
	var preview: Array[Vector2i] = [selected.cell]
	for step in hover_path:
		preview.append(step)
	highlight.set_hover_cell(cell)
	highlight.set_preview_path(preview)

func _clear_hover_preview() -> void:
	var had_hover: bool = has_hovered_dest
	has_hovered_dest = false
	hovered_dest = Vector2i.ZERO
	hovered_move_path.clear()
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

func _resolve_attack(attacker: Unit, defender: Unit, done: Callable = Callable()) -> void:
	if attacker == null or defender == null:
		_call_done(done)
		return
	if not attacker.can_attack(defender):
		_call_done(done)
		return

	var first: Unit = attacker
	var second: Unit = defender
	if defender.speed > attacker.speed and defender.can_attack(attacker):
		first = defender
		second = attacker

	_perform_attack_strike(first, second, func() -> void:
		if not is_instance_valid(first) or not is_instance_valid(second):
			_call_done(done)
			return
		if not first.is_alive() or not second.is_alive():
			_call_done(done)
			return
		if not second.can_attack(first):
			_refresh_stats_panel()
			_call_done(done)
			return
		_perform_attack_strike(second, first, done)
	)

func _perform_attack_strike(attacker: Unit, defender: Unit, done: Callable = Callable()) -> void:
	if attacker == null or defender == null:
		_call_done(done)
		return
	if not attacker.can_attack(defender):
		_call_done(done)
		return

	attacker.play_attack_animation(defender.global_position, func() -> void:
		if not is_instance_valid(attacker) or not is_instance_valid(defender):
			_call_done(done)
			return

		var hit_chance: int = attacker.get_hit_chance_against(defender)
		var roll: int = rng.randi_range(1, 100)
		if roll <= hit_chance:
			defender.take_damage(attacker.get_physical_damage())
			if not defender.is_alive():
				_remove_unit(defender)

		_refresh_stats_panel()
		_call_done(done)
	)

func _remove_unit(u: Unit) -> void:
	if u == null:
		return
	occ.erase(u.cell)
	player_units.erase(u)
	enemy_units.erase(u)

	if selected == u:
		selected = null
		selected_has_moved = false
	if focused_unit == u:
		focused_unit = null

	if is_instance_valid(u):
		u.queue_free()

	_update_selection()
	_refresh_stats_panel()

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
	for stand in stand_cells:
		var base_cell: Vector2i = stand
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var md: int = abs(dx) + abs(dy)
				if md == 0 or md > r:
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

func _try_move_then_attack(attacker: Unit, defender: Unit) -> bool:
	if attacker == null or defender == null:
		return false
	if not attacker.is_alive() or not defender.is_alive():
		return false
	if attacker.faction == defender.faction:
		return false
	if selected_has_moved:
		return false

	var choice: Dictionary = _find_hovered_attack_choice(attacker, defender)
	if choice.is_empty():
		choice = _find_attack_position(attacker, defender)
	if choice.is_empty():
		return false

	var move_cell: Vector2i = choice["cell"]
	var path: Array[Vector2i] = choice["path"]

	busy = true
	_reset_cursor_follow()

	if move_cell == attacker.cell:
		_resolve_attack(attacker, defender, func() -> void:
			_finish_selected_action()
			busy = false
		)
		return true

	highlight.clear_cells()
	_clear_hover_preview()
	selected_last_move_path = path.duplicate()
	_move_unit(attacker, path, func() -> void:
		selected_has_moved = true
		# This command is already committed to a specific target:
		# keep move/attack overlays hidden between movement and impact.
		highlight.show_cells([])
		highlight.show_attack_cells([])
		_clear_hover_preview()

		if not is_instance_valid(attacker) or not is_instance_valid(defender):
			if selected != null and not _has_attackable_enemy(selected):
				_finish_selected_action()
			elif selected != null:
				_update_selection()
			busy = false
			return

		if attacker.is_alive() and defender.is_alive() and attacker.can_attack(defender):
			_resolve_attack(attacker, defender, func() -> void:
				_finish_selected_action()
				busy = false
			)
			return

		if selected != null and not _has_attackable_enemy(selected):
			_finish_selected_action()
		elif selected != null:
			_update_selection()
		busy = false
	)
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
	if _manhattan(stand_cell, defender.cell) > attacker.attack_range:
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
		if abs(cell.x - defender.cell.x) + abs(cell.y - defender.cell.y) > attacker.attack_range:
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

func _call_done(done: Callable) -> void:
	if done.is_valid():
		done.call()

func _next_enemy_index(current_index: int, enemy_ref: Unit) -> int:
	if current_index < enemy_units.size() and enemy_units[current_index] == enemy_ref:
		return current_index + 1
	return current_index

func _focus_unit(u: Unit) -> void:
	if u == null or not is_instance_valid(u):
		focused_unit = null
	else:
		focused_unit = u
	_refresh_stats_panel()

func _set_combat_preview(attacker: Unit, defender: Unit, attacker_cell: Vector2i) -> void:
	if attacker == null or defender == null:
		_clear_combat_preview()
		return
	var changed: bool = preview_attacker != attacker \
		or preview_defender != defender \
		or preview_attacker_cell != attacker_cell
	preview_attacker = attacker
	preview_defender = defender
	preview_attacker_cell = attacker_cell
	if changed:
		_refresh_stats_panel()

func _clear_combat_preview() -> void:
	if preview_attacker == null and preview_defender == null:
		return
	preview_attacker = null
	preview_defender = null
	preview_attacker_cell = Vector2i.ZERO
	_refresh_stats_panel()

func _ensure_stats_ui() -> void:
	if phase_label == null:
		return

	var ui_root: Node = phase_label.get_parent()
	if ui_root == null:
		return

	stats_panel = PanelContainer.new()
	stats_panel.name = "UnitStatsPanel"
	stats_panel.visible = false
	stats_panel.anchor_left = 0.0
	stats_panel.anchor_top = 1.0
	stats_panel.anchor_right = 0.0
	stats_panel.anchor_bottom = 1.0
	stats_panel.offset_left = 16.0
	stats_panel.offset_top = -250.0
	stats_panel.offset_right = 320.0
	stats_panel.offset_bottom = -16.0
	ui_root.add_child(stats_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	stats_panel.add_child(margin)

	stats_scroll = ScrollContainer.new()
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	stats_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(stats_scroll)

	stats_label = RichTextLabel.new()
	stats_label.name = "StatsLabel"
	stats_label.bbcode_enabled = true
	stats_label.scroll_active = false
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.fit_content = true
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stats_label.add_theme_constant_override("line_separation", -4)
	stats_label.text = ""
	stats_scroll.add_child(stats_label)

func _refresh_stats_panel() -> void:
	if stats_panel == null or stats_label == null:
		return

	if preview_attacker != null \
	and preview_defender != null \
	and is_instance_valid(preview_attacker) \
	and is_instance_valid(preview_defender) \
	and preview_attacker.is_alive() \
	and preview_defender.is_alive():
		stats_panel.visible = true
		var preview_side_unit: Unit = preview_defender
		if focused_unit != null and is_instance_valid(focused_unit):
			preview_side_unit = focused_unit
		stats_label.text = _build_combat_preview_text(preview_attacker, preview_defender, preview_attacker_cell)
		_position_stats_panel_for_unit(preview_side_unit)
		return

	if focused_unit == null or not is_instance_valid(focused_unit) or not focused_unit.is_alive():
		stats_panel.visible = false
		stats_label.text = ""
		return

	stats_panel.visible = true
	stats_label.text = _build_default_unit_stats_text(focused_unit)
	_position_stats_panel_for_unit(focused_unit)

func _position_stats_panel_for_unit(u: Unit) -> void:
	if stats_panel == null or stats_label == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var max_content_w: float = max(80.0, viewport_size.x - 48.0)
	var content_w: float = _measure_stats_text_width(max_content_w)
	content_w = clampf(content_w, 80.0, max_content_w)

	var content_h: float = _measure_stats_text_height(content_w)
	stats_label.custom_minimum_size = Vector2(content_w, content_h)
	stats_label.update_minimum_size()

	var panel_w: float = content_w + 16.0
	var desired_h: float = content_h + 16.0
	var max_h: float = max(120.0, viewport_size.y - 32.0)
	var panel_h: float = min(desired_h, max_h)

	if stats_scroll != null:
		stats_scroll.custom_minimum_size = Vector2(content_w, panel_h - 16.0)

	stats_panel.anchor_left = 0.0
	stats_panel.anchor_top = 0.0
	stats_panel.anchor_right = 0.0
	stats_panel.anchor_bottom = 0.0

	var is_enemy: bool = u != null and u.faction == Unit.Faction.ENEMY
	var panel_x: float = 16.0
	if is_enemy:
		panel_x = viewport_size.x - panel_w - 16.0
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var panel_y: float = viewport_size.y - panel_h - 16.0
	stats_panel.offset_left = panel_x
	stats_panel.offset_top = panel_y
	stats_panel.offset_right = panel_x + panel_w
	stats_panel.offset_bottom = panel_y + panel_h

func _measure_stats_text_width(max_content_w: float) -> float:
	if stats_label == null:
		return 80.0
	var font: Font = stats_label.get_theme_font("font")
	var font_size: int = stats_label.get_theme_font_size("font_size")
	if font == null:
		return min(max_content_w, stats_label.get_combined_minimum_size().x)
	var plain_text: String = _strip_bbcode_tags(stats_label.text)
	var measured: Vector2 = font.get_multiline_string_size(
		plain_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		100000.0,
		font_size
	)
	return min(max_content_w, ceil(measured.x) + 2.0)

func _measure_stats_text_height(content_w: float) -> float:
	if stats_label == null:
		return 0.0
	var font: Font = stats_label.get_theme_font("font")
	var font_size: int = stats_label.get_theme_font_size("font_size")
	if font == null:
		return stats_label.get_combined_minimum_size().y
	var plain_text: String = _strip_bbcode_tags(stats_label.text)
	var measured: Vector2 = font.get_multiline_string_size(
		plain_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		content_w,
		font_size
	)
	var line_count: int = max(1, plain_text.count("\n") + 1)
	var line_sep: int = stats_label.get_theme_constant("line_separation")
	return max(1.0, measured.y + float(line_sep * max(0, line_count - 1)))

func _strip_bbcode_tags(text_value: String) -> String:
	var rx: RegEx = RegEx.new()
	var err: int = rx.compile("\\[/?[^\\]]+\\]")
	if err != OK:
		return text_value
	return rx.sub(text_value, "", true)

func _build_default_unit_stats_text(u: Unit) -> String:
	if u == null:
		return ""
	var crit_chance: int = int(u.precision / 5)
	var title_text: String = "[b]%s[/b]" % u.get_display_name()
	var attack_type: String = "Melee Attack"
	var attack_line: String = "Dmg: %d | Hit: %d%% | Crit: %d%%" % [u.strength, u.precision, crit_chance]
	if u.attack_range > 1:
		attack_type = "Ranged Attack"
		attack_line += " | Rng: %d" % u.attack_range
	return "%s\nHP: %d/%d | Arm: %d | Evd: %d\n\n%s\n%s\n\nStats\nHP: %d | Str: %d | Spd: %d | Pre: %d | Int: %d" % [
		title_text,
		u.current_hp,
		u.health,
		u.armor,
		u.speed,
		attack_type,
		attack_line,
		u.health,
		u.strength,
		u.speed,
		u.precision,
		u.intellect
	]

func _build_combat_preview_text(attacker: Unit, defender: Unit, attacker_cell: Vector2i) -> String:
	var attacker_can: bool = _can_attack_from_cell(attacker, attacker_cell, defender.cell)
	var defender_can: bool = _can_attack_from_cell(defender, defender.cell, attacker_cell)
	if not attacker_can:
		return "Combat Preview\nCannot attack from current position."

	var attacker_hit: int = attacker.get_hit_chance_against(defender)
	var defender_hit: int = defender.get_hit_chance_against(attacker)
	var attacker_dmg: int = attacker.get_physical_damage()
	var defender_dmg: int = defender.get_physical_damage()

	var attacker_hp_after: int = attacker.current_hp
	var defender_hp_after: int = defender.current_hp

	var first_striker: String = "Attacker"
	var attacker_strikes_first: bool = true
	if defender.speed > attacker.speed and defender_can:
		first_striker = "Defender"
		attacker_strikes_first = false

	if attacker_strikes_first:
		defender_hp_after = maxi(0, defender_hp_after - attacker_dmg)
		if defender_hp_after > 0 and defender_can:
			attacker_hp_after = maxi(0, attacker_hp_after - defender_dmg)
	else:
		attacker_hp_after = maxi(0, attacker_hp_after - defender_dmg)
		if attacker_hp_after > 0 and attacker_can:
			defender_hp_after = maxi(0, defender_hp_after - attacker_dmg)

	return "Combat Preview\nFirst strike: %s\n\nAttacker (%s)\nHP: %d/%d\nStrength: %d\nSpeed: %d\nPrecision: %d\nHit: %d%%\nDamage: %d\nHP After (if hits): %d\n\nDefender (%s)\nHP: %d/%d\nStrength: %d\nSpeed: %d\nPrecision: %d\nHit: %d%%\nDamage: %d\nHP After (if hits): %d" % [
		first_striker,
		_faction_label(attacker),
		attacker.current_hp,
		attacker.health,
		attacker.strength,
		attacker.speed,
		attacker.precision,
		attacker_hit,
		attacker_dmg,
		attacker_hp_after,
		_faction_label(defender),
		defender.current_hp,
		defender.health,
		defender.strength,
		defender.speed,
		defender.precision,
		defender_hit,
		defender_dmg,
		defender_hp_after
	]

func _can_attack_from_cell(attacker: Unit, attacker_cell: Vector2i, defender_cell: Vector2i) -> bool:
	if attacker == null or not attacker.is_alive():
		return false
	return _manhattan(attacker_cell, defender_cell) <= attacker.attack_range

func _faction_label(u: Unit) -> String:
	if u == null:
		return "Unknown"
	if u.faction == Unit.Faction.ENEMY:
		return "Enemy"
	return "Player"

func _is_empty_click_unselect(cell: Vector2i) -> bool:
	if occ.has(cell):
		return false
	if selected != null:
		return not _cell_is_highlighted_for_selection(cell)
	return focused_unit != null

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
	if phase != Phase.PLAYER or busy:
		return false

	if selected != null:
		if selected_has_moved and _has_attackable_enemy(selected):
			if _undo_selected_move():
				return true
		_clear_selection()
		_focus_unit(null)
		return true

	if focused_unit != null:
		_focus_unit(null)
		return true

	return false

func _undo_selected_move() -> bool:
	if selected == null:
		return false
	if not selected_has_moved:
		return false
	if not _has_attackable_enemy(selected):
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
