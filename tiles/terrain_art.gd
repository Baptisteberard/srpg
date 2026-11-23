extends Node2D

const SHEET = preload("res://tiles/kenney_tiny_town.png")
const GRASS := Vector2i(0, 0)
const PATH := Vector2i(1, 2)
const STONES := Vector2i(5, 3)
const EVERGREEN := Vector2i(5, 0)
const SHRUB := Vector2i(4, 2)

var board: Board

func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST

func _draw() -> void:
	if board == null:
		return
	var cell_size := Vector2(board.tile_set.tile_size)
	for cell in board.get_used_cells():
		var center := board.map_to_local(cell)
		var destination := Rect2(center - cell_size * 0.5, cell_size)
		var forest := board.is_forest(cell)
		var tile := GRASS
		if board.is_blocked(cell):
			tile = STONES
		elif not forest and posmod(cell.x + cell.y * 3, 7) == 0:
			tile = PATH
		draw_rect(destination, Color("#8eb850"))
		_draw_tile(destination, tile)
		if forest:
			var tree := EVERGREEN if posmod(cell.x * 7 + cell.y * 11, 4) == 0 else SHRUB
			var canopy_size := cell_size * 0.75
			_draw_tile(Rect2(center - canopy_size * 0.5 - Vector2(0, roundf(cell_size.y * 0.10)), canopy_size), tree)

func _draw_tile(destination: Rect2, tile: Vector2i) -> void:
	draw_texture_rect_region(SHEET, destination, Rect2(Vector2(tile * 16), Vector2(16, 16)))
