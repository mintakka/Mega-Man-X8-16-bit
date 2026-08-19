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
