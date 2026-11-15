extends RefCounted
class_name EquipmentCatalog

const BASIC_SWORD = preload("res://equipment/weapons/basic_sword.tres")
const BASIC_AXE = preload("res://equipment/weapons/basic_axe.tres")
const BASIC_SPEAR = preload("res://equipment/weapons/basic_spear.tres")
const MACE = preload("res://equipment/weapons/mace.tres")
const DAGGER = preload("res://equipment/weapons/dagger.tres")
const LONGBOW = preload("res://equipment/weapons/longbow.tres")
const WAR_HAMMER = preload("res://equipment/weapons/war_hammer.tres")

const PADDED_GAMBESON = preload("res://equipment/armor/padded_gambeson.tres")
const MAIL_HAUBERK = preload("res://equipment/armor/mail_hauberk.tres")
const LAMELLAR_ARMOR = preload("res://equipment/armor/lamellar_armor.tres")
const COAT_OF_PLATES = preload("res://equipment/armor/coat_of_plates.tres")
const BRIGANDINE = preload("res://equipment/armor/brigandine.tres")
const STEEL_PLATE_HARNESS = preload("res://equipment/armor/steel_plate_harness.tres")


static func all_weapons() -> Array[WeaponDefinition]:
	return [
		BASIC_SWORD,
		BASIC_AXE,
		BASIC_SPEAR,
		MACE,
		DAGGER,
		LONGBOW,
		WAR_HAMMER,
	]


static func all_armor() -> Array[ArmorDefinition]:
	return [
		PADDED_GAMBESON,
		MAIL_HAUBERK,
		LAMELLAR_ARMOR,
		COAT_OF_PLATES,
		BRIGANDINE,
		STEEL_PLATE_HARNESS,
	]
