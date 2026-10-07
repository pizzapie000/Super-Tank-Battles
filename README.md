# Super-Tank-Battles
This is a game based off of "Wii tanks" and the flash game "Tank Trouble"  that I have built out of my love for both of those games. It has a co-op mode and I am working on a single player adventure similar to "Wii Tanks's" main gameplay loop.

## Run the current prototype

1. Install Godot 4.7.1 or a compatible newer version.
2. Import `project.godot` from this repository into Godot.
3. Run the project (F5, or Command+B on macOS).

The current prototype is a local two-player PvP duel on one keyboard. Shots
ricochet off walls and can hit either tank, including the shooter. Each tank can
have five active shots. One hit ends the round; first to seven points wins.
A new connected maze is generated each round.

| Player | Drive | Turn | Fire |
| --- | --- | --- | --- |
| Cyan / P1 | Up / Down | Left / Right | M |
| Amber / P2 | E / D | S / F | Q |

- **Esc:** Pause or resume.
- **R:** Generate a new arena while keeping the score.
- **Enter:** Start a rematch after a match ends.

## Project layout

- `scenes/game/DuelArena.tscn`: Main game scene.
- `scenes/tanks/Tank.tscn`: Tank body and collision shape.
- `scenes/projectiles/Shell.tscn`: Projectile body and collision shape.
- `scripts/`: Gameplay, maze generation, HUD, and effects.
- `assets/`: Floor texture and sound effects.
- `tests/duel_smoke.gd`: Gameplay smoke checks.

The maze and player instances are created at runtime. Use Godot's **Remote**
scene tree while the game is running to inspect them.

## Verify gameplay

After Godot has imported the project, run:

```sh
godot --headless --path . --script tests/duel_smoke.gd
```

The checks cover maze connectivity, movement, turning, firing limits, shell
expiry, ricochets, self-hits, opponent hits, scoring, draws, rematches, and pause.
