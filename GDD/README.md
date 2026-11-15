# SRPG Game Design Document

Status: working design draft v0.1

See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for the current state
of every system described here.

This document defines the intended character, progression, equipment, skill,
and combat systems. Numerical values marked **initial tuning value** are a
coherent prototype baseline, not final balance.

## Design goals

- Character builds emerge from stat growth, class access, equipment, and skills.
- Every combat forecast is understandable before the player commits.
- Weight creates meaningful tradeoffs without making heavy equipment unusable.
- Dexterity, Speed, and Strength have distinct combat roles.
- Random growth creates varied units while class caps and minimum class options
  prevent progression dead ends.

## Terminology

| Term | Meaning |
| --- | --- |
| Characteristic | A unit's permanent core stat before equipment and temporary effects |
| Derived stat | A combat value calculated from characteristics, equipment, terrain, and skills |
| Base value | A value supplied by a weapon, skill, shield, class, or terrain |
| Battle Speed | Effective Speed after equipment weight and modifiers |
| Attack Speed | A skill's execution-speed value; its exact combat effect is not decided yet |
| Weapon Attack | The basic action automatically granted by the equipped weapon |

All formulas use integer values. Division rounds down unless a rule explicitly
says otherwise. Percentage rolls use an inclusive `1–100` roll.

`clamp(value, minimum, maximum)` limits a value so it cannot go below the
minimum or above the maximum.

Examples:

```text
clamp(-3, 0, 100) = 0
clamp(45, 0, 100) = 45
clamp(112, 0, 100) = 100
```

In plain language, `clamp(Critical Chance, 0, 100)` means that Critical Chance
cannot be lower than `0%` or higher than `100%`.

## Characteristics

| Characteristic | Primary effects |
| --- | --- |
| Health (HP) | Increases maximum HP |
| Strength | Increases physical damage and offsets equipment weight |
| Speed | Increases Battle Speed, evasion, and a skill's Attack Speed value |
| Dexterity | Increases accuracy, critical chance, block, and parry |
| Intellect | Increases magical damage and healing |

Dexterity is the canonical stat name in both the GDD and the code. Armor is not
a permanent characteristic: it is primarily derived from equipment, class, and
effects.

Temporary bonuses do not satisfy class or equipment requirements. Requirements
use permanent characteristics after permanent level-up gains.

## Unit information interface

Selecting or inspecting a unit opens one contextual window. The unit name and
class name appear in a header above three tabs:

1. **Characteristics** — only the five core characteristics and the growth rate
   of each characteristic.
2. **Equipment** — weapon, armor, shield or off-hand, their requirements, and
   their relevant combat values.
3. **Skills** — the granted Weapon Attack plus active, passive, and reaction
   skills.

The tabs share the same focused unit and never open as separate overlapping
windows. Until equipment and data-driven skills are implemented, their tabs
identify the current prototype placeholders explicitly.

## Weight and Battle Speed

```text
Total Weight = Weapon Weight + Armor Weight + Shield Weight + Accessory Weight
Weight Penalty = max(0, Total Weight - Strength)
Battle Speed = max(0, Speed - Weight Penalty)
```

Strength removes one point of weight penalty per point. Equipment lighter than
the unit's Strength never grants bonus Battle Speed.

### Derived combat values

```text
Evasion = Terrain Avoid + Battle Speed + Flat Evasion Modifiers
Attack Speed = Skill Base Attack Speed + Battle Speed + Flat Speed Modifiers
```

Percentage modifiers are applied after flat modifiers. Example:

```text
Modified Battle Speed = floor(Battle Speed × Speed Multiplier)
```

## Weapon Attacks

The basic automatic skill category is named **Weapon Attack**. Its displayed
name comes from the equipped weapon, such as `Sword Attack`, `Axe Attack`, or
`Bow Attack`.

A Weapon Attack is:

- automatically granted by the equipped weapon;
- used when initiating a normal attack;
- used as the unit's automatic defensive attack when targeted during the
  opposing turn, as described in the original concept;
