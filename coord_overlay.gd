extends Node2D
class_name CoordOverlay

enum LabelMode {
	RAW,
	GRID,
	BOTH
}

@export var board_path: NodePath
@export var toggle_key: Key = KEY_F3
@export var cycle_mode_key: Key = KEY_F4
@export var start_visible: bool = false
@export var label_mode: LabelMode = LabelMode.BOTH
@export var font_size: int = 14
@export var walkable_color: Color = Color8(242, 242, 255, 242)
@export var blocked_color: Color = Color8(255, 115, 115, 242)
@export var grid_tint: Color = Color8(140, 255, 255, 255)
@export var outline_color: Color = Color8(0, 0, 0, 230)

var board: Board = null
var overlay_enabled: bool = false

func _ready() -> void:
	board = get_node_or_null(board_path) as Board
	if board == null:
		push_warning("CoordOverlay: board_path is not set to a Board node.")
	visible = true
	overlay_enabled = start_visible
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == toggle_key:
			overlay_enabled = not overlay_enabled
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if key_event.pressed and not key_event.echo and key_event.keycode == cycle_mode_key:
			label_mode = (label_mode + 1) % 3
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

func _draw() -> void:
	if not overlay_enabled or board == null:
		return

	var font: Font = ThemeDB.fallback_font
	var fs: int = font_size if font_size > 0 else ThemeDB.fallback_font_size
	var used_cells: Array[Vector2i] = board.get_used_cells()
	if used_cells.is_empty():
		return

	var min_cell: Vector2i = used_cells[0]
	for c in used_cells:
		var cell_for_min: Vector2i = c
		min_cell.x = min(min_cell.x, cell_for_min.x)
		min_cell.y = min(min_cell.y, cell_for_min.y)

	for c in used_cells:
		var cell: Vector2i = c
		var color: Color = blocked_color if board.is_blocked(cell) else walkable_color
		var grid_cell: Vector2i = cell - min_cell

		var world_pos: Vector2 = board.cell_to_world(cell)
		var local_pos: Vector2 = to_local(world_pos)
		if label_mode == LabelMode.RAW:
			var raw_text: String = "R(%d,%d)" % [cell.x, cell.y]
			_draw_centered_text(font, fs, local_pos, raw_text, color)
		elif label_mode == LabelMode.GRID:
			var grid_text: String = "G(%d,%d)" % [grid_cell.x, grid_cell.y]
			_draw_centered_text(font, fs, local_pos, grid_text, color * grid_tint)
		else:
			var raw_text: String = "R(%d,%d)" % [cell.x, cell.y]
			var norm_text: String = "G(%d,%d)" % [grid_cell.x, grid_cell.y]
			_draw_centered_text(font, fs - 1, local_pos + Vector2(0, -7), raw_text, color)
			_draw_centered_text(font, fs - 1, local_pos + Vector2(0, 9), norm_text, color * grid_tint)

func _draw_centered_text(font: Font, fs: int, center_pos: Vector2, text: String, color: Color) -> void:
	var draw_fs: int = max(8, fs)
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_fs)
	var pos: Vector2 = center_pos + Vector2(-size.x * 0.5, draw_fs * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_fs, 2, outline_color)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_fs, color)
