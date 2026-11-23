# GDD Implementation Status

This file compares the target rules in the GDD with the current prototype.

Status meanings:

- **Implemented** — usable in the game and covered by the current test suite.
- **Partial** — some data or prototype behavior exists, but it does not satisfy
  the complete GDD rule.
- **Not implemented** — design only; no working game system exists yet.
- **Undecided** — intentionally has no approved final rule.

## Characteristics and interface

| GDD feature | Status | Current prototype |
| --- | --- | --- |
| Health | Implemented | Maximum and current HP, damage, HP bars, and defeat are functional. |
| Strength | Partial | Adds to physical Weapon Damage and offsets equipped weight. Other Strength requirements and modifiers are not implemented. |
| Speed | Partial | Feeds Battle Speed after the equipped-weight penalty. Its future Attack Speed role is not implemented. |
| Dexterity | Partial | Used by accuracy and critical chance. Block and Parry effects are not implemented. |
| Intellect | Partial | Stored and displayed, but has no magical-damage or healing behavior. |
| Armor | Partial | Equipped Armor reduces physical damage. Magical damage is not implemented, and the legacy base Armor field remains for compatibility. |
| Five personal growth rates | Implemented | Health, Strength, Speed, Dexterity, and Intellect rates are editable, displayed, and rolled independently. |
| Unit name and class header | Implemented | The focused unit's individual name and displayed class appear above the tabs. |
| Characteristics tab | Implemented | Shows only the five characteristics and their growth rates. |
| Equipment tab | Partial | Displays the equipped weapon, armor, damage, protection, range, weight, Weight Penalty, and Battle Speed. Inventory management, shields, and requirements do not exist. |
| Skills tab | Partial | Displays the full Hit and Crit formulas, final odds against a previewed target, the equipped Weapon Attack, and data-driven active skills. The primary Recruit can use the self-target Heal skill; a general targeting interface does not exist. |

## Weight and derived combat values

| GDD feature | Status | Current prototype |
| --- | --- | --- |
| Equipment Total Weight | Partial | Equipped weapon and armor weight are summed. Shield and accessory weight await those systems. |
| Strength reducing Weight Penalty | Implemented | `max(0, Total Weight - Strength)` is used at runtime. |
| Battle Speed | Implemented | `max(0, Speed - Weight Penalty)` is used for current evasion and legacy initiative. |
| Terrain Avoid and final Evasion | Partial | Forest tiles grant +20 Avoid, and final Evasion includes Battle Speed, Terrain Avoid, and flat modifiers. Other terrain types have no Avoid values yet. |
| Attack Speed formula | Not implemented | Weapon skills do not yet contain Base Attack Speed. |
| Exact effect of Attack Speed | Undecided | No approved strike-order or follow-up rule exists. |

## Attacks, accuracy, critical hits, and damage

| GDD feature | Status | Current prototype |
| --- | --- | --- |
| Weapon-granted Weapon Attack | Partial | Equipped weapons supply the displayed attack name, damage, weight, and range, but the attack remains hard-coded rather than a granted skill resource. |
| Automatic defensive Weapon Attack | Partial | Legacy reciprocal attacks exist, but their behavior is not the approved target rule. Exact target timing remains undecided. |
| GDD hit formula | Implemented | Weapon Attacks use `clamp(Base Hit + Dexterity + flat Hit - target Evasion, 0, 100)`, including forest Avoid. |
| Cannot-miss property | Not implemented | No skill property system exists. |
| Critical chance formula | Implemented | After a hit, Weapon Attacks roll `clamp(Base Crit + floor(Dexterity / 4) + flat Crit - target Evasion, 0, 100)`. |
| Critical damage | Implemented | Critical Weapon Attacks deal `2 × Final Damage`, after Armor reduction. |
| Physical formula | Partial | Strength, Weapon Damage, and target Armor are implemented. Skill Power and flat modifiers do not exist. |
| Magical formula | Not implemented | Intellect and magical actions have no combat implementation. |
| Single Armor defense | Partial | Armor reduces physical damage. Magical attacks do not exist yet, so magical mitigation is not exercised. |
| Healing formula | Implemented | The self-target Heal skill restores `max(1, Intellect + Weapon Healing Bonus + Skill Healing Power)`, cannot miss or crit, and is capped at maximum HP. |
| Shared forecast and resolution math | Partial | Forecast and resolution share equipped physical-power, Armor, and range calculations. The full skill pipeline is not implemented. |
| Strike resolution pipeline | Partial | Hit and critical rolls, equipped physical damage, Armor reduction, HP loss, healing, and defeat exist. Block, Parry, and a general effect pipeline do not. |

