extends Node2D
class_name UnitHpOverlay

@export var bar_height: float = 6.0
@export var y_offset: float = 3.0
@export var bar_width_ratio: float = 0.72
@export var min_bar_width: float = 34.0
@export var max_bar_width: float = 92.0
@export var track_color: Color = Color8(65, 65, 65, 220)
@export var ally_color: Color = Color.from_hsv(210.0 / 360.0, 0.75, 1.0, 0.92)
@export var enemy_color: Color = Color.from_hsv(0.0, 0.75, 1.0, 0.92)

func _ready() -> void:
	# Keep HP bars above board, units, trees and hover highlights.
	z_as_relative = false
	z_index = 100
	set_process(true)
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("units")
	for n in nodes:
		var u: Unit = n as Unit
		if u == null:
			continue
		if not u.is_inside_tree() or not u.visible:
			continue
		if u.health <= 0:
			continue

		var ratio: float = clampf(float(u.current_hp) / float(u.health), 0.0, 1.0)
		var bar_w: float = clampf(u.tile_size_px.x * bar_width_ratio, min_bar_width, max_bar_width)
		var bar_h: float = bar_height
		var anchor: Vector2 = to_local(u.global_position)
		var x0: float = anchor.x - (bar_w * 0.5)
		var y0: float = anchor.y + (u.tile_size_px.y * 0.5) - bar_h - y_offset

		draw_rect(Rect2(Vector2(x0, y0), Vector2(bar_w, bar_h)), track_color, true)
		var fill_w: float = max(0.0, (bar_w - 2.0) * ratio)
		if fill_w > 0.0:
			var team_color: Color = ally_color
			if u.faction == Unit.Faction.ENEMY:
				team_color = enemy_color
			draw_rect(Rect2(Vector2(x0 + 1.0, y0 + 1.0), Vector2(fill_w, bar_h - 2.0)), team_color, true)
