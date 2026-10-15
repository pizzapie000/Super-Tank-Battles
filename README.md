# Super-Tank-Battles
This is a game based off of "Wii tanks" and the flash game "Tank Trouble"  that I have built out of my love for both of those games. It has a co-op mode and I am working on a single player adventure similar to "Wii Tanks's" main gameplay loop.

## Run the game

1. Install Godot 4.7.1 or a compatible newer version.
2. Import `project.godot` from this repository into Godot.
3. Run the project (F5, or Command+B on macOS).

The main menu offers **True Campaign** (the new 1–4 player local story adventure),
**Classic Missions** (the editable 50-mission single-player campaign), the local
two-player duel, and an enemy field guide. Backspace returns to the menu.

## True Campaign: a playable story prototype

Choose **True Campaign → New Adventure**. Join in the crew lobby, then begin.
The screen fades to black for a short tank assembly and polishing sequence with
an original temporary music cue. Enter / controller Start skips the intro.

The campaign follows one connected, scrollable world through twelve sections,
with two sections for each area:

| Area | First section | Second section |
| --- | --- | --- |
| Factory | Safe assembly tutorial | Escape with pursuing reinforcements |
| Wasteland | Damaged, discarded models | Deeper scrapyard with working patrols |
| Forest | Burned woods and river crossing | Denser canopy and harder patrols |
| Fortress | Outer fortifications | Inner courtyard and the Gatekeeper |
| Village | Dirt road, peace signs, fleeing villagers | Chief's plea at the gates and the party's choice |
| Capital | Ruined boulevard | Elite command district and the First Commander |

Each new combat section adds more rubble and harder enemy combinations. The
Gatekeeper and First Commander appear in their area's second section.

The tutorial teaches movement, firing at two inactive tanks, and laying a mine.
The inactive tanks cannot fire, and the crew cannot take tutorial damage. When
the lessons are complete, the alarm sounds and real security tanks activate.
Clear enemies, then bring every active crew member to the eastern exit. During
factory escape, the exit is open immediately: security enters offscreen from the
west every five seconds and chases the crew. Leave together while enemies are
still alive. Waves scale with crew size, with a limit on simultaneous enemies.
Downed crew members return with the party at the next section checkpoint.

### Local crew and controller controls

The keyboard player is enabled initially. Controllers press **A / Cross** to
join and **B / Circle** to leave in the lobby. Use **Tab** or the **Keyboard
On / Off** button to remove the keyboard slot for an all-controller crew.
Up to four distinct controllers can play; device IDs are assigned individually.
Press Enter or Start to begin. This is local co-op on one computer.

| Action | Keyboard + mouse | Controller |
| --- | --- | --- |
| Move in a direction | WASD | Left stick |
| Aim turret independently | Mouse | Right stick |
| Fire | Left click / Space | RT / R2, or right shoulder |
| Landmine | E | B / Circle |
| Revive nearby friend / use village repairs | Hold F | Hold A / Cross |
| Field repair, costing 2 supplies | R | Y / Triangle |
| Pause | Esc | Start / Options |