- removed or replaced immediately when the weapon changes.

No strike-order or follow-up rule is approved. The exact effect of Attack Speed
and the timing of the automatic defensive attack remain open design decisions.
Active skills are not used automatically during defense unless a future skill
explicitly says otherwise.

## Accuracy, critical hits, and damage

### Hit chance

```text
Displayed Hit = clamp(
    Skill Base Hit + Dexterity + Flat Hit Modifiers - Target Evasion,
    5,
    95
)
```

The `5–95%` bounds are the **initial tuning value**. Skills marked `cannot miss`
skip the accuracy roll and display `100%`.

### Critical chance

```text
Displayed Crit = clamp(
    Skill Base Crit + floor(Dexterity / 4) + Flat Crit Modifiers
    - Target Evasion,
    0,
    100
)
```

The critical roll happens only after the attack hits. Evasion therefore reduces
both the initial hit chance and the chance that a successful hit becomes a
critical hit. Skills marked `cannot miss` still subtract Evasion from their
critical chance unless they also specify `cannot crit`.

Example:

```text
Sword Base Crit = 5
Attacker Dexterity = 20
Target Evasion = 8
Displayed Crit = clamp(5 + floor(20 / 4) - 8, 0, 100) = 2%
```

Critical damage is `2 × Final Damage` (**initial tuning value**). Healing and
skills marked `cannot crit` skip the critical roll.

### Physical damage

```text
Physical Power = Strength + Weapon Damage + Skill Power + Flat Damage Modifiers
Physical Damage = max(0, Physical Power - Target Armor)
```

### Magical damage

```text
Magical Power = Intellect + Weapon Damage + Skill Power
    + Flat Damage Modifiers
Magical Damage = max(0, Magical Power - Target Armor)
```

Armor is the single defensive value and reduces both physical and magical
damage. There is no separate Resistance characteristic or defense.

### Healing

```text
Healing = max(1, Intellect + Weapon Healing Bonus + Skill Healing Power)
Final HP = min(Max HP, Current HP + Healing)
```

The baseline Heal skill cannot miss, cannot crit, and has no Attack Speed value.

### Resolution order for one strike

1. Calculate attacker and defender derived stats.
2. Roll accuracy unless the action cannot miss.
3. Check Parry, then Block, when applicable.
4. Roll critical chance when allowed.
5. Calculate raw physical, magical, or healing power.
6. Apply Armor.
7. Apply critical and remaining skill modifiers.
8. Apply damage or healing and resolve defeat.

The combat forecast must use the same functions and rounding as combat
resolution.

## Equipment

### Slots

- Weapon
- Armor
- Shield or off-hand item
- Accessories (future extension)

A unit may equip an item only when all of these conditions are true:

- the class permits the item's type;
- the unit meets the permanent characteristic requirements;
- any level or prerequisite requirement is met;
- the required slot is available.

### Weapon data

| Field | Purpose |
| --- | --- |
| Weapon type | Sword, axe, bow, staff, tome, and future types |
| Damage type | Physical, magical, healing, or hybrid |
| Damage | Added to the physical or magical power formula |
| Healing bonus | Added to healing formulas |
| Weight | Contributes to Total Weight |
| Range | Valid minimum and maximum attack distance |
| Base hit | Accuracy supplied to the Weapon Attack |
| Base crit | Critical chance supplied to the Weapon Attack |
| Base attack speed | Execution speed supplied to the Weapon Attack |
| Granted skill | Usually the matching Weapon Attack |

Example Sword Attack:

```text
Physical Power = Strength + Sword Damage
Base Hit = 90
Base Crit = 5
Base Attack Speed = 50
```

Current weapon catalog values:

| Weapon | Type | Damage | Weight | Range |
| --- | --- | ---: | ---: | ---: |
| Basic Sword | Sword | 5 | 4 | 1 |
| Basic Axe | Axe | 7 | 7 | 1 |
| Basic Spear | Spear | 6 | 5 | 1–2 |
| Mace | Mace | 6 | 6 | 1 |
| Dagger | Dagger | 3 | 1 | 1 |
| Longbow | Bow | 5 | 4 | 2–3 |
| War Hammer | Hammer | 8 | 8 | 1 |

