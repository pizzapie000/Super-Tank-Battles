# Super-Tank-Battles
This is a game based off of "Wii tanks" and the flash game "Tank Trouble"  that I have built out of my love for both of those games. It has a co-op mode and I am working on a single player adventure similar to "Wii Tanks's" main gameplay loop.

## Run the game

1. Install Godot 4.7.1 or a compatible newer version.
2. Import `project.godot` from this repository into Godot.
3. Run the project (F5, or Command+B on macOS).

The main menu offers a single-player campaign, the local two-player duel, and an
enemy field guide. Use **Backspace** to return to the menu from either mode.

## Single-player campaign

Clear all enemy tanks to advance through 50 missions. You start with three lives;
one hit destroys your tank. Press **Enter** after a win to advance or after a loss
to retry. Cleared missions unlock in the menu and save automatically, so you can
replay them or resume from your highest unlocked mission.

- **W / S or Up / Down:** Drive forward / reverse.
- **A / D or Left / Right:** Turn the tank body.
- **Mouse:** Aim the turret independently of the body.
- **Left click or Space:** Fire (five simultaneous shots).
- **E:** Place a mine (two simultaneous mines).
- **Esc:** Pause / resume, including enemy AI, shots, and mine fuses.

Mines arm after 0.75 seconds and explode on proximity, a bullet hit, a nearby
blast, or after an eight-second fuse. Mines and returning shots can kill their
owner and other tanks. Mines chain together. Tanks do not take contact damage.

The campaign uses original connected arenas with deterministic layouts for each
mission. Enemy types debut at these missions and mix into later encounters:

| Enemy | Debut | Movement | Bullets | Fire / aim | Ricochets | Live shots | Mines | Behavior |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Brown | 1 | Stationary | Normal | Slow | 1 | 1 | 0 | Passive |
| Ash | 2 | Slow | Normal | Slow | 1 | 1 | 0 | Defensive |
| Marine | 5 | Slow | Fast | Slow | 0 | 1 | 0 | Defensive |
| Yellow | 8 | Normal | Normal | Slow | 1 | 1 | 4 | Incautious |
| Pink | 10 | Slow | Normal | Fast | 1 | 3 | 0 | Offensive |
| Green | 12 | Stationary | Fast | Fast | 2 | 2 | 0 | Active |
| Violet | 15 | Fast | Normal | Fast | 1 | 5 | 2 | Offensive |
| White | 20 | Slow | Normal | Fast | 1 | 5 | 2 | Offensive |
| Black | 50 | Very fast | Fast | Fast | 0 | 3 | 2 | Dynamic |

Yellow deploys mines rapidly. Green predicts the player's future position and
validates paths with up to two wall reflections. White fades to invisibility
at mission start while leaving visible ground tracks. Defensive tanks keep their
distance and evade threats; offensive tanks pursue; Black alternates pursuit and
retreat. AI avoids firing through allies, but friendly fire remains possible.

Campaign shots have no time limit. A ricochet is a reflection before the final
wall hit: the player's one-ricochet shots break on their second wall hit;
Green's two-ricochet shots break on their third. Marine and Black shots break on
their first wall hit.

## Two-player local duel

The duel is played on one keyboard. Shots ricochet off walls and can hit either
tank, including the shooter. Each tank can have five active shots. Shots have no
time limit and break on their third wall hit, preserving the current local
Godot tuning. One hit ends the round; first to seven points wins. A new connected
maze is generated each round.

| Player | Drive | Turn | Fire |
| --- | --- | --- | --- |
| Cyan / P1 (left) | E / D | S / F | Q |
| Amber / P2 (right) | Up / Down | Left / Right | M |

- **Esc:** Pause or resume.
- **R:** Generate a new arena while keeping the score.
- **Enter:** Start a rematch after a match ends.

## Project layout

- `scenes/game/MainMenu.tscn`: Mode selection and enemy guide.
- `scenes/game/CampaignArena.tscn`: Single-player campaign.
- `scenes/game/DuelArena.tscn`: Local two-player arena.
- `scenes/tanks/Tank.tscn`: Tank body and collision shape.
- `scenes/projectiles/Shell.tscn`: Projectile body and collision shape.
- `scripts/enemy_profiles.gd`: Enemy stats and mission rosters.
- `scripts/enemy_tank.gd`: Enemy movement, aiming, and tactics.
- `scripts/shot_planner.gd`: Direct and predictive ricochet geometry.
- `scripts/tank_mine.gd`: Mine arming, fuse, blast, and chains.
- `scripts/`: Campaign progression, gameplay, maze generation, HUD, and effects.
- `assets/`: Floor texture and sound effects.
- `tests/duel_smoke.gd`: Duel regression checks.
- `tests/campaign_smoke.gd`: Campaign, AI, mine, and mission checks.

The maze and player instances are created at runtime. Use Godot's **Remote**
scene tree while the game is running to inspect them.

## Verify gameplay

After Godot has imported the project, run:

```sh
godot --headless --path . --script tests/duel_smoke.gd
godot --headless --path . --script tests/campaign_smoke.gd
```

The duel checks cover maze connectivity, movement, turning, firing limits,
unlimited shot flight time, ricochet limits, self-hits, opponent hits, scoring,
draws, rematches, and pause.

Campaign checks cover all 50 connected arenas and debut rosters, corridor
navigation, real enemy fire, predictive double-bank shots, shot caps, invisibility
and tracks, mine caps/chains/proximity/shell detonation/pause, mission advancement,
retry, trades, final victory, and the menu. Tests do not change campaign saves.
