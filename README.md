# OUT OF TIME: 2D Stickman Mechanical Cane Combat & Time-Shifting Platformer (Godot 4.7 Port)

A complete Godot 4.7 port of **ChronoStick (`bevy-game-test`)** combined with the full **OUT OF TIME** design specification and a **Procedural Piece-by-Piece Modular Character & Weapon Rig System** compatible with **[Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp)**.

---

## 🎮 Controls Reference (`bevy-game-test` + `OUT OF TIME` Spec)

| Input | Action | Combat & Traversal Effect |
| :--- | :--- | :--- |
| **A / D** or **Left / Right** | Run / Wall Slide | Crisp acceleration (`2200`) & deceleration (`2800`), wall slide on vertical surfaces / Past vines |
| **W / Space / Up** | Jump / Wall Rebound | Variable jump height (`580`), coyote time (`0.12s`), jump buffer (`0.12s`), diagonal wall rebound |
| **Left Click** or **J** | Light Attack (Shift Staff / Katana) | 135° high-speed cane/blade sweep; slices enemies & deflects bullets; rapid cooldown cancel (`0.22s -> 0.04s`) on hit |
| **Right Click** or **K** | Heavy Launcher Attack | Vertical launcher strike (`105px` range) that launches enemies into aerial **Juggle** state (`0.55x` gravity) + leaves a 3s **Chrono-Echo** |
| **S + Left Click** (Airborne) | Downward Slam & Shockwave | Rapid aerial plunge (`-950 vy`) creating a `160px` AOE knockback & slice shockwave on landing |
| **E** or **Middle Click** | Kinetic Chrono Dash | Invulnerability burst dash (`780 px/s`); **cancels recovery frames of light slashes**; spawns ghost trail + **Chrono-Echo** |
| **F** | Directional Deflect / Parry | Timed guard (`0.22s`) reflecting enemy bullets (including Sniper ricochet shots) at `1.6x` speed and parrying melee attacks |
| **Q** | Chrono Warp | Instant phase-teleport beam (`380px`, `25` energy) spawning a neon warp beam + 3 afterimage ghosts and slicing all enemies along the line |
| **Shift (Hold)** | **Chronos Shift (Stick-Shift UI)** | Raises the machined brass H-gate cockpit HUD (`Mouse Drag`, `Mouse Wheel`, `1–6` gears, `0`/`` ` `` Neutral, `R` Reverse Gear). Persists in gear on release! |
| **Tab** or **C** | **Timeline Shift (Era Cycle)** | Cycles **Past (Overgrown Ruins) ↔ Present (Industrial Compound) ↔ Future (Cybernetic Void)** at Chronos Wells (or arena-wide in Horde mode), preserving momentum and detonating waiting **Chrono-Echoes** |
| **M** | Switch Game Mode | Toggles between **Mode 1: Horde Arena Slasher** and **Mode 2: Campaign Traversal Platformer** |
| **P** | Cycle Modular Rig Loadout | Live piece-by-piece runtime swapping of character armor, helmets, pauldrons, polygons, and Shift Staff weapon pieces |
| **R** (Shift not held) | Restart | Cleanly resets game state, waves, shifter, timelines, and chronometrics |

---

## 🧩 Procedural Piece-by-Piece Modular Asset Architecture

Located in [`new-game-project/scripts/modular_rig/modular_asset_system.gd`](new-game-project/scripts/modular_rig/modular_asset_system.gd):
- **20 Anatomical & Equipment `PartSlot`s**: `HEAD`, `EYES`, `HAT_HELMET`, `SCARF_CAPE`, `TORSO`, `PELVIS`, `UPPER_ARM_L/R`, `FOREARM_L/R`, `HAND_L/R`, `THIGH_L/R`, `SHIN_L/R`, `FOOT_L/R`, `WEAPON_MAIN`, `WEAPON_OFFHAND`.
- **11 Modular `WeaponPieceSlot`s**: `POMMEL`, `GRIP`, `GUARD`, `SHAFT_LOWER`, `GEARWORK_CORE`, `SHAFT_UPPER`, `BLADE_EDGE`, `KEY_TEETH`, `MUZZLE_BARREL`, `OPTIC_SCOPE`, `MAGAZINE`.
- **4 Interchangeable Render Backends per Piece**:
  1. `PROCEDURAL_VECTOR` — Crisp neon vector lines, circles, arcs, and rotating gearwork cogs.
  2. `TEXTURE_SPRITE` — External `.png`/`.svg` `Texture2D` assets aligned to bone transforms with pivot, region rect, scale, and tint.
  3. `CUSTOM_POLYGON` — Data-driven `PackedVector2Array` geometry in local bone space (e.g. Golem stone chestplates, pauldrons, ninja cowls, heavy cleavers).
  4. `PACKED_SCENE` — Arbitrary `.tscn` node hierarchies bound to any bone slot.
- **Shift Staff (Mechanical Cane / Chronos Key)**: As the player engages higher gears or approaches a **Chronos Well**, the cane's interlocking `GEARWORK_CORE` and `KEY_TEETH` dynamically align into the ornate ancient Chronos Key.
- **Ragdoll Split Inheritance**: When an enemy is sliced into `UpperTorso` and `LowerLegs`, `CharacterLoadout.split_for_ragdoll()` automatically routes upper-body pieces to the upper ragdoll and lower-body pieces to the lower ragdoll.

### Adding Assets via `godot-mcp` (`tools/godot-mcp`)
[`tools/godot-mcp/src/scripts/godot_operations.gd`](tools/godot-mcp/src/scripts/godot_operations.gd) and [`new-game-project/scripts/tools/asset_mcp_bridge.gd`](new-game-project/scripts/tools/asset_mcp_bridge.gd) support headless CLI/MCP injection into `res://assets/modular_parts_manifest.json`:
- `register_modular_part`
- `register_weapon_piece`

---

## 🚀 Running the Game & Tests

Launch the game:
```powershell
.\run.bat
```

Run all 5 headless test suites (**296 / 296 passing**):
```powershell
.\run_tests.bat
```
