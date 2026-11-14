# Unit.gd
extends Area2D
class_name Unit

signal clicked(unit: Unit)
signal move_finished(unit: Unit)

enum Faction { PLAYER, ENEMY }

@export var faction: Faction = Faction.PLAYER
@export var unit_name: String = ""
@export var move_range: int = 8
@export_group("Stats")
@export var health: int = 20
@export var strength: int = 12
@export var speed: int = 0
@export_range(0, 100, 1) var precision: int = 100
@export var intellect: int = 0
@export var armor: int = 0
@export_group("Combat")
@export var attack_range: int = 1
@export var attack_lunge_time: float = 0.08
@export var attack_return_time: float = 0.12

@export var blocks_allies: bool = false   # allies can pass through by default
@export var blocks_enemies: bool = true  # enemies cannot pass through by default
@export var draw_hp_bar_in_unit: bool = false

var current_hp: int = -1
var tile_size_px: Vector2 = Vector2(64.0, 64.0)

func blocks_movement_for(mover_faction: Faction) -> bool:
	# If mover is same faction => "ally"
	if mover_faction == faction:
		return blocks_allies
	return blocks_enemies

var cell: Vector2i = Vector2i.ZERO
var has_acted: bool = false
var is_moving: bool = false

var sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("units")
	_sanitize_stats()
	if current_hp < 0:
		current_hp = health
	current_hp = clampi(current_hp, 0, health)
	queue_redraw()

func _sanitize_stats() -> void:
	health = maxi(1, health)
	strength = maxi(0, strength)
	speed = maxi(0, speed)
	precision = clampi(precision, 0, 100)
	intellect = maxi(0, intellect)
	armor = maxi(0, armor)

func set_stats(health_value: int, strength_value: int, speed_value: int, precision_value: int, intellect_value: int, armor_value: int, reset_current_hp: bool = true) -> void:
	health = health_value
	strength = strength_value
	speed = speed_value
	precision = precision_value
	intellect = intellect_value
	armor = armor_value
	_sanitize_stats()
	if reset_current_hp:
		current_hp = health
	else:
		current_hp = clampi(current_hp, 0, health)
	queue_redraw()

func set_display_name(new_name: String) -> void:
	unit_name = new_name.strip_edges()

func get_display_name() -> String:
	if unit_name.strip_edges() != "":
		return unit_name.strip_edges()
	return name

func _get_sprite() -> Sprite2D:
	if sprite == null:
		sprite = get_node("Sprite2D") as Sprite2D
	return sprite

func set_texture(tex: Texture2D) -> void:
	_get_sprite().texture = tex

func set_tile_size(tile_size: Vector2i) -> void:
	if tile_size.x > 0 and tile_size.y > 0:
		tile_size_px = Vector2(tile_size)
	queue_redraw()

func is_alive() -> bool:
	return current_hp > 0

func can_attack(target: Unit) -> bool:
	if target == null:
		return false
	if target == self:
		return false
	if not is_alive() or not target.is_alive():
		return false
	if target.faction == faction:
		return false
	return abs(cell.x - target.cell.x) + abs(cell.y - target.cell.y) <= attack_range

func get_physical_damage() -> int:
	return strength

func get_hit_chance_against(target: Unit) -> int:
	if target == null:
		return 0
	return clampi(precision - target.speed, 0, 100)

func take_damage(amount: int) -> int:
	if amount <= 0 or not is_alive():
		return 0
	var dmg: int = mini(amount, current_hp)
	current_hp -= dmg
	queue_redraw()
	return dmg

func play_attack_animation(target_world_pos: Vector2, done: Callable = Callable()) -> void:
	var start_pos: Vector2 = global_position
	var to_target: Vector2 = target_world_pos - start_pos
	var distance: float = to_target.length()
	if distance <= 0.001:
		if done.is_valid():
			done.call()
		return

	var dir: Vector2 = to_target / distance
	var max_lunge: float = max(8.0, min(tile_size_px.x, tile_size_px.y) * 0.35)
	var lunge_distance: float = min(distance * 0.55, max_lunge)
	var hit_pos: Vector2 = start_pos + dir * lunge_distance

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position", hit_pos, attack_lunge_time)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "global_position", start_pos, attack_return_time)
	tw.finished.connect(func() -> void:
		global_position = start_pos
		if done.is_valid():
			done.call()
	, CONNECT_ONE_SHOT)

func set_cell(new_cell: Vector2i, world_pos: Vector2) -> void:
	cell = new_cell
	global_position = world_pos

func set_selected(selected: bool) -> void:
	_get_sprite().scale = Vector2(1.15, 1.15) if selected else Vector2.ONE

func _draw() -> void:
	if not draw_hp_bar_in_unit:
		return

	# Draw HP bar near feet (bottom of the tile).
	var ratio: float = 0.0 if health <= 0 else clampf(float(current_hp) / float(health), 0.0, 1.0)
	var bar_w: float = clampf(tile_size_px.x * 0.72, 34.0, 92.0)
	var bar_h: float = 6.0
	var x0: float = -bar_w * 0.5
	var y0: float = (tile_size_px.y * 0.5) - bar_h - 3.0

	var team_color: Color = Color.from_hsv(210.0 / 360.0, 0.75, 1.0, 0.92)
	if faction == Faction.ENEMY:
		team_color = Color.from_hsv(0.0, 0.75, 1.0, 0.92)
	var track_color: Color = Color8(65, 65, 65, 220) # #414141
	draw_rect(Rect2(Vector2(x0, y0), Vector2(bar_w, bar_h)), track_color, true)

	var fill_w: float = max(0.0, (bar_w - 2.0) * ratio)
	if fill_w > 0.0:
		draw_rect(Rect2(Vector2(x0 + 1.0, y0 + 1.0), Vector2(fill_w, bar_h - 2.0)), team_color, true)

func _input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		viewport.set_input_as_handled()
		clicked.emit(self)

func move_along(path: Array[Vector2i], board: Node, step_time: float = 0.12) -> void:
	# board must provide cell_to_world(Vector2i) -> Vector2
	if path.is_empty():
		move_finished.emit(self)
		return

	is_moving = true
	var tw := create_tween()
	for c in path:
		tw.tween_property(self, "global_position", board.cell_to_world(c), step_time)

	tw.finished.connect(func ():
		cell = path[path.size() - 1]
		is_moving = false
		move_finished.emit(self)
		)
		