## Equipment

| GDD feature | Status | Current prototype |
| --- | --- | --- |
| Weapon slot and weapon data | Partial | Seven weapon resources provide type, damage, weight, range, Base Hit, and Base Crit. Attack speed, requirements, and granted skill resources remain. |
| Armor slot and armor data | Partial | Six armor resources provide historical type, Armor value, and weight. Requirements and inventory management remain. |
| Shield or off-hand slot | Not implemented | No shield item or off-hand system exists. |
| Accessories | Not implemented | Reserved as a future extension. |
| Class and characteristic requirements | Not implemented | Prototype loadouts equip items directly without eligibility checks. |

## Skills and defensive reactions

| GDD feature | Status | Current prototype |
| --- | --- | --- |
| Data-driven Weapon Attacks | Not implemented | Basic attacks are hard-coded. |
| Active skills | Not implemented | No skill selection, targeting, cost, cooldown, or use limit exists. |
| Passive skills | Not implemented | No passive modifier framework exists. |
| Reaction skills | Not implemented | No general reaction trigger system exists. |
| Block | Not implemented | Shield Block chance and Guard Value are design only. |
| Parry | Not implemented | Class-granted Parry is design only. |
| Reckless | Not implemented | Its Evasion, Battle Speed, and damage modifiers are design only. |

## Experience, levels, growth, and classes

| GDD feature | Status | Current prototype |
| --- | --- | --- |
| Unit level and EXP | Implemented | Units track level and EXP; the identity header displays both. |
| Kill EXP formula | Implemented | The actual killer receives `30 + 5 × level difference`, limited to 10–60 EXP. |
| `100 EXP` level-up threshold | Implemented | EXP carries over and one reward can grant multiple levels. |
| Random growth rolls | Implemented | The five personal growths roll independently on every level. |
| Growths above 100% | Implemented | Each full 100% guarantees `+1`; the remainder receives a separate percentage roll. |
| Level-up result display | Implemented | A temporary HUD panel lists EXP gained, new levels, and every characteristic gain. |
| Class stat caps | Not implemented | No caps are enforced. |
| Class display name | Implemented | FE8 prototype units display Recruit or Brigand separately from their individual name. |
| Class eligibility | Not implemented | Stat, level, prerequisite, and equipment-tag requirements do not exist. |
| Class selection or promotion | Not implemented | The timing is also an open design decision. |
| Class growth modifiers | Not implemented | Current level-ups use the configured personal growth rates directly. |
| Class equipment permissions | Not implemented | No equipment system exists. |
| Class-granted skills | Not implemented | No skill system exists. |

## Open design decisions

The following items are intentionally not implementation tasks until their rules
are approved:

- the exact combat effect of Attack Speed;
- the timing and conditions of the automatic defensive Weapon Attack;
- whether hit chance remains bounded to `5–95%`;
- whether critical damage remains `2×`;
- final Block and Parry caps;
- kill-only EXP versus participation EXP;
- class-selection and promotion timing;
- whether missed growth rolls contribute toward a guaranteed future gain.

## Existing systems outside this GDD section

The prototype already has two maps, grid movement, turn phases, reachability,
basic enemy movement, combat previews, HP feedback and death fades, FE8 map
animations, and runtime unit-display/animation/movement-speed options. These are
working foundations, but they do not make the unimplemented GDD systems above
complete.
