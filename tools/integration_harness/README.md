# Integration harnesses

Run each scene with Godot 3.5 in headless mode. The harnesses cover native character scene contracts, HUD/pause/cheat/aspect integration, character-specific armor isolation, Fast Charge and Zero behavior, dynamic dialogue/ride resources, and both legacy save migrations.

```sh
godot3.5 --path . --no-window tools/integration_harness/NativeCharacterContractTest.tscn
godot3.5 --path . --no-window tools/integration_harness/NativeCharacterBootTest.tscn
godot3.5 --path . --no-window tools/integration_harness/IntegrationBehaviorTest.tscn
godot3.5 --path . --no-window tools/integration_harness/SaveMigrationTest.tscn
godot3.5 --path . --no-window tools/integration_harness/CampaignResourceMatrixTest.tscn
godot3.5 --path . --no-window tools/integration_harness/HybridZeroSpriteTest.tscn
godot3.5 --path . --no-window tools/integration_harness/MissionCharacterPickerTest.tscn
godot3.5 --path . --no-window tools/integration_harness/ZeroGuardTuningTest.tscn
godot3.5 --path . --no-window tools/integration_harness/CheatMenuReentryTest.tscn
godot3.5 --path . --no-window tools/integration_harness/NoahsParkCameraTest.tscn
godot3.5 --path . --no-window tools/integration_harness/CheatMenuLayerTest.tscn
godot3.5 --path . --no-window tools/integration_harness/ChargeAfterDialogueTest.tscn
godot3.5 --path . --no-window tools/integration_harness/StageRoutingTest.tscn
```

`BuildHybridZeroFrames.gd` regenerates the base-Zero hybrid SpriteFrames from
the user's MMX-Next source sheet while retaining Zashiko's animation contract.
Run it as `BuildHybridZeroFrames.tscn` after changing the source definitions.

`ZeroGuardTuningTest.tscn` protects Zero's innate knockback resistance and
confirms his standard ground, jumping, and wall saber attacks stagger a hiding
Metool before defeating it once exposed.

`CheatMenuReentryTest.tscn` covers repeated code-menu visits from the title,
Pause, and a returned title scene. `NoahsParkCameraTest.tscn` protects the
world-space camera detector used by Zashiko's upper K-Knuckle route.

`CheatMenuLayerTest.tscn` checks that the code entry is actually *drawn* over
the screen that opened it. It is its own CanvasLayer, so occlusion follows the
absolute `layer` number rather than nesting, and Pause instances Options at a
higher layer than the title screen does - which used to leave the code entry
underneath it, taking input while never appearing.

`ChargeAfterDialogueTest.tscn` keeps X's buster chargeable after a cutscene
conversation. Cutscenes set `block_charging` through `deactivate()` but end
through `GameManager.resume_character_inputs`, which restores input without
ever reaching `activate()` - the only place that used to clear the flag.

`StageRoutingTest.tscn` guards the difference between the two Noah's Park
levels. `NoahsPark` is the one-off intro (`Intro_NoahsPark.tscn`); `NoahsPark2`
is the replayable stage (`Axl_mod/.../Stage_NoahsPark.tscn`) and is the *only*
one containing Zero's K-Knuckle pickup and the upper route to it. Every start
button must check `already_finished_noahs_park()` before replaying the intro -
the character carousel's `GameStart` declared that helper but never called it,
so picking a character without a queued mission dropped a finished campaign
back into the intro stage, where the K-Knuckle area does not exist at all.

Two notes from a review pass on these fixes, both now covered:

- `ChargeAfterDialogueTest` also exercises **Ultimate Armor X**. `UltimateX.gd`
  extends `Character` directly instead of `Player`/`PlayerX`, but keeps its own
  `block_charging` and shares `Charge.gd`, so patching only the two obvious
  player scripts left the same permanent no-charge bug on that armor.
- `NativeCharacterBootTest` drives the real `ExtraDashJump._Setup()` with dash
  held and released, rather than calling the counters directly. `_Setup()` used
  to route through `dashjump_signal()`, which `AirDash` maps to
  `reduce_airdash_count` - so a double jump still ate an air dash whenever dash
  was held, which is the normal way to move. Note the player must be activated
  first: `Character.get_action_pressed` returns false while inactive, so the
  branch under test silently never runs on a freshly spawned player.
