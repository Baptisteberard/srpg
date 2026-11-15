extends CanvasLayer
class_name BattleHud

signal damage_preview_changed(damage_by_unit: Dictionary)
signal unit_visual_settings_changed(size_multiplier: float, vertical_offset: float)

const MIN_UNIT_SIZE_MULTIPLIER: float = 0.5
const MAX_UNIT_SIZE_MULTIPLIER: float = 2.0
const MIN_UNIT_VERTICAL_OFFSET: float = -64.0
const MAX_UNIT_VERTICAL_OFFSET: float = 64.0

var focused_unit: Unit
var preview_attacker: Unit
var preview_defender: Unit
var preview_attacker_cell: Vector2i = Vector2i.ZERO

var stats_panel: PanelContainer
var stats_scroll: ScrollContainer
var stats_label: RichTextLabel
var unit_visual_settings_panel: PanelContainer
var unit_size_slider: HSlider
var unit_size_value_label: Label
var unit_vertical_offset_slider: HSlider
var unit_vertical_offset_value_label: Label

var unit_size_multiplier: float = 1.0
var unit_vertical_offset: float = 0.0


func _ready() -> void:
	_build_stats_panel()
	_build_unit_visual_settings_panel()


func _build_unit_visual_settings_panel() -> void:
	unit_visual_settings_panel = PanelContainer.new()
	unit_visual_settings_panel.name = "UnitVisualSettingsPanel"
	unit_visual_settings_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	unit_visual_settings_panel.offset_left = -316.0
	unit_visual_settings_panel.offset_top = 16.0
	unit_visual_settings_panel.offset_right = -16.0
	unit_visual_settings_panel.offset_bottom = 154.0
	add_child(unit_visual_settings_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	unit_visual_settings_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "Unit display"
	title.add_theme_font_size_override("font_size", 16)
	rows.add_child(title)

	var controls := GridContainer.new()
	controls.columns = 3
	controls.add_theme_constant_override("h_separation", 8)
	controls.add_theme_constant_override("v_separation", 6)
	rows.add_child(controls)

	var size_label := Label.new()
	size_label.text = "Size"
	controls.add_child(size_label)

	unit_size_slider = HSlider.new()
	unit_size_slider.name = "UnitSizeSlider"
	unit_size_slider.custom_minimum_size.x = 150.0
	unit_size_slider.min_value = MIN_UNIT_SIZE_MULTIPLIER
	unit_size_slider.max_value = MAX_UNIT_SIZE_MULTIPLIER
	unit_size_slider.step = 0.05
	unit_size_slider.value = unit_size_multiplier
	unit_size_slider.value_changed.connect(_on_unit_size_changed)
	controls.add_child(unit_size_slider)

	unit_size_value_label = Label.new()
	unit_size_value_label.custom_minimum_size.x = 48.0
	unit_size_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.add_child(unit_size_value_label)

	var offset_label := Label.new()
	offset_label.text = "Y offset"
	controls.add_child(offset_label)

	unit_vertical_offset_slider = HSlider.new()
	unit_vertical_offset_slider.name = "UnitVerticalOffsetSlider"
	unit_vertical_offset_slider.custom_minimum_size.x = 150.0
	unit_vertical_offset_slider.min_value = MIN_UNIT_VERTICAL_OFFSET
	unit_vertical_offset_slider.max_value = MAX_UNIT_VERTICAL_OFFSET
	unit_vertical_offset_slider.step = 1.0
	unit_vertical_offset_slider.value = unit_vertical_offset
	unit_vertical_offset_slider.value_changed.connect(_on_unit_vertical_offset_changed)
	controls.add_child(unit_vertical_offset_slider)

	unit_vertical_offset_value_label = Label.new()
	unit_vertical_offset_value_label.custom_minimum_size.x = 48.0
	unit_vertical_offset_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.add_child(unit_vertical_offset_value_label)

	var reset_button := Button.new()
	reset_button.name = "ResetUnitVisualSettingsButton"
	reset_button.text = "Reset"
	reset_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset_button.pressed.connect(_on_reset_unit_visual_settings)
	rows.add_child(reset_button)
	_refresh_unit_visual_settings_labels()


func _on_unit_size_changed(value: float) -> void:
	unit_size_multiplier = value
	_refresh_unit_visual_settings_labels()
	unit_visual_settings_changed.emit(unit_size_multiplier, unit_vertical_offset)


func _on_unit_vertical_offset_changed(value: float) -> void:
	unit_vertical_offset = value
	_refresh_unit_visual_settings_labels()
	unit_visual_settings_changed.emit(unit_size_multiplier, unit_vertical_offset)


func _on_reset_unit_visual_settings() -> void:
	unit_size_slider.value = 1.0
	unit_vertical_offset_slider.value = 0.0


func _refresh_unit_visual_settings_labels() -> void:
	if unit_size_value_label != null:
		unit_size_value_label.text = "%d%%" % roundi(unit_size_multiplier * 100.0)
	if unit_vertical_offset_value_label != null:
		unit_vertical_offset_value_label.text = "%+d px" % roundi(unit_vertical_offset)


func focus_unit(unit: Unit) -> void:
	focused_unit = unit if unit != null and is_instance_valid(unit) else null
	refresh()


func show_combat_preview(attacker: Unit, defender: Unit, attacker_cell: Vector2i) -> void:
	if attacker == null or defender == null:
		clear_combat_preview()
		return
	var changed: bool = preview_attacker != attacker \
		or preview_defender != defender \
		or preview_attacker_cell != attacker_cell
	preview_attacker = attacker
	preview_defender = defender
	preview_attacker_cell = attacker_cell
	if changed:
		_emit_damage_preview()
		refresh()


func clear_combat_preview() -> void:
	if preview_attacker == null and preview_defender == null:
		return
	preview_attacker = null
	preview_defender = null
	preview_attacker_cell = Vector2i.ZERO
	damage_preview_changed.emit({})
	refresh()


func forget_unit(unit: Unit) -> void:
	if focused_unit == unit:
		focused_unit = null
	if preview_attacker == unit or preview_defender == unit:
		preview_attacker = null
		preview_defender = null
		preview_attacker_cell = Vector2i.ZERO
		damage_preview_changed.emit({})
	refresh()


func _emit_damage_preview() -> void:
	var damage_by_unit: Dictionary = {}
	var forecast: Dictionary = CombatResolver.forecast(preview_attacker, preview_defender, preview_attacker_cell)
	if bool(forecast.get("can_attack", false)):
		var attacker_damage: int = preview_attacker.current_hp - int(forecast["attacker_hp_after"])
		var defender_damage: int = preview_defender.current_hp - int(forecast["defender_hp_after"])
		if attacker_damage > 0:
			damage_by_unit[preview_attacker] = attacker_damage
		if defender_damage > 0:
			damage_by_unit[preview_defender] = defender_damage
	damage_preview_changed.emit(damage_by_unit)


func refresh() -> void:
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


func _build_stats_panel() -> void:
	stats_panel = PanelContainer.new()
	stats_panel.name = "UnitStatsPanel"
	stats_panel.visible = false
	add_child(stats_panel)

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
	stats_scroll.add_child(stats_label)


func _position_stats_panel_for_unit(unit: Unit) -> void:
	if stats_panel == null or stats_label == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var max_content_width: float = max(80.0, viewport_size.x - 48.0)
	var content_width: float = clampf(_measure_stats_text_width(max_content_width), 80.0, max_content_width)
	var content_height: float = _measure_stats_text_height(content_width)
	stats_label.custom_minimum_size = Vector2(content_width, content_height)
	stats_label.update_minimum_size()

	var panel_width: float = content_width + 16.0
	var desired_height: float = content_height + 16.0
	var panel_height: float = min(desired_height, max(120.0, viewport_size.y - 32.0))
	if stats_scroll != null:
		stats_scroll.custom_minimum_size = Vector2(content_width, panel_height - 16.0)

	stats_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var is_enemy: bool = unit != null and unit.faction == Unit.Faction.ENEMY
	var panel_x: float = viewport_size.x - panel_width - 16.0 if is_enemy else 16.0
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if is_enemy else HORIZONTAL_ALIGNMENT_LEFT
	var panel_y: float = viewport_size.y - panel_height - 16.0
	stats_panel.offset_left = panel_x
	stats_panel.offset_top = panel_y
	stats_panel.offset_right = panel_x + panel_width
	stats_panel.offset_bottom = panel_y + panel_height


func _measure_stats_text_width(max_content_width: float) -> float:
	var font: Font = stats_label.get_theme_font("font")
	var font_size: int = stats_label.get_theme_font_size("font_size")
	if font == null:
		return min(max_content_width, stats_label.get_combined_minimum_size().x)
	var measured: Vector2 = font.get_multiline_string_size(
		_strip_bbcode_tags(stats_label.text),
		HORIZONTAL_ALIGNMENT_LEFT,
		100000.0,
		font_size
	)
	return min(max_content_width, ceil(measured.x) + 2.0)


func _measure_stats_text_height(content_width: float) -> float:
	var font: Font = stats_label.get_theme_font("font")
	var font_size: int = stats_label.get_theme_font_size("font_size")
	if font == null:
		return stats_label.get_combined_minimum_size().y
	var plain_text: String = _strip_bbcode_tags(stats_label.text)
	var measured: Vector2 = font.get_multiline_string_size(
		plain_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		content_width,
		font_size
	)
	var line_count: int = max(1, plain_text.count("\n") + 1)
	var line_separation: int = stats_label.get_theme_constant("line_separation")
	return max(1.0, measured.y + float(line_separation * max(0, line_count - 1)))


func _strip_bbcode_tags(text_value: String) -> String:
	var expression: RegEx = RegEx.new()
	if expression.compile("\\[/?[^\\]]+\\]") != OK:
		return text_value
	return expression.sub(text_value, "", true)


func _build_default_unit_stats_text(unit: Unit) -> String:
	var crit_chance: int = int(unit.precision / 5)
	var attack_type: String = "Ranged Attack" if unit.attack_range > 1 else "Melee Attack"
	var attack_line: String = "Dmg: %d | Hit: %d%% | Crit: %d%%" % [unit.strength, unit.precision, crit_chance]
	if unit.attack_range > 1:
		attack_line += " | Rng: %d" % unit.attack_range
	return "[b]%s[/b]\nHP: %d/%d | Arm: %d | Evd: %d\n\n%s\n%s\n\nStats\nHP: %d | Str: %d | Spd: %d | Pre: %d | Int: %d" % [
		unit.get_display_name(),
		unit.current_hp,
		unit.health,
		unit.armor,
		unit.speed,
		attack_type,
		attack_line,
		unit.health,
		unit.strength,
		unit.speed,
		unit.precision,
		unit.intellect,
	]


func _build_combat_preview_text(attacker: Unit, defender: Unit, attacker_cell: Vector2i) -> String:
	var forecast: Dictionary = CombatResolver.forecast(attacker, defender, attacker_cell)
	if not bool(forecast.get("can_attack", false)):
		return "Combat Preview\nCannot attack from current position."

	var attacker_hit: int = attacker.get_hit_chance_against(defender)
	var defender_hit: int = defender.get_hit_chance_against(attacker)
	var attacker_damage: int = attacker.get_physical_damage()
	var defender_damage: int = defender.get_physical_damage()
	var attacker_hp_after: int = int(forecast["attacker_hp_after"])
	var defender_hp_after: int = int(forecast["defender_hp_after"])
	var first_striker: String = "Attacker" if bool(forecast["attacker_strikes_first"]) else "Defender"

	return "Combat Preview\nFirst strike: %s\n\nAttacker (%s)\nHP: %d/%d\nStrength: %d\nSpeed: %d\nPrecision: %d\nHit: %d%%\nDamage: %d\nHP After (if hits): %d\n\nDefender (%s)\nHP: %d/%d\nStrength: %d\nSpeed: %d\nPrecision: %d\nHit: %d%%\nDamage: %d\nHP After (if hits): %d" % [
		first_striker,
		_faction_label(attacker),
		attacker.current_hp,
		attacker.health,
		attacker.strength,
		attacker.speed,
		attacker.precision,
		attacker_hit,
		attacker_damage,
		attacker_hp_after,
		_faction_label(defender),
		defender.current_hp,
		defender.health,
		defender.strength,
		defender.speed,
		defender.precision,
		defender_hit,
		defender_damage,
		defender_hp_after,
	]

func _faction_label(unit: Unit) -> String:
	return "Enemy" if unit != null and unit.faction == Unit.Faction.ENEMY else "Player"
