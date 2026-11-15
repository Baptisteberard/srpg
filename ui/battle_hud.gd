extends CanvasLayer
class_name BattleHud

signal damage_preview_changed(damage_by_unit: Dictionary)
signal unit_visual_settings_changed(size_multiplier: float, vertical_offset: float)
signal unit_animation_settings_changed(animation_speed_multiplier: float, movement_speed_multiplier: float)
signal skill_requested(unit: Unit, skill: SkillDefinition)

const MIN_UNIT_SIZE_MULTIPLIER: float = 0.5
const MAX_UNIT_SIZE_MULTIPLIER: float = 2.0
const MIN_UNIT_VERTICAL_OFFSET: float = -64.0
const MAX_UNIT_VERTICAL_OFFSET: float = 64.0
const MIN_ANIMATION_SPEED_MULTIPLIER: float = 0.25
const MAX_ANIMATION_SPEED_MULTIPLIER: float = 3.0
const MIN_MOVEMENT_SPEED_MULTIPLIER: float = 0.25
const MAX_MOVEMENT_SPEED_MULTIPLIER: float = 2.0

var focused_unit: Unit
var preview_attacker: Unit
var preview_defender: Unit
var preview_attacker_cell: Vector2i = Vector2i.ZERO

var stats_panel: PanelContainer
var unit_info_layout: VBoxContainer
var unit_identity_label: RichTextLabel
var stats_tabs: TabContainer
var stats_scroll: ScrollContainer
var stats_label: RichTextLabel
var equipment_scroll: ScrollContainer
var equipment_label: RichTextLabel
var skills_scroll: ScrollContainer
var skills_label: RichTextLabel
var skill_action_button: Button
var progression_panel: PanelContainer
var progression_label: RichTextLabel
var progression_timer: Timer
var unit_visual_settings_toggle: Button
var unit_visual_settings_panel: PanelContainer
var unit_size_slider: HSlider
var unit_size_value_label: Label
var unit_vertical_offset_slider: HSlider
var unit_vertical_offset_value_label: Label
var unit_animation_speed_slider: HSlider
var unit_animation_speed_value_label: Label
var unit_movement_speed_slider: HSlider
var unit_movement_speed_value_label: Label

var unit_size_multiplier: float = 0.75
var unit_vertical_offset: float = -24.0
var unit_animation_speed_multiplier: float = 1.0
var unit_movement_speed_multiplier: float = 1.0


func _ready() -> void:
	_build_stats_panel()
	_build_progression_panel()
	_build_unit_visual_settings_panel()


