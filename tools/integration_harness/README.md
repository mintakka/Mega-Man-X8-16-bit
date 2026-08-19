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
```

`BuildHybridZeroFrames.gd` regenerates the base-Zero hybrid SpriteFrames from
the user's MMX-Next source sheet while retaining Zashiko's animation contract.
Run it as `BuildHybridZeroFrames.tscn` after changing the source definitions.

`ZeroGuardTuningTest.tscn` protects Zero's innate knockback resistance and
confirms his standard ground, jumping, and wall saber attacks stagger a hiding
Metool before defeating it once exposed.
