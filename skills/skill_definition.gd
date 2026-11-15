extends Resource
class_name SkillDefinition

enum EffectType { HEAL }
enum TargetType { SELF }

@export var display_name: String = "Skill"
@export_multiline var description: String = ""
@export var effect_type: EffectType = EffectType.HEAL
@export var target_type: TargetType = TargetType.SELF
@export_range(0, 99, 1) var healing_power: int = 0
@export var cannot_miss: bool = true
@export var cannot_crit: bool = true

func is_healing_skill() -> bool:
	return effect_type == EffectType.HEAL
