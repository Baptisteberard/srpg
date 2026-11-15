extends Resource
class_name UnitStats

# Kept as a compatibility base for resources created by the prototype.
# New encounter data should use UnitDefinition.
@export_group("Identity")
@export var display_name: String = ""
@export var unit_class_name: String = "Unclassed"

@export_group("Progression")
@export_range(1, 99, 1) var level: int = 1
@export_range(0, 99, 1) var experience: int = 0

@export_group("Core Stats")
@export var health: int = 20
@export var strength: int = 12
@export var speed: int = 0
@export_range(0, 100, 1) var dexterity: int = 100
@export var intellect: int = 0
@export var armor: int = 0

@export_group("Equipment")
@export var equipped_weapon: WeaponDefinition
@export var equipped_armor: ArmorDefinition

@export_group("Skills")
@export var active_skills: Array[SkillDefinition] = []

@export_group("Growth Rates")
@export_range(0, 300, 1) var health_growth_rate: int = 60
@export_range(0, 300, 1) var strength_growth_rate: int = 40
@export_range(0, 300, 1) var speed_growth_rate: int = 40
@export_range(0, 300, 1) var dexterity_growth_rate: int = 40
@export_range(0, 300, 1) var intellect_growth_rate: int = 20

@export_group("Movement")
@export var move_range: int = 8
@export var blocks_allies: bool = false
@export var blocks_enemies: bool = true

@export_group("Combat")
@export var minimum_attack_range: int = 1
@export var attack_range: int = 1
@export var flat_hit_modifier: int = 0
@export var flat_crit_modifier: int = 0
@export var flat_evasion_modifier: int = 0
@export var attack_lunge_time: float = 0.08
@export var attack_return_time: float = 0.12

@export_group("Visuals")
@export var texture: Texture2D
@export var fe8_map_sprite_animation: FE8MapSpriteAnimation
