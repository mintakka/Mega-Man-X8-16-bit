# Integration harnesses

Run each scene with Godot 3.5 in headless mode. The harnesses cover native character scene contracts, HUD/pause/cheat/aspect integration, character-specific armor isolation, Fast Charge and Zero behavior, dynamic dialogue/ride resources, and both legacy save migrations.

```sh
godot3.5 --path . --no-window tools/integration_harness/NativeCharacterContractTest.tscn
godot3.5 --path . --no-window tools/integration_harness/NativeCharacterBootTest.tscn
godot3.5 --path . --no-window tools/integration_harness/IntegrationBehaviorTest.tscn
godot3.5 --path . --no-window tools/integration_harness/SaveMigrationTest.tscn
godot3.5 --path . --no-window tools/integration_harness/CampaignResourceMatrixTest.tscn
```
