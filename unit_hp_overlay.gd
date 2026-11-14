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
@export var damage_color: Color = Color(1.0, 1.0, 1.0, 0.92)
@export_range(0.05, 2.0, 0.01) var damage_ease_duration: float = 0.45
@export_range(0.05, 2.0, 0.01) var death_fade_duration: float = 0.45
@export var preview_color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var preview_glow_color: Color = Color(1.0, 1.0, 1.0, 0.34)
@export_range(0.05, 2.0, 0.01) var preview_pulse_duration: float = 0.55

var _preview_damage_by_unit: Dictionary = {}
var _preview_elapsed: float = 0.0
var _last_hp_by_unit: Dictionary = {}
var _damage_trails: Dictionary = {}
var _death_effects: Dictionary = {}

func _ready() -> void:
	# Keep HP bars above board, units, trees and hover highlights.
	z_as_relative = false
	z_index = 100
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	for node in get_tree().get_nodes_in_group("units"):
		_track_unit(node as Unit)
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	if not _preview_damage_by_unit.is_empty():
		_preview_elapsed += delta
	_update_damage_trails(delta)
	_update_death_effects(delta)
	queue_redraw()
	if not _needs_continuous_redraw():
		set_process(false)

func _on_node_added(node: Node) -> void:
	if node is Unit:
		_track_unit(node as Unit)

func _on_node_removed(node: Node) -> void:
	if node is Unit:
		_preview_damage_by_unit.erase(node)
		_last_hp_by_unit.erase(node)
		_damage_trails.erase(node)
		queue_redraw()


func set_damage_previews(damage_by_unit: Dictionary) -> void:
	_preview_damage_by_unit.clear()
	for value in damage_by_unit:
		var unit: Unit = value as Unit
		if unit == null or not is_instance_valid(unit) or not unit.is_alive():
			continue
		var damage: int = clampi(int(damage_by_unit[value]), 0, unit.current_hp)
		if damage > 0:
			_preview_damage_by_unit[unit] = damage
	_preview_elapsed = 0.0
	if not _preview_damage_by_unit.is_empty():
		set_process(true)
	elif not _needs_continuous_redraw():
		set_process(false)
	queue_redraw()

func _track_unit(unit: Unit) -> void:
	if unit == null:
		return
	_last_hp_by_unit[unit] = unit.current_hp if unit.current_hp >= 0 else unit.health
	if not unit.health_changed.is_connected(_on_unit_health_changed):
		unit.health_changed.connect(_on_unit_health_changed)
	if not unit.position_changed.is_connected(_on_unit_visual_changed):
		unit.position_changed.connect(_on_unit_visual_changed)
	if not unit.visual_motion_started.is_connected(_on_unit_motion_started):
		unit.visual_motion_started.connect(_on_unit_motion_started)
	if not unit.visual_motion_finished.is_connected(_on_unit_motion_finished):
		unit.visual_motion_finished.connect(_on_unit_motion_finished)
	queue_redraw()