Story tanks start with three armor points. Every shell and missile can damage crew,
enemies, and its own shooter after launch, regardless of team. Friendly shells
also intercept each other, destroying both shots. The safe tutorial still prevents
crew damage. Friendly mine blasts retain their separate crew protection.
A downed tank remains visible and can be
revived by a teammate holding help nearby for two seconds. Whole-party defeat
offers a chapter retry. Stick deadzones reject drift and limit diagonal speed;
controller handling follows [Godot's mapped gamepad input](https://docs.godotengine.org/en/4.7/tutorials/inputs/controllers_gamepads_joysticks.html).
The camera follows the crew, and a separation limit keeps players on screen.
Disconnecting a joined controller pauses play; reconnecting resumes the story
state, or return to the lobby to change the crew. Physical pads still need a
hands-on check; automated tests inject per-device controller events.

### The village and checkpoints

The first village section follows a dirt road with signs begging tanks to leave
the residents alone. Villagers flee toward home as the crew approaches. In the
second section, reach the closed village gates: the chief begs the crew for
mercy, and play pauses for a shared party decision:

- **Spare:** gain 3 supplies, repair the crew immediately, and retain a permanent
  free repair refuge. You can travel back from the capital with your crew.
- **Destroy:** take 8 supplies immediately; the village burns and free repairs
  close. Supplies can instead fund field repairs.

The decision changes the village's appearance and ending text. Chapter clears
grant 2 supplies. Checkpoints save the chapter, supplies, and village decision in
`user://adventure.cfg`, separate from classic mission unlocks. Older seven-section
saves migrate to the matching area, retaining supplies and the village decision.
Continue assembles a fresh local crew and starts at the saved chapter; retry restores that chapter's
starting supplies and part loadouts. New Adventure begins a new story save when the adventure starts.

### Co-op encounters and tank roles

Regular enemy counts use 100%, 140%, 180%, and 220% of the authored solo roster
for one through four players, rounded to whole tanks. Bosses, inactive tutorial
tanks, and peaceful village sections are excluded. Boss and regular enemy armor
remain the same for every crew size. Five-second factory waves use the same curve
and retain a cap on live enemies.

Solo enemies retain their independent behavior. Co-op squads divide targets
among living players, spread out, flank from different sides, and select cover
that actually blocks direct shots. With three or four players, support tanks
prefer valid ricochets when available. Green tanks retain their rule of firing
only calculated bank shots. Extra mine tanks (Yellow), multi-shot tanks (Pink),
and fast-shot tanks (Marine) appear earlier for larger crews; they occupy slots
inside the scaled budget.

Front and side entries deploy the additional patrols. A reserved rear group
ambushes the crew as it advances. In `FortressCourtyard.tscn`, solo uses one
entrance. Co-op entering the courtyard opens two, three, or four entrances at
once and deploys its reserved attackers from those directions. The exit waits
for both patrols and reserved attackers to be defeated.

Hold **F / A** beside a labeled part crate for a moment to equip it. Each tank
has one part slot; taking another part replaces its current part. A crate equips
only the player who claims it. Roles appear beside armor in the crew HUD.

| Part | Benefit | Tradeoff |
| --- | --- | --- |
| Loader | Reload decreases from 0.32s to 0.22s | Uses the one part slot |
| Armor | Maximum armor increases from 3 to 4 | Movement decreases from 150 to 135 |
| Bank Shot | One extra bounce; shots deal 2 damage after bouncing | Direct shots still deal 1; friendly and self hits also receive the bonus |
| Engine | Movement increases from 150 to 185 | Maximum armor decreases from 3 to 2 |

Part slots persist between sections and in Continue saves. Retry restores the
section's starting parts and resets its crates. Revives and repairs respect each
player's equipped armor capacity. These are starting balance values for playtesting.

### Edit the story and replace its music

Open `scenes/story/StoryWorld.tscn` to see how the locations connect. Edit individual
scenes in `scenes/story/regions` to move/delete/duplicate walls or tank markers.
Wall pieces use the same **Size** property as classic missions. Keep wall rotations
at 0 and scales at (1, 1). Use the **Start** / **Exit** markers and leave tank-width
routes; the navigation grid is 32px, so allow at least 80px passages. Keep chapter
positions and the gate at the region's eastern boundary for progression.
Each region root exposes its **Title**, **Briefing**, and **Section Type**. The
factory escape's **Reinforcement Interval** defaults to 5 seconds. Story enemy
markers expose **Tank Type**, **Dormant**, **Damaged**, **Armor**, and
**Boss Title**. The forest river banks and village houses have actual collisions.
**CoopEntries** contain editable attack markers with an **Approach** direction;
**AmbushTrigger** controls where reserved attackers activate. Courtyard markers
also reference physical entrance gates. **Parts** contain editable
`UpgradePart.tscn` crates with a **Part Type** property.

To install your music:

1. Put your audio files in `assets/music` and let Godot import them.
2. Open `scenes/story/Adventure.tscn` and select the **Adventure** root.
3. Drag your triumphant track into **Intro Music**, replacing the temporary cue.
4. Optional: expand **Chapter Music** to twelve entries and assign a track to each
   chapter, in story order. Chapter tracks restart when they finish.
5. Set **Intro Duration** to your track's length in seconds; the assembly and
   polishing animation retimes to match. The default is 16 seconds.

Edit section titles and briefings on each region's root. Adjust the opening
animation in `scripts/story/adventure.gd`. The temporary opening music, factory
alarm and checkpoint sound are original synthesized placeholders; existing shot, ricochet
and explosion effects are reused. Run `Adventure.tscn` directly with F6 for a solo
story test, or use the main menu for controller joining. Direct story runs use the
normal story save; classic mission previews continue to avoid changing saves.

## Scenery and tank detail

Story forests use large overhead tree canopies. Tanks, bullets and projectile
trails can pass beneath the leaves and disappear from view; the trunks are solid
and can reflect shells. This is visual concealment, and the crew HUD remains
visible. The forest includes scorched foliage and broad tree shadows.

Broken concrete, brickwork and steel wreckage add solid ricochet surfaces along
the story route. Their visible straight edges match the collision and aiming
geometry. Enemy routes are rebuilt around this cover at chapter start.

Reusable pieces live in `scenes/story/props`:

- **CoverTree.tscn:** move/duplicate trees; change **Crown Radius**, **Variation**,
  or **Scorched** in the Inspector. Keep rotation at 0 and scale at (1, 1).
- **Rubble.tscn:** move/duplicate rubble, resize using **Size**, and choose
  **Surface Type** (Concrete, Wreckage, Bricks). Keep tank-width gaps and spawn
  positions clear. **Variation** changes the surface chips.
- **Conveyor.tscn:** an animated decorative belt, with **Belt Size** for resizing.
  The crew starts on one in `FactoryBoot.tscn`. It does not force tank movement.
- **VillageSign.tscn:** move/duplicate a wooden plea sign and edit **Message**.
- **Villager.tscn:** move people along the village road; **Safe Position** is their
  escape destination in their parent's local coordinates. **Flee Radius** and
  **Run Speed** control their response. **Chief** keeps a villager beside the gate.

Tanks use shared modular artwork for suspension, track rollers, armor plates,
engine grilles, turret rings, hatches, bolts and cannon fittings. Their bright
colors and identification symbols remain. The intro installs these same parts
in stages, including a lowering hoist and welding sparks, before the technician
polishes the finished tank on the conveyor. Its duration still follows the
Adventure root's **Intro Duration** setting.

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

The campaign loads 50 editable mission scenes. Their starting layouts and enemy
placements preserve the original connected arenas. Enemy types debut at these
missions and mix into later encounters:

| Enemy | Debut | Movement | Bullets | Fire / aim | Ricochets | Live shots | Mines | Behavior |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Brown | 1 | Stationary | Normal | Slow | 1 | 1 | 0 | Passive |
| Ash | 2 | Slow | Normal | Slow | 1 | 1 | 0 | Defensive |
| Marine | 5 | Slow | Fast | Slow | 0 | 1 | 0 | Defensive |
| Yellow | 8 | Normal | Normal | Slow | 1 | 1 | 4 | Incautious |
| Pink | 10 | Slow | Normal | Fast | 1 | 3 | 0 | Offensive |
| Green | 12 | Stationary | Fast missiles | Fast | 2 | 2 | 0 | Active |
| Violet | 15 | Fast | Normal | Fast | 1 | 5 | 2 | Offensive |
| White | 20 | Slow | Normal | Fast | 1 | 5 | 2 | Offensive |
| Black | 50 | Very fast | Fast | Fast | 0 | 3 | 2 | Dynamic |

Yellow deploys mines rapidly. Green predicts the player's future position and
only fires missiles when it finds a valid one- or two-ricochet path. It never
fires directly at the player and holds fire when no bank angle is available.
Its missiles have visible exhaust and a longer smoke trail. White fades to invisibility
at mission start while leaving visible ground tracks. Defensive tanks keep their
distance and evade threats; offensive tanks pursue; Black alternates pursuit and
retreat. AI avoids firing through allies, but friendly fire remains possible.

Campaign shots have no time limit. A ricochet is a reflection before the final
wall hit: the player's one-ricochet shots break on their second wall hit;
Green's two-ricochet shots break on their third. Marine and Black shots break on
their first wall hit. All projectiles, including Green missiles, can intercept
each other. A collision destroys both shots and frees both ammunition slots,
even when both shots belong to the same tank.

Tank colors use a brighter, more saturated palette: royal blue for the player
and vivid hot pink for Pink enemies. Tank bodies have bright outlines, player
tanks display 1/2, and each enemy type has a distinct white identification symbol
shown in the field guide. White still becomes invisible during missions.

## Design your own mission layouts in Godot

1. In the **FileSystem** panel, expand `scenes/levels/missions` and double-click
   `Mission01.tscn` (or any of `Mission01` through `Mission50`). Switch to **2D**.
   The arena, walls, and labeled starting tanks are visible before you run it.
2. Expand **Walls** in the **Scene** tree. Select a wall in the tree or click it
   in the arena. Drag to move it; **Command+D** duplicates it on macOS
   (**Ctrl+D** elsewhere). Use **Delete** or right-click **Delete Node(s)** to
   remove it. **Command+Z / Ctrl+Z** undoes edits.
3. To add a wall, select **Walls**, then drag `HorizontalWall.tscn` or
   `VerticalWall.tscn` from `scenes/levels/pieces` into the 2D view. This works
   even in Mission 1, which starts with no interior walls. Adding a wall directly
   under the mission root also works.
4. With a wall selected, change **Size** near the top of the **Inspector** to
   make it longer or shorter. A vertical piece starts at `(14, 142)`; a horizontal
   piece starts at `(142, 14)`. Use the two templates for orientation; keep
   **Rotation** at `0` and **Scale** at `(1, 1)`. Edit Size instead of polygon
   points. Change an instance inside the mission, rather than the shared piece
   scene, unless you want to change every instance that uses that piece.
5. For tidy grid placement, enable grid snapping with the 2D editor's magnet
   controls. In **Configure Snap**, set **Grid Step** to `(128, 128)` and
   **Grid Offset** to `(64, 152)`. Wall origins sit on grid intersections;
   tank markers sit halfway between them. Turn snapping off when moving spawns
   or making a free-positioned layout. Free-positioned walls also work.
6. Drag **PlayerSpawn** or markers under **Enemies** to move starting positions.
   Keep one **PlayerSpawn**. To add an enemy, duplicate an enemy marker or drag
   `pieces/EnemySpawn.tscn` into the arena. Select an enemy and change **Tank Type**
   in the Inspector to choose its AI. Delete an enemy marker to remove that tank.
7. Save with **Command+S / Ctrl+S**, then choose **Run Current Scene** (F6;
   some Mac keyboards require Fn+F6). The open mission runs even if it is locked
   in the campaign, and preview wins do not change your saved campaign progress.
   Stop, edit, and run again to see your changes. F5 runs the usual main menu.

The outer boundary and arena size stay fixed. Leave room around tank spawn
markers and routes between the player and mobile enemies. A warning icon on the
mission root reports overlapping/blocked spawns, walls outside the arena, or
mobile enemies with no route to the player. Empty enemy lists clear immediately.
Keep the numbered mission filenames and the root's Mission Number unchanged so
the campaign loads the right scene. The old `scenes/levels/Level1.tscn` is a
legacy scene; edit the numbered scenes in `missions` for the campaign.

Walls use the same saved geometry for their appearance, collisions, ricochet
aiming, and enemy routes. Routes are rebuilt from your edited walls at each
mission start. The navigation grid is 32 pixels with tank clearance; leave
passages at least 80 pixels wide, preferably wider for fast tanks and turning.

## Two-player local duel

The duel is played on one keyboard. Shots ricochet off walls and can hit either
tank, including the shooter. Each tank can have five active shots. Shots have no
time limit and break on their third wall hit, preserving the current local
Godot tuning. One hit ends the round; first to seven points wins. A new connected
maze is generated each round.

| Player | Drive | Turn | Fire |
| --- | --- | --- | --- |
| Royal blue / P1 (left) | E / D | S / F | Q |
| Orange / P2 (right) | Up / Down | Left / Right | M |

- **Esc:** Pause or resume.
- **R:** Generate a new arena while keeping the score.
- **Enter:** Start a rematch after a match ends.

## Project layout

- `scenes/game/MainMenu.tscn`: Mode selection and enemy guide.
- `scenes/story/Lobby.tscn`: Local crew joining and input assignments.
- `scenes/story/Adventure.tscn`: Story flow, music slots, co-op and shared camera.
- `scenes/story/StoryWorld.tscn` / `regions/`: Connected, editable story locations.
- `scripts/story/`: Tutorial, story state, crew controls, damaged enemies and bosses.
- `scenes/story/props/`: Editable overhead trees, solid rubble and animated conveyors.
- `scripts/tank_art.gd`: Shared tank components for gameplay and assembly animation.
- `scenes/game/CampaignArena.tscn`: Single-player campaign.
- `scenes/game/DuelArena.tscn`: Local two-player arena.
- `scenes/levels/missions/Mission01.tscn` through `Mission50.tscn`: Editable campaign layouts.
- `scenes/levels/pieces/`: Reusable horizontal/vertical walls and enemy spawn marker.
- `scenes/tanks/Tank.tscn`: Tank body and collision shape.
- `scenes/projectiles/Shell.tscn`: Projectile body and collision shape.
- `scripts/enemy_profiles.gd`: Enemy stats and mission rosters.
- `scripts/enemy_tank.gd`: Enemy movement, aiming, and tactics.
- `scripts/shot_planner.gd`: Direct and predictive ricochet geometry.
- `scripts/tank_mine.gd`: Mine arming, fuse, blast, and chains.
- `scripts/mission_layout.gd`: Editor preview, layout warnings, and direct mission testing.
- `scripts/mission_wall.gd` / `mission_spawn.gd`: Editable wall and tank markers.
- `scripts/mission_navigation.gd`: Routes around edited wall geometry.
- `scripts/`: Campaign progression, gameplay, maze generation, HUD, and effects.
- `assets/`: Floor texture and sound effects.
- `tests/duel_smoke.gd`: Duel regression checks.
- `tests/campaign_smoke.gd`: Campaign, AI, mine, and mission checks.
- `tests/projectile_smoke.gd`: Projectile interception and ammunition checks.
- `tests/layout_smoke.gd`: Authored layout loading, wall editing, navigation, and direct mission previews.
- `tests/story_smoke.gd`: Co-op inputs, tutorial, story progression, choices and checkpoints.
- `tests/story_expansion_smoke.gd`: Extended routes, timed offscreen pursuit, village arrival, and save migration.
- `tests/coop_smoke.gd`: All party-size budgets, squad tactics, fortress gates, role pickups, bank damage, and saved parts.
- `tests/scenery_smoke.gd`: Real ricochets off rubble/trunks and firing beneath foliage.

Campaign layouts are editable in the numbered mission scenes. Live tank and
physics instances are created at runtime; use Godot's **Remote** scene tree while
running to inspect those. The local duel still generates a new maze each round.

## Verify gameplay

After Godot has imported the project, run:

```sh
godot --headless --path . --script tests/duel_smoke.gd
godot --headless --path . --script tests/campaign_smoke.gd
godot --headless --path . --script tests/projectile_smoke.gd
godot --headless --path . --script tests/layout_smoke.gd
godot --headless --path . --script tests/story_smoke.gd
godot --headless --path . --script tests/story_expansion_smoke.gd
godot --headless --path . --script tests/coop_smoke.gd
godot --headless --path . --script tests/scenery_smoke.gd
```

The duel checks cover maze connectivity, movement, turning, firing limits,
unlimited shot flight time, ricochet limits, self-hits, opponent hits, scoring,
draws, rematches, and pause.

Campaign checks cover all 50 connected arenas and debut rosters, corridor
navigation, real enemy fire, predictive double-bank shots, shot caps, invisibility
and tracks, mine caps/chains/proximity/shell detonation/pause, mission advancement,
retry, trades, final victory, and the menu. Tests do not change campaign saves.

Projectile checks cover normal shots and missiles, same-owner interceptions,
fast perpendicular crossings, walls blocking an interception, paused shots,
immediate collision removal without consuming a third shot, and impacts on
damageable objects other than tanks.

Layout checks compare every running mission's walls and starting tanks against
its saved scene (allowing intentional editor changes), then exercise adding, moving, resizing, saving/reloading
and deleting walls, physics blocking, live navigation around an off-grid wall,
layout warnings, direct mission previews, and cleanup when returning to the menu.

Story checks cover four-player assignment (including nonconsecutive device IDs),
controller-only joining/leaving, deadzones, actual movement/aim/fire/mine input,
tutorial safety and alarm activation, teammate shell damage, self-inflicted
ricochets, protected friendly mine blasts, armor,
revives, targeting another player when P1 is down, pause/disconnect recovery,
chapter geometry/routes, damaged tanks, boss phases/reinforcements, both village
choices and repairs, persistence, checkpoint retry, crew exit gating, and the
capital ending. Tests use their own save path and never overwrite story progress.
