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
| Strength | Partial | Stored and used as direct physical damage. Weapon damage and weight offset are not implemented. |
| Speed | Partial | Stored and used by legacy combat behavior. GDD Battle Speed and weight interaction are not implemented. |
| Dexterity | Partial | Still named `precision` internally and used for hit chance. Critical, Block, and Parry effects are not implemented. |
| Intellect | Partial | Stored and displayed, but has no magical-damage or healing behavior. |
| Armor | Partial | Stored and displayed in underlying unit data, but does not reduce damage yet. |
| Five growth-rate fields | Partial | Health, Strength, Speed, Dexterity, and Intellect growth values exist and are displayed. Level-up rolls do not exist. |
| Unit name and class header | Implemented | The focused unit's individual name and displayed class appear above the tabs. |
| Characteristics tab | Implemented | Shows only the five characteristics and their growth rates. |
| Equipment tab | Partial | Tab and honest placeholders exist; equipment data does not. |
| Skills tab | Partial | Tab and prototype Basic Attack text exist; data-driven skills do not. |

## Weight and derived combat values

| GDD feature | Status | Current prototype |
| --- | --- | --- |
| Equipment Total Weight | Not implemented | No equipment inventory or weight values exist. |
| Strength reducing Weight Penalty | Not implemented | Formula exists only in the GDD. |
| Battle Speed | Not implemented | Formula exists only in the GDD. |
| Terrain Avoid and final Evasion | Not implemented | Terrain does not provide evasion. Legacy hit chance subtracts the target's raw Speed. |
| Attack Speed formula | Not implemented | Weapon skills do not yet contain Base Attack Speed. |
| Exact effect of Attack Speed | Undecided | No approved strike-order or follow-up rule exists. |

## Attacks, accuracy, critical hits, and damage

| GDD feature | Status | Current prototype |
| --- | --- | --- |
| Weapon-granted Weapon Attack | Partial | Units have a hard-coded basic physical attack, but no weapon or granted-skill data. |
| Automatic defensive Weapon Attack | Partial | Legacy reciprocal attacks exist, but their behavior is not the approved target rule. Exact target timing remains undecided. |
| GDD hit formula | Not implemented | Current formula is `precision - target.speed`; it does not use Skill Base Hit, terrain, or GDD Evasion. |
| Cannot-miss property | Not implemented | No skill property system exists. |
| Critical chance formula | Not implemented | No critical roll exists. Target formula subtracts Evasion after adding Base Crit and `floor(Dexterity / 4)`. |
| Critical damage | Not implemented | The proposed `2 × Final Damage` remains an initial tuning value. |
| Physical formula | Partial | Strength supplies damage, but Weapon Damage, Skill Power, modifiers, and Armor reduction do not exist. |
| Magical formula | Not implemented | Intellect and magical actions have no combat implementation. |
| Single Armor defense | Not implemented | The approved GDD uses Armor against physical and magical damage; current damage ignores Armor. |
| Healing formula | Not implemented | No healing action exists. |
| Shared forecast and resolution math | Partial | A combat forecast exists for legacy combat, but it does not use the target GDD formulas. |
| Strike resolution pipeline | Partial | Hit roll, damage, HP loss, and defeat exist. Critical, Armor, Block, Parry, equipment, and skill modifiers do not. |

## Equipment

| GDD feature | Status | Current prototype |
| --- | --- | --- |
| Weapon slot and weapon data | Not implemented | No weapon resource, type, damage, weight, range, or granted skill exists. |
| Armor slot and armor data | Not implemented | No armor item resource, type, value, weight, or requirements exist. |
| Shield or off-hand slot | Not implemented | No shield item or off-hand system exists. |
| Accessories | Not implemented | Reserved as a future extension. |
| Class and characteristic requirements | Not implemented | Items cannot currently be equipped. |

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
| Unit level and EXP | Not implemented | Units have no level or EXP state. |
| Kill EXP formula | Not implemented | Defeating a unit grants no EXP. |
| `100 EXP` level-up threshold | Not implemented | No level-up flow exists. |
| Random growth rolls | Not implemented | Growth rates are stored and displayed only. |
| Growths above 100% | Not implemented | Guaranteed gains plus remainder rolls are design only. |
| Class stat caps | Not implemented | No caps are enforced. |
| Class display name | Implemented | FE8 prototype units display Recruit or Brigand separately from their individual name. |
| Class eligibility | Not implemented | Stat, level, prerequisite, and equipment-tag requirements do not exist. |
| Class selection or promotion | Not implemented | The timing is also an open design decision. |
| Class growth modifiers | Not implemented | Growth data currently has no class modifier. |
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
