# SRPG Game Design Document

Status: working design draft v0.1

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
| Attack Speed | A skill's execution speed; used for strike order and follow-ups |
| Weapon Attack | The basic action automatically granted by the equipped weapon |

All formulas use integer values. Division rounds down unless a rule explicitly
says otherwise. Percentage rolls use an inclusive `1–100` roll.

## Characteristics

| Characteristic | Primary effects |
| --- | --- |
| Health (HP) | Increases maximum HP |
| Strength | Increases physical damage and offsets equipment weight |
| Speed | Increases Battle Speed, evasion, strike priority, and follow-up potential |
| Dexterity | Increases accuracy, critical chance, block, and parry |
| Intellect | Increases magical damage and healing |

`Dexterity` replaces the prototype name `Precision`. Armor is not a permanent
characteristic: it is primarily derived from equipment, class, and effects.

Temporary bonuses do not satisfy class or equipment requirements. Requirements
use permanent characteristics after permanent level-up gains.

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

## Weapon Attacks and combat exchanges

The basic automatic skill category is named **Weapon Attack**. Its displayed
name comes from the equipped weapon, such as `Sword Attack`, `Axe Attack`, or
`Bow Attack`.

A Weapon Attack is:

- automatically granted by the equipped weapon;
- used when initiating a normal attack;
- used to counter when attacked, if the defender survives, the attacker is in
  range, and the weapon permits a counter;
- removed or replaced immediately when the weapon changes.

Active skills do not replace the counterattack unless the skill explicitly has
the `counter` property.

### Exchange order

1. Determine whether both units can attack from their current positions.
2. Calculate each usable action's Attack Speed.
3. The higher Attack Speed acts first. The initiator wins ties.
4. If the other unit survives and can counter, it acts next.
5. If the Attack Speed difference is at least `20` (**initial tuning value**),
   the faster unit makes one follow-up strike if it is still alive and in range.
6. A unit can make at most one follow-up per exchange.

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
    - Target Crit Resistance,
    0,
    100
)
```

Critical Resistance is a derived value supplied by classes, equipment, or
passives; it is `0` when no source provides it.

Critical damage is `2 × Final Damage` (**initial tuning value**). Healing and
skills marked `cannot crit` skip the critical roll.

### Physical damage

```text
Physical Power = Strength + Weapon Damage + Skill Power + Flat Damage Modifiers
Physical Damage = max(0, Physical Power - Target Armor)
```

### Magical damage

```text
Magical Power = Intellect + Weapon Magic Damage + Skill Power
    + Flat Damage Modifiers
Magical Damage = max(0, Magical Power - Target Resistance)
```

Resistance is a derived defensive value supplied by equipment, class, and
skills. Keeping Armor and Resistance separate gives physical and magical builds
different counters.

### Healing

```text
Healing = max(1, Intellect + Weapon Healing Bonus + Skill Healing Power)
Final HP = min(Max HP, Current HP + Healing)
```

The baseline Heal skill cannot miss, cannot crit, and has no Attack Speed because
it does not participate in an exchange.

### Resolution order for one strike

1. Calculate attacker and defender derived stats.
2. Roll accuracy unless the action cannot miss.
3. Check Parry, then Block, when applicable.
4. Roll critical chance when allowed.
5. Calculate raw physical, magical, or healing power.
6. Apply Armor or Resistance.
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
| Damage / magic damage | Added to the appropriate power formula |
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

### Armor data

| Field | Purpose |
| --- | --- |
| Armor type | Cloth, light, medium, heavy, and future types |
| Armor value | Reduces physical damage |
| Resistance | Reduces magical damage |
| Weight | Contributes to Total Weight |
| Requirements | Class tags and permanent characteristic minimums |

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

Automatic basic actions granted by weapons. They can initiate attacks and
counterattacks.

### Active skills

Chosen deliberately during the player's turn. An active skill defines:

- target type and range;
- physical, magical, healing, or utility effect;
- base hit, base crit, and base attack speed when relevant;
- resource cost, cooldown, or limited uses when relevant;
- whether it can counter, miss, crit, or trigger a follow-up.

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

1. Rename `Precision` to `Dexterity` and centralize derived-stat formulas.
2. Add equipment resources, requirements, weight, Armor, and Resistance.
3. Replace direct strikes with data-driven Weapon Attacks and a shared forecast.
4. Add critical hits, follow-ups, Block, Parry, and passive modifiers.
5. Add level, EXP, growth rates, stat caps, and the level-up result flow.
6. Add class requirements, class selection, growth modifiers, and equipment tags.
7. Add active skills, healing, costs, cooldowns, and AI skill selection.

## Open balancing decisions

These values need playtesting before they become final:

- `5–95%` hit bounds;
- `2×` critical damage;
- `20` Attack Speed required for a follow-up;
- `75%` Block and `60%` Parry caps;
- kill-only EXP versus participation EXP;
- when class-selection and promotion opportunities occur;
- whether a missed growth should contribute to a future guaranteed-stat system.

## Current prototype gap

The current code implements HP, Strength, Speed, `Precision`, Intellect, Armor,
basic hit rolls, simple strike order, and counterattacks. It does not yet
implement the formulas in this document for weight, equipment, Armor mitigation,
Resistance, critical hits, follow-ups, skills, EXP, growth, or classes.

The GDD is the target specification. Code changes should be introduced in the
implementation order above and accompanied by small deterministic tests.
