# Board.gd (TileMapLayer version)
extends TileMapLayer
class_name Board

signal cell_clicked(cell: Vector2i)

var used_rect: Rect2i = Rect2i()

func _ready() -> void:
	used_rect = get_used_rect()

func in_bounds(cell: Vector2i) -> bool:
	if used_rect.size == Vector2i.ZERO:
		# If map data loads late or layer starts empty, refresh bounds on demand.
		used_rect = get_used_rect()
	return used_rect.has_point(cell)

func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell)) # center of tile

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return local_to_map(to_local(world_pos))

func get_map_center_world() -> Vector2:
	var cells: Array[Vector2i] = get_used_cells()
	if cells.is_empty():
		return global_position

	var acc: Vector2 = Vector2.ZERO
	for c in cells:
		var cell: Vector2i = c
		acc += cell_to_world(cell)

	return acc / float(cells.size())

func is_blocked(cell: Vector2i) -> bool:
	# "no tile painted" = blocked (void)
	var td: TileData = get_cell_tile_data(cell)
	if td == null:
		return true
	return bool(td.get_custom_data("blocked"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		var cell: Vector2i = local_to_map(get_local_mouse_position())
		if not is_blocked(cell):
			cell_clicked.emit(cell)
