# highlight.gd
@tool
extends Node2D
class_name HighlightMap

const DEFAULT_TILE_SIZE := Vector2i(128, 128)

@export var board_path: NodePath = NodePath("../Board")
@export var fill_color: Color = Color8(51, 153, 255, 125)
@export var border_color: Color = Color8(51, 153, 255, 255)
@export var attack_fill_color: Color = Color8(255, 0, 0, 125)
@export var attack_border_color: Color = Color8(255, 0, 0, 255)
@export var hover_fill_color: Color = Color8(255, 255, 255, 125)
@export var hover_border_color: Color = Color8(255, 255, 255, 255)
@export var path_color: Color = Color8(255, 255, 255, 255)
@export var path_node_color: Color = Color8(255, 255, 255, 255)
@export var path_width: float = 3.0
@export var path_endpoint_radius: float = 4.0
@export var path_turn_round_radius: float = 2.6
@export var cell_fill_scale: float = 0.90
@export var cell_corner_roundness: float = 0.20
@export var cell_corner_segments: int = 4

var board_ref: Board = null
var _cells: Array[Vector2i] = []
var _attack_cells: Array[Vector2i] = []
var _preview_path: Array[Vector2i] = []
var _hover_cell: Vector2i = Vector2i.ZERO
var _has_hover_cell: bool = false

func _ready() -> void:
	if board_ref == null:
		_try_bind_board_from_path()
	_sync_transform_from_board()
	z_index = 1
	queue_redraw()

func configure_from_board(board: Board) -> void:
	if board == null:
		return
	board_ref = board
	_sync_transform_from_board()
	queue_redraw()

func show_cells(cells: Array[Vector2i]) -> void:
	_cells.clear()
	for c in cells:
		_cells.append(c)
	queue_redraw()

func clear_cells() -> void:
	_cells.clear()
	_attack_cells.clear()
	queue_redraw()

func show_attack_cells(cells: Array[Vector2i]) -> void:
	_attack_cells.clear()
	for c in cells:
		_attack_cells.append(c)
	queue_redraw()

func set_hover_cell(cell: Vector2i) -> void:
	if _has_hover_cell and _hover_cell == cell:
		return
	_hover_cell = cell
	_has_hover_cell = true
	queue_redraw()

func clear_hover_cell() -> void:
	if not _has_hover_cell:
		return
	_has_hover_cell = false
	queue_redraw()

func set_preview_path(path_cells: Array[Vector2i]) -> void:
	_preview_path.clear()
	for c in path_cells:
		_preview_path.append(c)
	queue_redraw()

func clear_preview_path() -> void:
	if _preview_path.is_empty():
		return
	_preview_path.clear()
	queue_redraw()

func _draw() -> void:
	if board_ref == null:
		return
	if _cells.is_empty() and _attack_cells.is_empty() and _preview_path.is_empty():
		return

	var tile_size: Vector2 = _get_tile_size()
	var fill_scale: float = clampf(cell_fill_scale, 0.1, 1.0)
	var fill_size: Vector2 = tile_size * fill_scale
	var corner_radius: float = min(fill_size.x, fill_size.y) * clampf(cell_corner_roundness, 0.0, 0.48)
	var rect_offset: Vector2 = (tile_size - fill_size) * 0.5

	for cell in _cells:
		var tile_origin: Vector2 = board_ref.map_to_local(cell) - (tile_size * 0.5)
		var rect := Rect2(tile_origin + rect_offset, fill_size)
		_draw_cell_rect(rect, corner_radius, fill_color, border_color, 1.5)

	for cell in _attack_cells:
		var tile_origin_attack: Vector2 = board_ref.map_to_local(cell) - (tile_size * 0.5)
		var attack_rect := Rect2(tile_origin_attack + rect_offset, fill_size)
		_draw_cell_rect(attack_rect, corner_radius, attack_fill_color, attack_border_color, 1.5)

	if _has_hover_cell and (_cells.has(_hover_cell) or _attack_cells.has(_hover_cell)):
		var hover_origin: Vector2 = board_ref.map_to_local(_hover_cell) - (tile_size * 0.5)
		var hover_rect := Rect2(hover_origin + rect_offset, fill_size)
		_draw_cell_rect(hover_rect, corner_radius, hover_fill_color, hover_border_color, 1.8)

	if _preview_path.size() >= 2:
		var points: PackedVector2Array = PackedVector2Array()
		for c in _preview_path:
			points.append(board_ref.map_to_local(c))

		var smooth_points: PackedVector2Array = _build_smoothed_path(points)
		draw_polyline(smooth_points, path_color, path_width, true)
		var endpoint_r: float = max(2.5, path_endpoint_radius)
		draw_circle(points[0], endpoint_r, path_node_color)
		draw_circle(points[points.size() - 1], endpoint_r, path_node_color)