func _build_progression_panel() -> void:
	progression_panel = PanelContainer.new()
	progression_panel.name = "ProgressionPanel"
	progression_panel.visible = false
	progression_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	progression_panel.offset_left = -220.0
	progression_panel.offset_top = 16.0
	progression_panel.offset_right = 220.0
	progression_panel.offset_bottom = 180.0
	add_child(progression_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	progression_panel.add_child(margin)

	progression_label = RichTextLabel.new()
	progression_label.name = "ProgressionLabel"
	progression_label.bbcode_enabled = true
	progression_label.fit_content = true
	progression_label.scroll_active = false
	progression_label.custom_minimum_size = Vector2(400.0, 120.0)
	progression_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(progression_label)

	progression_timer = Timer.new()
	progression_timer.name = "ProgressionTimer"
	progression_timer.one_shot = true
	progression_timer.wait_time = 3.0
	progression_timer.timeout.connect(_on_progression_timeout)
	add_child(progression_timer)


func show_progression_result(unit: Unit, experience_gained: int, level_results: Array[Dictionary]) -> void:
	if unit == null or not is_instance_valid(unit) or progression_panel == null:
		return
	var lines: Array[String] = [
		"[b]%s gained %d EXP[/b]" % [unit.get_display_name(), experience_gained]
	]
	for gains in level_results:
		lines.append("[b]Level %d![/b]" % int(gains.get("level", unit.level)))
		var stat_gains: Array[String] = []
		_append_growth_result(stat_gains, "HP", int(gains.get("health", 0)))
		_append_growth_result(stat_gains, "Strength", int(gains.get("strength", 0)))
		_append_growth_result(stat_gains, "Speed", int(gains.get("speed", 0)))
		_append_growth_result(stat_gains, "Dexterity", int(gains.get("dexterity", 0)))
		_append_growth_result(stat_gains, "Intellect", int(gains.get("intellect", 0)))
		lines.append(", ".join(stat_gains) if not stat_gains.is_empty() else "No characteristic gains")
	progression_label.text = "\n".join(lines)
	progression_panel.visible = true
	progression_timer.start()
	refresh()


func _append_growth_result(results: Array[String], stat_name: String, gain: int) -> void:
	if gain > 0:
		results.append("%s +%d" % [stat_name, gain])


func _on_progression_timeout() -> void:
	progression_panel.visible = false


func _build_unit_visual_settings_panel() -> void:
	unit_visual_settings_toggle = Button.new()
	unit_visual_settings_toggle.name = "UnitVisualSettingsToggle"
	unit_visual_settings_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	unit_visual_settings_toggle.offset_left = -156.0
	unit_visual_settings_toggle.offset_top = 16.0
	unit_visual_settings_toggle.offset_right = -16.0
	unit_visual_settings_toggle.offset_bottom = 52.0
	unit_visual_settings_toggle.toggle_mode = true
	unit_visual_settings_toggle.toggled.connect(_on_unit_visual_settings_toggled)
	add_child(unit_visual_settings_toggle)

	unit_visual_settings_panel = PanelContainer.new()
	unit_visual_settings_panel.name = "UnitVisualSettingsPanel"
	unit_visual_settings_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	unit_visual_settings_panel.offset_left = -316.0
	unit_visual_settings_panel.offset_top = 60.0
	unit_visual_settings_panel.offset_right = -16.0
	unit_visual_settings_panel.offset_bottom = 282.0
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
	title.text = "Unit options"
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

	var animation_speed_label := Label.new()
	animation_speed_label.text = "Anim speed"
	controls.add_child(animation_speed_label)

	unit_animation_speed_slider = HSlider.new()
	unit_animation_speed_slider.name = "UnitAnimationSpeedSlider"
	unit_animation_speed_slider.custom_minimum_size.x = 150.0
	unit_animation_speed_slider.min_value = MIN_ANIMATION_SPEED_MULTIPLIER
	unit_animation_speed_slider.max_value = MAX_ANIMATION_SPEED_MULTIPLIER
	unit_animation_speed_slider.step = 0.05
	unit_animation_speed_slider.value = unit_animation_speed_multiplier
	unit_animation_speed_slider.value_changed.connect(_on_unit_animation_speed_changed)
	controls.add_child(unit_animation_speed_slider)

	unit_animation_speed_value_label = Label.new()
	unit_animation_speed_value_label.custom_minimum_size.x = 48.0
	unit_animation_speed_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.add_child(unit_animation_speed_value_label)

	var movement_speed_label := Label.new()
	movement_speed_label.text = "Move speed"
	controls.add_child(movement_speed_label)

	unit_movement_speed_slider = HSlider.new()
	unit_movement_speed_slider.name = "UnitMovementSpeedSlider"
	unit_movement_speed_slider.custom_minimum_size.x = 150.0
	unit_movement_speed_slider.min_value = MIN_MOVEMENT_SPEED_MULTIPLIER
	unit_movement_speed_slider.max_value = MAX_MOVEMENT_SPEED_MULTIPLIER
	unit_movement_speed_slider.step = 0.05
	unit_movement_speed_slider.value = unit_movement_speed_multiplier
	unit_movement_speed_slider.value_changed.connect(_on_unit_movement_speed_changed)
	controls.add_child(unit_movement_speed_slider)

	unit_movement_speed_value_label = Label.new()
	unit_movement_speed_value_label.custom_minimum_size.x = 48.0
	unit_movement_speed_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.add_child(unit_movement_speed_value_label)

	var reset_button := Button.new()
	reset_button.name = "ResetUnitSettingsButton"
	reset_button.text = "Reset"
	reset_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset_button.pressed.connect(_on_reset_unit_visual_settings)
	rows.add_child(reset_button)
	_refresh_unit_visual_settings_labels()
	_set_unit_visual_menu_open(false)


func _on_unit_visual_settings_toggled(is_open: bool) -> void:
	_set_unit_visual_menu_open(is_open)


func _set_unit_visual_menu_open(is_open: bool) -> void:
	unit_visual_settings_panel.visible = is_open
	unit_visual_settings_toggle.text = "Unit options ▲" if is_open else "Unit options ▼"
	var end_turn_button := get_node_or_null("EndTurnButton") as Button
	if end_turn_button != null:
		end_turn_button.offset_top = 298.0 if is_open else 68.0
		end_turn_button.offset_bottom = 344.0 if is_open else 114.0


func _on_unit_size_changed(value: float) -> void:
	unit_size_multiplier = value
	_refresh_unit_visual_settings_labels()
	unit_visual_settings_changed.emit(unit_size_multiplier, unit_vertical_offset)


func _on_unit_vertical_offset_changed(value: float) -> void:
	unit_vertical_offset = value
	_refresh_unit_visual_settings_labels()
	unit_visual_settings_changed.emit(unit_size_multiplier, unit_vertical_offset)


func _on_unit_animation_speed_changed(value: float) -> void:
	unit_animation_speed_multiplier = value
	_refresh_unit_visual_settings_labels()
	unit_animation_settings_changed.emit(unit_animation_speed_multiplier, unit_movement_speed_multiplier)


func _on_unit_movement_speed_changed(value: float) -> void:
	unit_movement_speed_multiplier = value
	_refresh_unit_visual_settings_labels()
	unit_animation_settings_changed.emit(unit_animation_speed_multiplier, unit_movement_speed_multiplier)


func _on_reset_unit_visual_settings() -> void:
	unit_size_slider.value = 0.75
	unit_vertical_offset_slider.value = -24.0
	unit_animation_speed_slider.value = 1.0
	unit_movement_speed_slider.value = 1.0


func _refresh_unit_visual_settings_labels() -> void:
	if unit_size_value_label != null:
		unit_size_value_label.text = "%d%%" % roundi(unit_size_multiplier * 100.0)
	if unit_vertical_offset_value_label != null:
		unit_vertical_offset_value_label.text = "%+d px" % roundi(unit_vertical_offset)
	if unit_animation_speed_value_label != null:
		unit_animation_speed_value_label.text = "%d%%" % roundi(unit_animation_speed_multiplier * 100.0)
	if unit_movement_speed_value_label != null:
		unit_movement_speed_value_label.text = "%d%%" % roundi(unit_movement_speed_multiplier * 100.0)


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
	if stats_panel == null \
	or unit_identity_label == null \
	or stats_label == null \
	or equipment_label == null \
	or skills_label == null:
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
		_refresh_unit_window(preview_side_unit)
		_position_stats_panel_for_unit(preview_side_unit)
		return

	if focused_unit == null or not is_instance_valid(focused_unit) or not focused_unit.is_alive():
		stats_panel.visible = false
		unit_identity_label.text = ""
		stats_label.text = ""
		equipment_label.text = ""
		skills_label.text = ""
		_refresh_skill_action_button(null)
		return

	stats_panel.visible = true
	_refresh_unit_window(focused_unit)
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

	unit_info_layout = VBoxContainer.new()
	unit_info_layout.add_theme_constant_override("separation", 6)
	unit_info_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_info_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(unit_info_layout)

	unit_identity_label = RichTextLabel.new()
	unit_identity_label.name = "UnitIdentityLabel"
	unit_identity_label.bbcode_enabled = true
	unit_identity_label.scroll_active = false
	unit_identity_label.fit_content = true
	unit_identity_label.custom_minimum_size.y = 42.0
	unit_identity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_identity_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	unit_info_layout.add_child(unit_identity_label)

	stats_tabs = TabContainer.new()
	stats_tabs.name = "UnitInfoTabs"
	stats_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	unit_info_layout.add_child(stats_tabs)

	var characteristics_tab := _create_unit_info_tab("Characteristics", "CharacteristicsLabel")
	stats_scroll = characteristics_tab["scroll"] as ScrollContainer
	stats_label = characteristics_tab["label"] as RichTextLabel

	var equipment_tab := _create_unit_info_tab("Equipment", "EquipmentLabel")
	equipment_scroll = equipment_tab["scroll"] as ScrollContainer
	equipment_label = equipment_tab["label"] as RichTextLabel

	var skills_tab := _create_unit_info_tab("Skills", "SkillsLabel")
	skills_scroll = skills_tab["scroll"] as ScrollContainer
	skills_label = skills_tab["label"] as RichTextLabel
	skill_action_button = Button.new()
	skill_action_button.name = "SkillActionButton"
	skill_action_button.visible = false
	skill_action_button.pressed.connect(_on_skill_action_pressed)
	unit_info_layout.add_child(skill_action_button)
	stats_tabs.tab_changed.connect(_on_unit_info_tab_changed)
	stats_tabs.current_tab = 0


func _create_unit_info_tab(tab_name: String, label_name: String) -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_tabs.add_child(scroll)

	var label := RichTextLabel.new()
	label.name = label_name
	label.bbcode_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.fit_content = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.add_theme_constant_override("line_separation", -4)
	scroll.add_child(label)
	return {"scroll": scroll, "label": label}


func _position_stats_panel_for_unit(unit: Unit) -> void:
	if stats_panel == null or stats_label == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var max_content_width: float = max(300.0, viewport_size.x - 48.0)
	var measured_width: float = maxf(
		_measure_label_text_width(unit_identity_label, max_content_width),
		maxf(
			_measure_label_text_width(stats_label, max_content_width),
			maxf(
				_measure_label_text_width(equipment_label, max_content_width),
				_measure_label_text_width(skills_label, max_content_width)
			)
		)
	)
	var content_width: float = clampf(maxf(300.0, measured_width), 300.0, max_content_width)
	var stats_height: float = _measure_label_text_height(stats_label, content_width)
	var equipment_height: float = _measure_label_text_height(equipment_label, content_width)
	var skills_height: float = _measure_label_text_height(skills_label, content_width)
	var content_height: float = maxf(stats_height, maxf(equipment_height, skills_height))
	var identity_height: float = maxf(42.0, _measure_label_text_height(unit_identity_label, content_width))
	_set_unit_info_label_size(unit_identity_label, content_width, identity_height)
	_set_unit_info_label_size(stats_label, content_width, stats_height)
	_set_unit_info_label_size(equipment_label, content_width, equipment_height)
	_set_unit_info_label_size(skills_label, content_width, skills_height)

	var panel_width: float = content_width + 16.0
	var desired_height: float = maxf(220.0, content_height + identity_height + 64.0)
	var panel_height: float = min(desired_height, max(220.0, viewport_size.y - 32.0))
	var tabs_height: float = maxf(140.0, panel_height - identity_height - 22.0)
	stats_tabs.custom_minimum_size = Vector2(content_width, tabs_height)
	var scroll_height: float = maxf(100.0, tabs_height - 36.0)
	for scroll in [stats_scroll, equipment_scroll, skills_scroll]:
		if scroll != null:
			scroll.custom_minimum_size = Vector2(content_width, scroll_height)

	stats_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var is_enemy: bool = unit != null and unit.faction == Unit.Faction.ENEMY
	var panel_x: float = viewport_size.x - panel_width - 16.0 if is_enemy else 16.0
	var alignment := HORIZONTAL_ALIGNMENT_RIGHT if is_enemy else HORIZONTAL_ALIGNMENT_LEFT
	unit_identity_label.horizontal_alignment = alignment
	stats_label.horizontal_alignment = alignment
	equipment_label.horizontal_alignment = alignment
	skills_label.horizontal_alignment = alignment
	var panel_y: float = viewport_size.y - panel_height - 16.0
	stats_panel.offset_left = panel_x
	stats_panel.offset_top = panel_y
	stats_panel.offset_right = panel_x + panel_width
	stats_panel.offset_bottom = panel_y + panel_height


func _set_unit_info_label_size(label: RichTextLabel, width: float, height: float) -> void:
	label.custom_minimum_size = Vector2(width, height)
	label.update_minimum_size()


func _measure_label_text_width(label: RichTextLabel, max_content_width: float) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	if font == null:
		return min(max_content_width, label.get_combined_minimum_size().x)
	var measured: Vector2 = font.get_multiline_string_size(
		_strip_bbcode_tags(label.text),
		HORIZONTAL_ALIGNMENT_LEFT,
		100000.0,
		font_size
	)
	return min(max_content_width, ceil(measured.x) + 2.0)


func _measure_label_text_height(label: RichTextLabel, content_width: float) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	if font == null:
		return label.get_combined_minimum_size().y
	var plain_text: String = _strip_bbcode_tags(label.text)
	var measured: Vector2 = font.get_multiline_string_size(
		plain_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		content_width,
		font_size
	)
	var line_count: int = max(1, plain_text.count("\n") + 1)
	var line_separation: int = label.get_theme_constant("line_separation")
	return max(1.0, measured.y + float(line_separation * max(0, line_count - 1)))


func _refresh_unit_window(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		unit_identity_label.text = ""
		stats_label.text = ""
		equipment_label.text = ""
		skills_label.text = ""
		return
	unit_identity_label.text = "[b]%s[/b]\nClass: %s | Level %d | EXP %d/%d" % [
		unit.get_display_name(),
		unit.get_class_display_name(),
		unit.level,
		unit.experience,
		Unit.EXPERIENCE_PER_LEVEL,
	]
	stats_label.text = _build_characteristics_text(unit)
	equipment_label.text = _build_equipment_text(unit)
	skills_label.text = _build_skills_text(unit)
	_refresh_skill_action_button(unit)


func _strip_bbcode_tags(text_value: String) -> String:
	var expression: RegEx = RegEx.new()
	if expression.compile("\\[/?[^\\]]+\\]") != OK:
		return text_value
	return expression.sub(text_value, "", true)


func _build_characteristics_text(unit: Unit) -> String:
	return "[b]Health[/b]: %d    Growth: %d%%\n[b]Strength[/b]: %d    Growth: %d%%\n[b]Speed[/b]: %d    Growth: %d%%\n[b]Dexterity[/b]: %d    Growth: %d%%\n[b]Intellect[/b]: %d    Growth: %d%%" % [
		unit.health,
		unit.health_growth_rate,
		unit.strength,
		unit.strength_growth_rate,
		unit.speed,
		unit.speed_growth_rate,
		unit.dexterity,
		unit.dexterity_growth_rate,
		unit.intellect,
		unit.intellect_growth_rate,
	]


func _build_equipment_text(unit: Unit) -> String:
	var weapon_text := "None"
	if unit.equipped_weapon != null:
		weapon_text = "%s (%s)\nDamage: +%d | Weight: %d | Range: %d–%d\nBase Hit: %d%% | Base Crit: %d%%" % [
			unit.equipped_weapon.display_name,
			str(unit.equipped_weapon.weapon_type),
			unit.equipped_weapon.damage,
			unit.equipped_weapon.weight,
			unit.minimum_attack_range,
			unit.attack_range,
			unit.equipped_weapon.base_hit,
			unit.equipped_weapon.base_crit,
		]

	var armor_text := "None"
	if unit.equipped_armor != null:
		armor_text = "%s (%s)\nArmor: +%d | Weight: %d" % [
			unit.equipped_armor.display_name,
			str(unit.equipped_armor.armor_type),
			unit.equipped_armor.armor_value,
			unit.equipped_armor.weight,
		]

	return "[b]Weapon[/b]\n%s\n\n[b]Armor[/b]\n%s\n\n[b]Load[/b]\nTotal Weight: %d | Penalty: %d\nBattle Speed: %d\n\n[b]Shield[/b]\nNone" % [
		weapon_text,
		armor_text,
		unit.get_total_weight(),
		unit.get_weight_penalty(),
		unit.get_battle_speed(),
	]


func _build_skills_text(unit: Unit) -> String:
	var attack_name := "Unarmed Attack"
	if unit.equipped_weapon != null:
		attack_name = "%s Attack" % str(unit.equipped_weapon.weapon_type)
	var active_lines: Array[String] = []
	for skill in unit.active_skills:
		if skill != null and skill.is_healing_skill():
			active_lines.append("%s: Heal self for %d HP (cannot miss or crit)" % [
				skill.display_name,
				unit.get_healing_amount(skill),
			])
	var active_text := "None" if active_lines.is_empty() else "\n".join(active_lines)
	return "[b]Weapon Attack[/b]\n%s\nPhysical Power: %d (Strength %d + Weapon %d)\nAccuracy: %d | Base Crit: %d%%\n\n[b]Active Skills[/b]\n%s\n\n[b]Passive Skills[/b]\nNone" % [
		attack_name,
		unit.get_physical_damage(),
		unit.strength,
		unit.get_weapon_damage(),
		unit.get_accuracy(),
		unit.get_weapon_base_crit(),
		active_text,
	]

func _on_unit_info_tab_changed(_tab: int) -> void:
	_refresh_skill_action_button(focused_unit)

func _refresh_skill_action_button(unit: Unit) -> void:
	if skill_action_button == null:
		return
	var heal_skill: SkillDefinition = null
	if unit != null and is_instance_valid(unit):
		for skill in unit.active_skills:
			if skill != null and skill.is_healing_skill():
				heal_skill = skill
				break
	var on_skills_tab := stats_tabs != null and stats_tabs.current_tab == 2
	var is_player := unit != null and is_instance_valid(unit) and unit.faction == Unit.Faction.PLAYER
	skill_action_button.visible = on_skills_tab and heal_skill != null and is_player
	if not skill_action_button.visible:
		return
	skill_action_button.text = "Use %s on self" % heal_skill.display_name
	skill_action_button.disabled = unit.has_acted or unit.current_hp >= unit.health
	skill_action_button.set_meta("skill", heal_skill)

func _on_skill_action_pressed() -> void:
	if focused_unit == null or not is_instance_valid(focused_unit):
		return
	var skill := skill_action_button.get_meta("skill", null) as SkillDefinition
	if skill != null:
		skill_requested.emit(focused_unit, skill)
