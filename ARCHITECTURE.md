# SRPG Architecture

The target gameplay rules are maintained in [GDD/README.md](GDD/README.md).
This file documents the current code architecture rather than future mechanics.

## Scene flow

`main.tscn` owns the map-selection menu and instantiates the chosen map under
`GameRoot`.

Each map scene owns only map-specific terrain and encounter settings. Both maps
instantiate `battle/battle_runtime.tscn`, which provides the shared camera,
highlights, HP overlay, HUD, unit scene, and battle controller.

## Runtime responsibilities

| Component | Responsibility |
| --- | --- |
| `Board` | Tile bounds, blocked terrain, coordinate conversion, and cell clicks |
| `BattleRuntime` | Shared battle-scene composition and encounter configuration |
| `TurnManager` | Turn orchestration, player commands, selection, and occupancy |
| `GridNavigator` | Reachability and shortest-path calculations |
| `CombatResolver` | Current prototype combat forecast, hit rolls, reciprocal attacks, damage, and defeat events |
| `EnemyAI` | Enemy movement decisions; currently chooses a random reachable cell |
| `BattleHud` | Unit identity header, tabbed unit details (Characteristics, Equipment, Skills), combat damage previews, phase label, End Turn interface, and collapsible live unit-display, animation-speed, and movement-speed controls |
| `HighlightMap` | Movement, attack, hover, and path-preview drawing |
| `UnitHpOverlay` | Event-driven HP bars, forecast pulses, delayed damage trails, and death fades |
| `Unit` | Runtime unit state, input, movement/attack animation, and defeat fade |
| `UnitDefinition` | Reusable unit stats, movement/combat rules, and optional texture |
| `FE8MapSpriteImporter` | Optional local extraction, transparency, and faction-palette conversion for the FE8 reference sheet |
| `FE8MapSpriteAnimation` | Explicit FE8 dual-idle and four-direction movement animation data; right movement mirrors the side sequence |

## Battle state

`TurnManager` separates the active faction (`PLAYER` or `ENEMY`) from the
current action state (`IDLE`, `MOVING`, `COMBAT`, or `ENEMY_TURN`). Movement and
combat animations are awaited, so each action completes before the next state
transition.

The occupancy dictionary remains the authoritative mapping from board cells to
runtime units. `GridNavigator` receives the same dictionary by reference.

## Unit data

Create `UnitDefinition` resources for reusable unit archetypes. Definitions
contain base stats, move and attack ranges, blocking rules, animation timing,
and an optional texture. Current HP, cell position, faction, and action state
remain on the runtime `Unit`.

`UnitStats` remains as a compatibility base for resources made before the
architecture update.

When the local Sacred Stones reference sheet is present, `BattleRuntime`
supplies Recruit animations to player units and enemy-palette Brigand
animations to enemy units. Both maps use this shared path. Public clones that
do not contain the copyrighted sheet retain the generated circle fallback.

## Tests

The project intentionally uses one small, dependency-free headless test runner:

```powershell
godot --headless --path . --script res://tests/run_tests.gd
```

It checks that both maps load and spawn correctly, grid destinations obey the
movement rules, awaited movement updates occupancy, and combat forecasts and
damage math are stable.
