extends Control

const INK := Color("#101826")
const GOLD := Color("#ffdc89")
const FighterPack = preload("res://battle/fighter_animation_pack.gd")

var fighters: Array[Unit] = []
var striker: Unit
var target: Unit
var outcome := ""
var critical := false
var forest_encounter := false
var archer_pack: RefCounted
var attack_frame: Texture2D
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_NEAREST
	hide()

func begin(attacker: Unit, defender: Unit) -> void:
	fighters.assign([attacker, defender] if attacker.faction == Unit.Faction.PLAYER else [defender, attacker])
	forest_encounter = attacker.get_terrain_avoid() > 0 or defender.get_terrain_avoid() > 0
	if archer_pack == null and (_is_archer(attacker) or _is_archer(defender)):
		archer_pack = FighterPack.load_fletchling()
	outcome = ""
	show()
	queue_redraw()
	await create_tween().tween_interval(0.18).finished

func windup(attacker: Unit, defender: Unit, is_critical: bool) -> void:
	striker = attacker
	target = defender
	critical = is_critical
	outcome = ""
	progress = 0.0
	if _uses_pack(attacker):
		await _play_pack_phase("windup")
		var flight := create_tween()
		flight.tween_property(self, "progress", 1.0, 0.16)
		await flight.finished
		return
	var tween := create_tween()
	tween.tween_property(self, "progress", 0.35, 0.26 if critical else 0.18)
	tween.tween_property(self, "progress", 1.0, 0.20)
	await tween.finished

func impact(hit: bool, damage: int) -> void:
	outcome = ("CRITICAL  " if critical else "") + str(damage) if hit else "MISS"
	queue_redraw()
	if _uses_pack(striker):
		await _play_pack_phase("recovery")
	await create_tween().tween_interval(0.32).finished
	var recovery := create_tween()
	recovery.tween_property(self, "progress", 0.0, 0.20)
	await recovery.finished
	striker = null
	attack_frame = null
	target = null
	outcome = ""
	queue_redraw()

func close() -> void:
	fighters.clear()
	striker = null
	target = null
	hide()

func _is_archer(unit: Unit) -> bool:
	return unit != null and unit.unit_class_name == "Archer" and unit.equipped_weapon != null \
		and unit.equipped_weapon.weapon_type == &"Bow"

func _uses_pack(unit: Unit) -> bool:
	return archer_pack != null and _is_archer(unit)

func _play_pack_phase(phase: String) -> void:
	var mode := 6 if critical else 5
	for entry in archer_pack.modes[mode][phase]:
		attack_frame = entry[0]
		queue_redraw()
		await create_tween().tween_interval(entry[1]).finished

func _draw() -> void:
	if fighters.size() != 2 or size.x <= 0 or size.y <= 0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(960, 540))
	draw_rect(Rect2(0, 0, 960, 540), Color("#212742"))
	draw_circle(Vector2(730, 145), 55, Color("#ded2a1"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 350), Vector2(170, 180), Vector2(345, 320), Vector2(580, 205), Vector2(960, 335), Vector2(960, 440), Vector2(0, 440)]), Color("#393f60"))
	if forest_encounter:
		for index in range(13):
			var x := float(index * 83 - 27)
			var crown := float(155 + posmod(index * 67, 115))
			draw_rect(Rect2(x + 37, crown + 55, 12, 360 - crown - 55), Color("#38363b"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(x + 43, crown), Vector2(x + 89, crown + 124),
				Vector2(x - 3, crown + 124),
			]), Color("#2d514a") if index % 2 == 0 else Color("#355f52"))
	draw_rect(Rect2(0, 360, 960, 180), Color("#435745") if forest_encounter else Color("#59604b"))
	draw_line(Vector2(0, 360), Vector2(960, 360), Color("#829274"), 3)
	for index in range(2):
		var unit := fighters[index]
		if not is_instance_valid(unit):
			continue
		var facing := 1.0 if index == 0 else -1.0
		var origin := Vector2(242 if index == 0 else 718, 382)
		var weapon := String(unit.equipped_weapon.weapon_type).to_lower() if unit.equipped_weapon else "unarmed"
		var motion := progress if unit == striker else 0.0
		if unit == striker and not _uses_pack(unit):
			var reach := 18.0 if weapon == "bow" else (200.0 if weapon == "dagger" else 160.0)
			origin.x += facing * lerpf(-15.0, reach, motion)
		elif unit == target and not outcome.is_empty():
			origin.x -= facing * (35.0 if outcome == "MISS" else 15.0) * progress
		var tint := Color("#60b9ba") if index == 0 else Color("#dc846b")
		if unit == target and not outcome.is_empty() and outcome != "MISS":
			tint = tint.lerp(GOLD, progress * 0.5)
		if unit.current_hp == 0:
			origin.y += 25 * progress
			tint.a = 0.35
		var stage_scale := size / Vector2(960, 540)
		draw_set_transform(origin * stage_scale, 0.0, Vector2(facing, 1) * stage_scale)
		if _uses_pack(unit):
			var frame: Texture2D = attack_frame if unit == striker and attack_frame != null else archer_pack.modes[10]["windup"][0][0]
			# The source actor faces left. Mirror around the feet for the left slot.
			draw_set_transform(origin * stage_scale, 0.0, Vector2(-facing, 1) * stage_scale)
			var sprite_scale := 4.0
			draw_texture_rect(frame, Rect2(-Vector2(146, 104) * sprite_scale, frame.get_size() * sprite_scale), false,
				Color(1, 1, 1, tint.a))
		else:
			_draw_fighter(weapon, tint, motion)
		draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(960, 540))
		var x := 50.0 if index == 0 else 610.0
		_label(Vector2(x, 455), unit.get_display_name() + "  /  " + unit.get_class_display_name(), 20)
		draw_rect(Rect2(x, 469, 300, 12), INK)
		draw_rect(Rect2(x, 469, 300.0 * unit.current_hp / maxi(unit.health, 1), 12), tint)
		_label(Vector2(x, 510), "HP  %d / %d" % [unit.current_hp, unit.health], 18)
	if striker != null and target != null:
		if _uses_pack(striker) and outcome.is_empty() and progress > 0.0:
			var direction := 1.0 if striker == fighters[0] else -1.0
			var launch_x := 290.0 if direction > 0.0 else 670.0
			var arrow_tip := Vector2(launch_x + direction * 400.0 * progress, 294)
			draw_line(arrow_tip - Vector2(direction * 38.0, 0), arrow_tip, GOLD, 3.0)
		if outcome.is_empty() and critical:
			_label(Vector2(414, 115), "CRITICAL", 25)
		elif not outcome.is_empty():
			var impact_x := 695.0 if target == fighters[1] else 220.0
			if outcome != "MISS":
				draw_arc(Vector2(impact_x, 297), 40.0 * progress, -1.1, 1.1, 16, GOLD, 5.0, true)
			_label(Vector2(impact_x - 65, 205), outcome, 25)

