Use sonnet as the implementors. Fix the animations and death sprites for stickmen so they match the visual style of https://www.youtube.com/watch?v=34NfuVCrfok&pp=ygUKb25lIHZzIGFsbA%3D%3D, adopting the style without copying the moves.

Working directory: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project
Integrity mode: development

Reference:
- Visual style reference: https://www.youtube.com/watch?v=34NfuVCrfok&pp=ygUKb25lIHZzIGFsbA%3D%3D

## Requirements

### R1. Stickman Character Animation Style
Fix character animations across player, echoes, and enemy archetypes to display clean, readable, fluid stick-figure motion matching the reference video style, without copying the specific moves. Characters must have distinct color tints or accents per archetype (player, echoes, and enemy types) on clean, solid stick-figure silhouettes rather than blurred or smeared sprite clusters.

### R2. Death Visuals and Dismemberment
Fix character death sprites and ragdoll remains so that character defeat triggers procedural dismemberment into clean, detached stick-figure parts with physics and ragdoll momentum, remaining clearly readable as stick-figure segments matching the reference style rather than thin fragmented debris.

### R3. Test Suite Preservation
Maintain full compatibility with the existing project test suite so that all existing tests pass without regressions.

## Acceptance Criteria

### Visual Style and Animation
- [ ] Live stickman characters render with clean, readable stick-figure silhouettes with distinct archetype color tints or accents.
- [ ] Character animations (idle, movement, attacks, reactions) are fluid, snappy, and visually readable without sprite smearing or visual artifacts.

### Death Visuals
- [ ] Defeated characters dismember into clean, detached stick-figure body segments (head, torso, limbs) that tumble with readable physics and momentum.
- [ ] Death remains and ragdoll pieces maintain recognizable stick-figure proportions and styling rather than scattered line debris.

### Verification and Regression
- [ ] Running `run_tests.bat` passes all test suites (including all 393 existing assertions) with zero failures.
- [ ] The visual animations and death effects run and render cleanly in the Godot test scene `res://scenes/test_procedural_stickmen.tscn`.
