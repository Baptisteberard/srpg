extends RefCounted

const Gear = preload("res://equipment/equipment_catalog.gd")
const Heal = preload("res://skills/heal.tres")
const Definition = preload("res://units/unit_definition.gd")
const MAP_SPRITE_CLASSES = {
	"Spearman": "Soldier",
	"Archer": "Archer M",
	"Scout": "Thief",
	"Man-at-Arms": "Fighter",
}

# Stats and growths are ordered HP, Strength, Speed, Dexterity, Intellect.
const ENTRIES = [
	["Recruit", [20, 12, 8, 14, 4], [70, 40, 50, 55, 25], Gear.BASIC_SWORD, Gear.MAIL_HAUBERK, Color("#4d8ed3")],
	["Brigand", [24, 14, 5, 7, 1], [80, 60, 30, 35, 5], Gear.BASIC_AXE, Gear.PADDED_GAMBESON, Color("#ad773f")],
	["Spearman", [22, 11, 9, 12, 2], [65, 45, 45, 50, 15], Gear.BASIC_SPEAR, Gear.LAMELLAR_ARMOR, Color("#449678")],
	["Archer", [18, 9, 11, 18, 3], [50, 35, 55, 65, 20], Gear.LONGBOW, Gear.BRIGANDINE, Color("#82994b")],
	["Scout", [17, 8, 15, 20, 2], [45, 30, 70, 70, 15], Gear.DAGGER, Gear.PADDED_GAMBESON, Color("#9c70bf")],
	["Man-at-Arms", [25, 13, 7, 10, 3], [75, 50, 35, 40, 20], Gear.MACE, Gear.COAT_OF_PLATES, Color("#c18d50")],
	["Knight", [28, 16, 6, 8, 1], [85, 65, 25, 30, 10], Gear.WAR_HAMMER, Gear.STEEL_PLATE_HARNESS, Color("#7b8eb0")],
]

static func create(index: int, enemy: bool) -> UnitStats:
	var entry: Array = ENTRIES[index]
	var unit: UnitStats = Definition.new()
	unit.unit_class_name = entry[0]
	var stats: Array = entry[1]
	unit.health = stats[0]
	unit.strength = stats[1]
	unit.speed = stats[2]
	unit.dexterity = stats[3]
	unit.intellect = stats[4]
	var growths: Array = entry[2]
	unit.health_growth_rate = growths[0]
	unit.strength_growth_rate = growths[1]
	unit.speed_growth_rate = growths[2]
	unit.dexterity_growth_rate = growths[3]
	unit.intellect_growth_rate = growths[4]
	unit.equipped_weapon = entry[3]
	unit.equipped_armor = entry[4]
	if index == 0:
		unit.active_skills.append(Heal)
	var palette := "enemy" if enemy else "ally"
	var sprite_class: String = MAP_SPRITE_CLASSES.get(unit.unit_class_name, unit.unit_class_name)
	unit.fe8_map_sprite_animation = FE8MapSpriteImporter.load_animation(sprite_class, palette)
	if unit.fe8_map_sprite_animation == null:
		var color: Color = entry[5]
		unit.fe8_map_sprite_animation = _build_original_sprite(index, color, palette)
	return unit

static func _build_original_sprite(index: int, color: Color, palette: String) -> FE8MapSpriteAnimation:
	# Original compact pixel atlas. Rows match the shared unit animation player.
	var atlas := Image.create(128, 160, false, Image.FORMAT_RGBA8)
	var outline := Color("#242035")
	var metal := Color("#d2dbe0")
	var trim := Color("#ef6d58") if palette == "enemy" else Color("#7be0ff")
	for row in range(5):
		for frame in range(4):
			var origin := Vector2i(frame * 32, row * 32)
			var bob := (frame % 2) if row != 0 else int(frame == 1)
			var stride: int = [0, 1, 0, -1][frame] if row >= 2 else 0
			atlas.fill_rect(Rect2i(origin + Vector2i(10, 20 + bob + stride), Vector2i(5, 6)), outline)
			atlas.fill_rect(Rect2i(origin + Vector2i(17, 20 + bob - stride), Vector2i(5, 6)), outline)
			atlas.fill_rect(Rect2i(origin + Vector2i(9, 13 + bob), Vector2i(14, 9)), outline)
			atlas.fill_rect(Rect2i(origin + Vector2i(10, 14 + bob), Vector2i(12, 6)), color)
			atlas.fill_rect(Rect2i(origin + Vector2i(11, 19 + bob), Vector2i(10, 2)), trim)
			atlas.fill_rect(Rect2i(origin + Vector2i(11, 6 + bob), Vector2i(10, 8)), outline)
			atlas.fill_rect(Rect2i(origin + Vector2i(12, 7 + bob), Vector2i(8, 4)), metal if index >= 5 else color.lightened(0.3))
			if row != 4:
				atlas.fill_rect(Rect2i(origin + Vector2i(12 if row == 2 else 14, 11 + bob), Vector2i(5, 2)), Color("#f2b789"))
			var weapon_x := 6 if row == 2 else 24
			var weapon_height: int = [11, 12, 18, 13, 6, 10, 14][index]
			atlas.fill_rect(Rect2i(origin + Vector2i(weapon_x, 23 - weapon_height + bob), Vector2i(2, weapon_height)), outline)
			atlas.fill_rect(Rect2i(origin + Vector2i(weapon_x - 1, 23 - weapon_height + bob), Vector2i(4 if index in [1, 5, 6] else 2, 4)), metal)
	return FE8MapSpriteAnimation.new().configure(str(ENTRIES[index][0]), palette, ImageTexture.create_from_image(atlas))