Weights are abstract balance values, not kilograms.

### Armor data

| Field | Purpose |
| --- | --- |
| Armor type | Cloth, light, medium, heavy, and future types |
| Armor value | Reduces physical and magical damage |
| Weight | Contributes to Total Weight |
| Requirements | Class tags and permanent characteristic minimums |

Current medieval armor catalog values:

| Armor | Type | Armor value | Weight |
| --- | --- | ---: | ---: |
| Padded Gambeson | Padded | 2 | 3 |
| Chainmail Hauberk | Mail | 5 | 7 |
| Lamellar Armor | Lamellar | 6 | 8 |
| Coat of Plates | Plate Reinforced | 7 | 10 |
| Brigandine | Brigandine | 8 | 10 |
| Steel Plate Armor | Plate | 10 | 14 |

These are historically grounded categories with game-tuned protection and
weight values rather than literal historical measurements.

### Shield data

| Field | Purpose |
| --- | --- |
| Shield type | Determines class compatibility |
| Melee base block | Base chance against adjacent physical attacks |
| Projectile base block | Base chance against projectiles |
| Guard value | Additional damage removed on a successful block |
| Weight | Contributes to Total Weight |

## Defensive reactions

### Block

Equipping a shield grants the Block passive.

```text
Melee Block Chance = clamp(
    Shield Melee Base Block + floor((Battle Speed + Dexterity) / 2),
    0,
    75
)

Projectile Block Chance = clamp(
    Shield Projectile Base Block + floor((Battle Speed + Dexterity) / 2),
    0,
    75
)
```

On success:

```text
Blocked Damage = max(0, Final Damage - Shield Guard Value)
```

The `75%` cap is an **initial tuning value** that prevents permanent immunity.

### Parry

Some classes grant the Parry passive. The original `Skill` term is replaced by
Dexterity because Skill is not a characteristic.

```text
Parry Chance = clamp(floor((Battle Speed + Dexterity) / 2), 0, 60)
```

Parry works only against eligible melee attacks and negates the strike on
success. Parry is checked before Block; only one defensive reaction can trigger
for a strike. The `60%` cap is an **initial tuning value**.

## Skills

### Weapon Attacks

Automatic basic actions granted by weapons. They are used when attacking and as
the automatic defensive attack during the opposing turn.

### Active skills

Chosen deliberately during the player's turn. An active skill defines:

- target type and range;
- physical, magical, healing, or utility effect;
- base hit, base crit, and base attack speed when relevant;
- resource cost, cooldown, or limited uses when relevant;
- whether it can miss or crit.

### Passive skills

Always-on modifiers or conditional rules. Passive modifiers follow this order:

1. calculate base characteristics and equipment totals;
2. apply flat modifiers;
3. apply percentage modifiers;
4. apply caps and round down.

Example Reckless:

```text
Evasion Multiplier = 0.50
Battle Speed Multiplier = 1.50
Physical and Magical Damage Multiplier = 1.50
```

Reckless modifies calculated values; it does not permanently change the unit's
characteristics.

### Reaction skills

Block and Parry are passive reaction skills. Future reaction skills may trigger
when targeted, hit, damaged, healed, or reduced below an HP threshold.

## Experience and level growth

### Experience

- A unit gains EXP when it defeats an enemy.
- `100 EXP` grants one level and excess EXP carries over.
- A unit may gain multiple levels from one reward.
- Defeated units grant no further EXP.

Proposed kill EXP baseline:

```text
Kill EXP = clamp(30 + 5 × (Enemy Level - Unit Level), 10, 60)
```

Bosses and objectives may add explicit bonus EXP. This catch-up formula rewards
fighting stronger enemies and limits farming weaker ones.

