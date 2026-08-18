# Headless play harness

Boots a stage as a chosen character, drives real input through the InputMap and
logs what the abilities actually do, frame by frame. The Godot build on this
machine is a server build with no renderer (`--video-driver` offers only
`Dummy`), so nothing can be screenshotted - but all game logic runs, which is
what this checks.

Run it by pointing the project at the harness scene, then putting the real main
scene back:

```bash
cp project.godot /tmp/pg.bak
sed -i 's|^run/main_scene=.*|run/main_scene="res://tools/harness/ZeroTest.tscn"|' project.godot
timeout 180 ~/.local/bin/godot3.5 --path . > /tmp/run.log 2>&1
cp /tmp/pg.bak project.godot
```

**Always run the same scenario as X as well.** The harness loads a level without
the HUD, which makes a fixed number of unrelated null-node errors; the only way
to tell a real regression from that noise is that the counts differ between
characters.