func _on_unit_health_changed(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var previous_hp: int = int(_last_hp_by_unit.get(unit, unit.current_hp))
	var current_hp: int = unit.current_hp
	_last_hp_by_unit[unit] = current_hp
	_preview_damage_by_unit.erase(unit)

	if current_hp < previous_hp:
		if current_hp <= 0:
			_damage_trails.erase(unit)
			_start_death_effect(unit, previous_hp)
		else:
			_damage_trails[unit] = {
				"start_hp": float(previous_hp),
				"target_hp": float(current_hp),
				"elapsed": 0.0,
			}
		set_process(true)
	elif current_hp > previous_hp:
		_damage_trails.erase(unit)
		_death_effects.erase(unit.get_instance_id())

	queue_redraw()


func _on_unit_visual_changed(_unit: Unit) -> void:
	queue_redraw()

func _on_unit_motion_started(_unit: Unit) -> void:
	set_process(true)
	queue_redraw()

func _on_unit_motion_finished(_unit: Unit) -> void:
	queue_redraw()
	call_deferred("_stop_processing_if_idle")

func _stop_processing_if_idle() -> void:
	if not _needs_continuous_redraw():
		set_process(false)


func _needs_continuous_redraw() -> bool:
	return not _preview_damage_by_unit.is_empty() \
		or not _damage_trails.is_empty() \
		or not _death_effects.is_empty() \
		or _has_active_motion()

func _has_active_motion() -> bool:
	for node in get_tree().get_nodes_in_group("units"):
		var unit: Unit = node as Unit
		if unit != null and unit.is_visually_moving:
			return true
	return false


func _update_damage_trails(delta: float) -> void:
	var finished: Array = []
	var duration: float = maxf(damage_ease_duration, 0.05)
	for value in _damage_trails:
		var unit: Unit = value as Unit
		if unit == null or not is_instance_valid(unit) or not unit.is_inside_tree():
			finished.append(value)
			continue
		var trail: Dictionary = _damage_trails[value]
		trail["elapsed"] = float(trail["elapsed"]) + delta
		if float(trail["elapsed"]) >= duration:
			finished.append(value)
		else:
			_damage_trails[value] = trail
	for value in finished:
		_damage_trails.erase(value)


func _update_death_effects(delta: float) -> void:
	var finished: Array[int] = []
	var total_duration: float = maxf(damage_ease_duration, 0.05) + maxf(death_fade_duration, 0.05)
	for value in _death_effects:
		var unit_id: int = int(value)
		var effect: Dictionary = _death_effects[unit_id]
		effect["elapsed"] = float(effect["elapsed"]) + delta
		if float(effect["elapsed"]) >= total_duration:
			finished.append(unit_id)
		else:
			_death_effects[unit_id] = effect
	for unit_id in finished:
		_death_effects.erase(unit_id)


func _start_death_effect(unit: Unit, previous_hp: int) -> void:
	var bar_w: float = clampf(unit.tile_size_px.x * bar_width_ratio, min_bar_width, max_bar_width)
	var anchor: Vector2 = to_local(unit.global_position)
	var team_color: Color = ally_color if unit.faction == Unit.Faction.PLAYER else enemy_color
	_death_effects[unit.get_instance_id()] = {
		"anchor": anchor,
		"bar_width": bar_w,
		"tile_height": unit.tile_size_px.y,
		"max_hp": maxi(unit.health, 1),
		"start_hp": float(maxi(previous_hp, 0)),
		"team_color": team_color,
		"elapsed": 0.0,
	}


func _damage_trail_hp(unit: Unit) -> float:
	if not _damage_trails.has(unit):
		return float(unit.current_hp)
	var trail: Dictionary = _damage_trails[unit]
	var duration: float = maxf(damage_ease_duration, 0.05)
	var progress: float = clampf(float(trail["elapsed"]) / duration, 0.0, 1.0)
	var eased: float = progress * progress * progress
	return lerpf(float(trail["start_hp"]), float(trail["target_hp"]), eased)

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
		if _death_effects.has(u.get_instance_id()):
			continue

		var bar_w: float = clampf(u.tile_size_px.x * bar_width_ratio, min_bar_width, max_bar_width)
		var anchor: Vector2 = to_local(u.global_position)
		var team_color: Color = ally_color if u.faction == Unit.Faction.PLAYER else enemy_color
		_draw_bar(
			anchor,
			bar_w,
			u.tile_size_px.y,
			float(u.health),
			float(u.current_hp),
			_damage_trail_hp(u),
			team_color,
			1.0,
			int(_preview_damage_by_unit.get(u, 0))
		)

	_draw_death_effects()


func _draw_death_effects() -> void:
	var damage_duration: float = maxf(damage_ease_duration, 0.05)
	var fade_duration: float = maxf(death_fade_duration, 0.05)
	for value in _death_effects:
		var effect: Dictionary = _death_effects[value]
		var elapsed: float = float(effect["elapsed"])
		var trail_hp: float = 0.0
		var alpha: float = 1.0
		if elapsed < damage_duration:
			var damage_progress: float = clampf(elapsed / damage_duration, 0.0, 1.0)
			var damage_eased: float = damage_progress * damage_progress * damage_progress
			trail_hp = lerpf(float(effect["start_hp"]), 0.0, damage_eased)
		else:
			var fade_progress: float = clampf((elapsed - damage_duration) / fade_duration, 0.0, 1.0)
			alpha = 1.0 - fade_progress * fade_progress * fade_progress

		_draw_bar(
			effect["anchor"],
			float(effect["bar_width"]),
			float(effect["tile_height"]),
			float(effect["max_hp"]),
			0.0,
			trail_hp,
			effect["team_color"],
			alpha,
			0
		)


func _draw_bar(
	anchor: Vector2,
	bar_w: float,
	tile_height: float,
	max_hp: float,
	current_hp: float,
	trail_hp: float,
	team_color: Color,
	alpha: float,
	preview_damage: int
) -> void:
	var safe_max_hp: float = maxf(max_hp, 1.0)
	var bar_h: float = bar_height
	var x0: float = anchor.x - (bar_w * 0.5)
	var y0: float = anchor.y + (tile_height * 0.5) - bar_h - y_offset
	var inner_w: float = maxf(bar_w - 2.0, 0.0)
	var current_ratio: float = clampf(current_hp / safe_max_hp, 0.0, 1.0)
	var trail_ratio: float = clampf(trail_hp / safe_max_hp, current_ratio, 1.0)
	var current_w: float = inner_w * current_ratio
	var trail_w: float = inner_w * trail_ratio

	var faded_track: Color = track_color
	faded_track.a *= alpha
	draw_rect(Rect2(Vector2(x0, y0), Vector2(bar_w, bar_h)), faded_track, true)

	if trail_w > current_w:
		var faded_damage: Color = damage_color
		faded_damage.a *= alpha
		draw_rect(
			Rect2(Vector2(x0 + 1.0 + current_w, y0 + 1.0), Vector2(trail_w - current_w, bar_h - 2.0)),
			faded_damage,
			true
		)

	if current_w > 0.0:
		var faded_team: Color = team_color
		faded_team.a *= alpha
		draw_rect(Rect2(Vector2(x0 + 1.0, y0 + 1.0), Vector2(current_w, bar_h - 2.0)), faded_team, true)

	if preview_damage <= 0 or current_hp <= 0.0:
		return
	var preview_hp: float = maxf(0.0, current_hp - float(preview_damage))
	var preview_start_w: float = inner_w * clampf(preview_hp / safe_max_hp, 0.0, current_ratio)
	var preview_w: float = current_w - preview_start_w
	if preview_w <= 0.0:
		return

	var duration: float = maxf(preview_pulse_duration, 0.05)
	var pulse: float = 0.5 - 0.5 * cos(TAU * _preview_elapsed / (duration * 2.0))
	var preview_alpha: float = lerpf(0.15, 1.0, pulse) * alpha
	var glow: Color = preview_glow_color
	glow.a *= preview_alpha
	var segment: Color = preview_color
	segment.a *= preview_alpha
	var preview_origin := Vector2(x0 + 1.0 + preview_start_w, y0 + 1.0)
	draw_rect(
		Rect2(preview_origin - Vector2.ONE, Vector2(preview_w + 2.0, bar_h)),
		glow,
		true
	)
	draw_rect(
		Rect2(preview_origin, Vector2(preview_w, bar_h - 2.0)),
		segment,
		true
	)