func _draw_fighter(weapon: String, tint: Color, motion: float) -> void:
	var heavy := weapon in ["axe", "mace", "hammer"]
	var lean := Vector2(motion * 16.0, -sin(motion * PI) * 8.0)
	var shoulder := Vector2(8, -92) + lean
	draw_line(Vector2(-25, -49), Vector2(-39 - motion * 23, 0), INK, 22)
	draw_line(Vector2(19, -49), Vector2(34 + motion * 12, 0), INK, 22)
	draw_colored_polygon(PackedVector2Array([Vector2(-36, -98) + lean, Vector2(26, -99) + lean, Vector2(30, -47), Vector2(-29, -44)]), tint)
	draw_line(Vector2(-30, -54), Vector2(28, -54), INK, 8)
	draw_circle(Vector2(-10, -119) + lean, 22 if heavy else 18, INK)
	draw_rect(Rect2(Vector2(-12, -124) + lean, Vector2(22, 12)), tint.lightened(0.55))
	var hand := shoulder + Vector2(lerpf(12, 49, motion), lerpf(22, -2, motion))
	draw_line(shoulder, hand, tint.lightened(0.22), 16)
	var steel := Color("#dadfea")
	match weapon:
		"bow":
			draw_arc(hand, 31, -PI / 2, PI / 2, 20, GOLD, 5, true)
			draw_polyline(PackedVector2Array([hand + Vector2(0, -31), hand + Vector2(-26 * (1.0 - motion), 0), hand + Vector2(0, 31)]), steel, 2, true)
			if motion > 0.35:
				var arrow := hand + Vector2((motion - 0.35) * 600.0, 0)
				draw_line(arrow - Vector2(40, 0), arrow, GOLD, 3)
		"spear":
			draw_line(hand - Vector2(32, -10), hand + Vector2(82, -18), GOLD, 5)
			draw_line(hand + Vector2(70, -16), hand + Vector2(92, -20), steel, 8)
		_:
			var angle := lerpf(-2.35, 0.15 if heavy else -0.42, motion)
			var length := 30.0 if weapon == "dagger" or weapon == "unarmed" else 57.0
			var tip := hand + Vector2.from_angle(angle) * length
			draw_line(hand, tip, GOLD if heavy else steel, 6 if heavy else 8)
			if weapon == "mace":
				draw_circle(tip, 10, steel)
			elif weapon == "axe":
				var edge := Vector2.from_angle(angle + PI / 2)
				draw_colored_polygon(PackedVector2Array([tip - edge * 7, tip + edge * 18,
					tip + edge * 15 + Vector2.from_angle(angle) * 13, tip + Vector2.from_angle(angle) * 9]), steel)
			elif heavy:
				draw_line(tip - Vector2.from_angle(angle + PI / 2) * 13, tip + Vector2.from_angle(angle + PI / 2) * 13, steel, 13 if weapon == "hammer" else 9)
			elif weapon == "sword":
				draw_line(hand - Vector2(0, 9), hand + Vector2(0, 9), GOLD, 5)

func _label(position: Vector2, caption: String, font_size: int) -> void:
	draw_string(ThemeDB.fallback_font, position, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#f2edf0"))