Kill-only EXP can encourage feeding final blows to one unit. Keep it for the
first prototype, then evaluate participation or damage EXP during playtests.

### Growth rates

Every characteristic has a personal growth rate. A class may add a growth
modifier.

```text
Final Growth = Personal Growth + Class Growth Modifier
Guaranteed Gain = floor(Final Growth / 100)
Growth Roll = Final Growth mod 100
Stat Gain = Guaranteed Gain + (1 if d100 <= Growth Roll else 0)
```

Examples:

- `45%` growth gives a 45% chance of `+1`.
- `100%` growth always gives `+1`.
- `135%` growth always gives `+1` and has a 35% chance of another `+1`.

Each characteristic rolls independently on level-up. A characteristic cannot
exceed its current class cap. The level-up screen displays every successful gain.

Current provisional prototype growth rates:

| Unit definition | HP | Strength | Speed | Dexterity | Intellect |
| --- | ---: | ---: | ---: | ---: | ---: |
| Default / Unclassed | 60% | 40% | 40% | 40% | 20% |
| Recruit | 70% | 40% | 50% | 55% | 10% |
| Brigand | 80% | 60% | 30% | 35% | 5% |

These are initial tuning values. Class growth modifiers and class stat caps are
not implemented yet, so current rolls use the configured personal rate directly.

## Classes

Class eligibility is checked only at a class-selection or promotion opportunity.
A class can require:

- minimum permanent characteristics;
- a minimum level;
- a prerequisite class;
- one or more equipment or weapon tags.

Classes define:

- characteristic caps;
- growth-rate modifiers;
- permitted weapon, armor, and shield types;
- movement type and movement range;
- granted active, passive, and reaction skills.

Equipment bonuses and temporary buffs never unlock a class. At least one base
class must always have no characteristic requirement so random growth cannot
soft-lock progression.

Illustrative requirements, pending starting-stat balance:

| Class | Example requirement | Identity |
| --- | --- | --- |
| Fighter | Strength 8 | Heavy physical weapons |
| Myrmidon | Speed 8, Dexterity 8 | Fast, accurate melee and Parry |
| Knight | Health 22, Strength 8 | Heavy armor and shields |
| Mage | Intellect 8 | Magical weapons and ranged magic |
| Cleric | Intellect 7 | Healing and support |

## Initial implementation plan

1. Centralize derived-stat formulas around Dexterity and the other canonical
   characteristic names.
2. Add equipment resources, requirements, weight, and Armor.
3. Replace direct strikes with data-driven Weapon Attacks and a shared forecast.
4. Add critical hits, Block, Parry, and passive modifiers.
5. Add level, EXP, growth rates, stat caps, and the level-up result flow.
6. Add class requirements, class selection, growth modifiers, and equipment tags.
7. Add active skills, healing, costs, cooldowns, and AI skill selection.

## Open balancing decisions

These values need playtesting before they become final:

- `5–95%` hit bounds;
- `2×` critical damage;
- the exact combat effect of Attack Speed;
- the timing and conditions of the automatic defensive Weapon Attack;
- `75%` Block and `60%` Parry caps;
- kill-only EXP versus participation EXP;
- when class-selection and promotion opportunities occur;
- whether a missed growth should contribute to a future guaranteed-stat system.

## Current prototype gap

The current code implements HP, Strength, Speed, Dexterity, Intellect, weapon and
armor equipment, weapon damage, Armor mitigation for physical attacks, equipment
weight, Weight Penalty, Battle Speed, weapon range, basic hit rolls, unit levels,
kill EXP, five personal growth rates, random level-up rolls, EXP carry-over, and
visible level-up results. It does not yet implement critical hits, magical
attacks, healing, shields, equipment requirements, data-driven skills, class stat
caps, class growth modifiers, or class eligibility and selection.

The prototype currently also contains speed-based strike order and reciprocal
attacks. Those are legacy prototype behaviors, not approved GDD rules.

The GDD is the target specification. Code changes should be introduced in the
implementation order above and accompanied by small deterministic tests.