func _get_tile_size() -> Vector2:
	if board_ref == null or board_ref.tile_set == null:
		return Vector2(DEFAULT_TILE_SIZE)
	var ts: Vector2i = board_ref.tile_set.tile_size
	if ts.x <= 0 or ts.y <= 0:
		return Vector2(DEFAULT_TILE_SIZE)
	return Vector2(ts)

func _try_bind_board_from_path() -> void:
	var b: Board = get_node_or_null(board_path) as Board
	if b != null:
		board_ref = b

func _sync_transform_from_board() -> void:
	if board_ref == null:
		return
	if global_transform != board_ref.global_transform:
		global_transform = board_ref.global_transform

func _draw_cell_rect(rect: Rect2, radius: float, fill: Color, border: Color, border_width: float) -> void:
	var r: float = min(radius, min(rect.size.x, rect.size.y) * 0.5)
	if r <= 0.001:
		draw_rect(rect, fill, true)
		draw_rect(rect, border, false, border_width)
		return

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.border_width_bottom = int(ceil(border_width))
	sb.border_width_left = int(ceil(border_width))
	sb.border_width_right = int(ceil(border_width))
	sb.border_width_top = int(ceil(border_width))
	var rr: int = int(round(r))
	sb.corner_radius_top_left = rr
	sb.corner_radius_top_right = rr
	sb.corner_radius_bottom_right = rr
	sb.corner_radius_bottom_left = rr
	draw_style_box(sb, rect)

func _build_smoothed_path(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var out: PackedVector2Array = PackedVector2Array()
	out.append(points[0])

	for i in range(1, points.size() - 1):
		var prev_p: Vector2 = points[i - 1]
		var cur_p: Vector2 = points[i]
		var next_p: Vector2 = points[i + 1]

		var in_v: Vector2 = cur_p - prev_p
		var out_v: Vector2 = next_p - cur_p
		var in_len: float = in_v.length()
		var out_len: float = out_v.length()
		if in_len <= 0.001 or out_len <= 0.001:
			continue

		var in_n: Vector2 = in_v / in_len
		var out_n: Vector2 = out_v / out_len
		var turn_dot: float = in_n.dot(out_n)

		# Straight line: preserve original point.
		if turn_dot >= 0.999:
			out.append(cur_p)
			continue

		# Round the corner by trimming both segments then inserting a bezier arc.
		var r: float = min(path_turn_round_radius, min(in_len, out_len) * 0.45)
		r = max(0.5, r)
		var start_round: Vector2 = cur_p - in_n * r
		var end_round: Vector2 = cur_p + out_n * r
		out.append(start_round)

		var segs: int = max(3, int(4 + r / 2.0))
		for s in range(1, segs):
			var t: float = float(s) / float(segs)
			var a: Vector2 = start_round.lerp(cur_p, t)
			var b: Vector2 = cur_p.lerp(end_round, t)
			out.append(a.lerp(b, t))

		out.append(end_round)

	out.append(points[points.size() - 1])
	return out
