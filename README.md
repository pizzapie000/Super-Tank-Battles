# Super-Tank-Battles
This is a game based off of "Wii tanks" and the flash game "Tank Trouble"  that I have built out of my love for both of those games. It has a co-op mode and I am working on a single player adventure similar to "Wii Tanks's" main gameplay loop.

## Run the game

1. Install Godot 4.7.1 or a compatible newer version.
2. Import `project.godot` from this repository into Godot.
3. Run the project (F5, or Command+B on macOS).

The main menu offers **True Campaign** (the new 1–4 player local story adventure),
**Classic Missions** (the editable 50-mission single-player campaign), the local
two-player duel, and an enemy field guide. Backspace returns to the menu.
During a battle, pause with **Esc** (**Start / Options** in True Campaign), then
select **Enemy Field Guide**. **Back to Pause**, Esc, or controller B / Circle
returns to the pause menu; resume normally when you are ready. Combat stays frozen while
the guide is open. The same guide is available in True Campaign, Classic Missions,
and local duels.

## True Campaign: a playable story prototype

Choose **True Campaign → New Adventure**. Join in the crew lobby, then begin.
The screen fades to black for a short tank assembly and polishing sequence with
an original temporary music cue. Three articulated handling robots grip the
chassis, tracks, armor, turret and cannon, seat them, then open their jaws and
retract. A separate welding robot follows the fitted seams with an arc, sparks
and a little smoke. Each joined player gets an assembly bay with their actual
tank color and number; crews of two to four are built together.
Enter / controller Start skips the intro.
While the technician polishes, the engine cranks and catches with a short puff of
exhaust. The tank rolls forward, and the startled worker drops his cloth and runs
away. The engine sound and animation follow **Intro Duration**; **Engine Start Sound**
on `Adventure.tscn` can replace the original startup cue. Skipping stops the cue
immediately. If skipped before the worker runs, he flees when a crew tank first
moves in the tutorial. Retry resets him, and pausing freezes his reaction.

For testing, choose **True Campaign → Debug Checkpoints** on the main menu.
Pick a numbered stage, assemble your crew, and select **Test This Checkpoint**.
The list reads stage titles directly from `StoryWorld.tscn`, including added levels.
Debug runs skip the opening movie and start at the selected stage with a fresh
crew, two supplies, and the usual five-second protected arrival. They never change
the regular adventure save. The HUD shows **DEBUG · NO SAVE** while testing.
Pause and choose **Debug Checkpoints** to jump again with the same crew; cancel
returns to the paused battle. Keyboard arrows / Enter and controller left stick
or D-pad / A select a stage; Esc / B cancels. Return to modes and use **Continue**
or **New Adventure** to play normally again.

The campaign follows one connected, scrollable world through fifteen checkpoints.
The wasteland, forest, and fortress each have three sections:

| Area | First section | Second section | Third section |
| --- | --- | --- | --- |
| Factory | Safe assembly tutorial | Escape with pursuing reinforcements | — |
| Wasteland | Damaged, discarded models | The Rustworks scrapyard | Salvage Run: offset wreck rows and a mixed salvage patrol |
| Forest | Burned woods and river crossing | Deep in the Ruins | The Overgrown Crossroads: two river crossings, canopy, and ruined cover |
| Fortress | The Fortress Gate and the Pink Gatekeeper | The Ricochet Battery and its escort patrol | The Inner Bastion: layered ramparts and a mobile garrison |
| Village | Dirt road, peace signs, fleeing villagers | Chief's plea at the gates and the party's choice | — |
| Capital | Ruined boulevard | Elite command district and the First Commander | — |

The outer gate and the Gatekeeper share one encounter. The Gatekeeper is a slow
Pink tank with four armor, three active shells, no mines, and no extra wave when
its armor is damaged. The separate battery checkpoint has two Green tanks,
one Brown tank, two Ash escorts, and one Pink escort before co-op scaling.
The First Commander appears in the capital's second section. Existing saves move
to the same named stage, keeping supplies, parts, the village decision, and completion.
The new stages each have their own checkpoint, powerup crates, and co-op attack entries.

Every checkpoint opens with a **Next Stage** card showing its title and checkpoint
number. Tanks fade in over five seconds. Players can move and equip powerups
while all combat waits; the countdown pauses with the game and starts after
the screen transition finishes.

The tutorial has six large, readable lesson cards: welcome, movement, firing at
two inactive tanks, mines, fitting a powerup, and crew support. Each stays until
the practice is complete, its reading time has elapsed, and a player presses
**Enter / A**. The inactive tanks cannot fire, and the crew cannot take tutorial
damage. Confirm the final lesson to sound the alarm and activate real security.
The main menu's **Skip factory tutorial** checkbox remembers your preference.
During training, hold **T / Y or Triangle** for two seconds to skip directly to
the factory escape. The opening movie remains separately skippable with Enter / Start.
Clear enemies, then bring every active crew member to the eastern exit. During
factory escape, a solid blast gate blocks the exit. It takes six normal shell hits to break
through, then leave together while enemies are still alive. Security enters
offscreen from the west every five seconds and chases the crew. The red warning
pulse and looping siren continue from the tutorial alarm until the crew reaches
the wasteland; pausing also pauses the siren and pulse. Waves scale with crew
size, with a limit on simultaneous enemies. Retry restores the blast gate.
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
| Self-repair, costing 2 supplies | Hold R for 2 seconds | Hold Y / Triangle for 2 seconds |
| Pause | Esc | Start / Options |

Story tanks start with three armor points. Every shell and missile can damage crew,
enemies, and its own shooter after launch, regardless of team. Friendly shells
also intercept each other, destroying both shots. The safe tutorial still prevents
crew damage. Mine blasts also hurt their owner and nearby allies, regardless of team.
A downed tank remains visible and can be
revived by a teammate holding help nearby for two seconds. Whole-party defeat
offers a chapter retry. Stick deadzones reject drift and limit diagonal speed;
controller handling follows [Godot's mapped gamepad input](https://docs.godotengine.org/en/4.7/tutorials/inputs/controllers_gamepads_joysticks.html).
The camera follows the crew, and a separation limit keeps players on screen.
Field repairs immobilize the repairing tank for the full two-second hold and
show a green progress ring. The tank cannot shoot or place mines while repairing.
Releasing early or pausing cancels the repair without spending supplies.
Completing a repair restores only that player's armor and spends two supplies;
release the button before starting another repair. Full armor and insufficient
supplies do not start a repair or immobilize the tank.
Disconnecting a joined controller pauses play; reconnecting resumes the story
state, or return to the lobby to change the crew. Physical pads still need a
hands-on check; automated tests inject per-device controller events.

### The village and checkpoints

Village homes have wooden doors, shuttered windows and flower boxes, tiled roofs,
chimneys, porch lamps, potted plants, rain barrels, and small stacks of firewood.
Stepping-stone paths lead from their porches to the road. The homes retain their
original solid footprints; the gardens and porch details are decorative.
In `Village.tscn`, select a house under **Walls** to edit **Size**, **Entrance Side**,
**Plaster Color**, **Roof Color**, and **Flower Color**. All four homes are drawn
upright; the lower homes' paths wrap around to their front porches.
Raiding the village darkens the homes, breaks their windows,
and withers their plants.

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
and earlier twelve- or thirteen-section saves migrate to the matching area, retaining supplies,
the village decision, and equipped parts.
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

When three or more enemy tanks bunch up, both modes favor less crowded routes.
One tank keeps the lead while followers account for nearby tanks and the next
part of their routes, taking other passages or different firing approaches when
space allows. Briefly committed lanes prevent constant switching. Close tanks
also steer apart, while mine escapes, bullet dodges and wall recovery keep their
priority. Crowding is a soft route cost, so a narrow single passage remains usable;
walls and mine blast areas still block unsafe routes. Stationary enemies stay put.

Moving enemies in both story and classic missions plan routes around all
mines before they arm, keeping outside their blast areas. Even Yellow tanks
avoid player mines. If a mine blocks the only safe passage, enemies wait and
resume their route when it is gone. Mine layers check for a clear escape lane
before planting, then flee past the blast radius before resuming the fight.
They avoid their own mines and allied mines too. Story White tanks start near the capital's
entrances, in view of the crew, so their transition into invisibility is visible.

Front and side entries deploy the additional patrols. A reserved rear group
ambushes the crew as it advances. In `Fortress.tscn`, solo uses one
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
For forest bridges, **Forest Crossings** lists each bridge's top and bottom Y coordinates;
keep the solid riverbank wall pieces aligned with those openings.
**CoopEntries** contain editable attack markers with an **Approach** direction;
**AmbushTrigger** controls where reserved attackers activate. Courtyard markers
also reference physical entrance gates. **Parts** contain editable
`UpgradePart.tscn` crates with a **Part Type** property.

To install your music:

1. Put your audio files in `assets/music` and let Godot import them.
2. Open `scenes/story/Adventure.tscn` and select the **Adventure** root.
3. Drag your triumphant track into **Intro Music**, replacing the temporary cue.
4. Optional: expand **Chapter Music** to fifteen entries and assign a track to each
   chapter, in story order. Existing twelve- and thirteen-track arrays retain their
   matching sections; the three added stages reuse the preceding area track.
   Thirteen-track arrays use the outer gate's track for the combined boss encounter.
   Tracks restart when they finish.
5. Set **Intro Duration** to your track's length in seconds; the assembly and
   polishing animation retimes to match. The default is 16 seconds.

Edit section titles and briefings on each region's root. Adjust the opening
animation's part paths, robot jobs and weld seams in
`scripts/story/factory_assembly.gd`; crew layouts and startup timing are in
`scripts/story/intro_sequence.gd`. The temporary opening music and checkpoint
sound are original synthesized placeholders. The factory alarm is a softened,
lower-pitched adaptation of EZduzziteh's CC0 "Alarm" from OpenGameArt, with
gentle fades and a short gap between repetitions. Its source and license are
recorded in `assets/audio/CREDITS.txt`; existing shot, ricochet
and explosion effects are reused. Run `Adventure.tscn` directly with F6 for a solo
story test, or use the main menu for controller joining. Direct story runs use the
normal story save; classic mission previews continue to avoid changing saves.
The menu tank has animated tracks and a gentle turning motion. The tank being
assembled keeps its tracks still until it drives away at the end of the movie.

Moving tanks leave paired tread impressions that fade over five seconds in
all three battle modes. Marks follow distance traveled, turns and reversing;
they stop accumulating when parked, freeze while paused, and clear on retries
or checkpoint changes. Invisible White tanks still leave readable tracks.
A quiet tank-engine loop fades in with nearby movement, including turning,
and fades out when tanks stop. One shared loop stays capped at -24 dB even
with a large enemy wave. It uses ReadeOnly's CC0 `engine4_loop.wav` from
Freesound, filtered and crossfaded for a softer loop; source and adaptation
details are in `assets/audio/CREDITS.txt`. Adjust the lifetime, spacing, and
volume constants in `scripts/tank_ground_feedback.gd` to tune the effect.

## Scenery and tank detail

Story forests use large overhead tree canopies. Tanks, bullets and projectile
trails can pass beneath the leaves and disappear from view; the trunks are solid
and can reflect shells. This is visual concealment, and the crew HUD remains
visible. The forest includes scorched foliage and broad tree shadows.

Broken concrete, brickwork and steel wreckage add solid ricochet surfaces along
the story route. Their visible straight edges match the collision and aiming
geometry. Enemy routes are rebuilt around this cover at chapter start.

Each environment now uses its own editable cover pieces:

| Environment | Cover scene | Appearance |
| --- | --- | --- |
| Factory | `FactoryBarricade.tscn` | Bolted machinery, vents, status lights and hazard stripes |
| Wasteland | `WastelandRuins.tscn` | Decaying buildings with boarded windows, exposed brick and rusted salvage |
| Forest | `ForestMasonry.tscn` | Moss-covered bricks, creeping vines and small plants |
| Fortress | `FortressRampart.tscn` | Cut stone, reinforcing bands and brass crests |
| Village | `VillageBarricade.tscn` | Timber, rope bindings and small roadside flowers |
| Capital | `CapitalBarricade.tscn` | Damaged city facades, shattered windows, reinforcing steel and painted concrete barriers |

These scenes live in `scenes/story/props` and replace generic story rubble in the
existing layouts. Their positions and solid footprints are unchanged. The village's
detailed homes and wooden gate keep their separate artwork. Drag in a cover scene,
then edit **Size**, **Environment**, **Form** (Barrier / Building / Scrap), and
**Variation** in the Inspector. Buildings are used by the wasteland and capital;
the other environments use their own wall detail. Keep Rotation at 0, Scale at
(1, 1), and use **Size** for long horizontal or vertical pieces. The details follow
the long edge while physics and bank-shot aiming keep the same rectangle.

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
in stages with gripping robotic arms and a welding station, before the technician
polishes the finished tank on the conveyor. Its duration still follows the
Adventure root's **Intro Duration** setting.

## Tank handling

Tanks build speed and brake over a short distance. Direction changes carry a
little momentum, and the hull builds up its turn instead of snapping around.
Both campaigns use directional movement: WASD moves the tank in the direction
you press, with the hull turning to follow. Classic Missions also accepts the
arrow keys; True Campaign supports the controller's left stick. Aiming remains
independent of the heavier hull. Repairs stop both movement and turning immediately.

For tuning, open `scenes/story/StoryTank.tscn` (campaign crew) or
`scenes/tanks/Tank.tscn` (classic missions and duels), select the tank root, and
expand **Handling** in the Inspector:

- **Acceleration Time:** 0.22 seconds to build full forward speed from rest.
- **Braking Time:** 0.14 seconds to stop from full forward speed.
- **Turn Response:** 0.12 seconds to build or stop a full-rate turn.

Larger values add more weight. **Turn Speed** controls the maximum hull turn rate;
both campaign players use a turn rate of 6 for directional input (Classic Missions
sets this when spawning the player). Duels retain their original steering controls.
Enemies use the same momentum, with braking before route corners and recovery
that still avoids mines.

## Single-player campaign

Clear all enemy tanks to advance through 50 missions. You start with three lives;
one hit destroys your tank. Press **Enter** after a win to advance or after a loss
to retry. Cleared missions unlock in the menu and save automatically, so you can
replay them or resume from your highest unlocked mission.

Choose **Classic Missions → Debug Missions** to start any of the 50 missions
without unlocking or overwriting normal progress. Debug runs show **DEBUG · NO
SAVE**. Pause and choose **Debug Missions** to switch to another mission with
three fresh lives. Losing all three lives retries the same debug mission; clearing
a mission advances normally. Return to the main menu and use **Play Missions**
to resume your regular unlocks.

- **WASD or arrow keys:** Move up, left, down, or right, with momentum and hull
  turning matching True Campaign. Diagonal movement keeps the same top speed.
- **Mouse:** Aim the turret independently of the body.
- **Left click or Space:** Fire (five simultaneous shots).
- **E:** Place a mine (two simultaneous mines).
- **Esc:** Pause / resume, including enemy AI, shots, and mine fuses.

Mines arm after 0.75 seconds and explode on proximity, a bullet hit, a nearby
blast, or after an eight-second fuse. Mines and returning shots can kill their
owner and other tanks. Mines chain together. Tanks do not take contact damage.

Crumbly, cracked masonry reflects shells and blocks tanks like other walls, but
one nearby mine blast destroys it. Mines measure distance to the wall's nearest
edge, so you can plant beside a wide wall and retreat before it arms. Breaches
update collision, enemy routes and ricochet aiming immediately. A retry restores
the walls. Classic missions 7, 8, 12, 20, 25, 30, 35, 40, 45 and 50 and thirteen
story areas include this cover. In Godot, instance
`scenes/levels/pieces/CrumblyWall.tscn` into a mission or a story region's **Walls**
or **Rubble** container; adjust **Size**, **Environment** and **Variation**.

The campaign loads 50 editable mission scenes. Their starting layouts and enemy
placements preserve the original connected arenas. Enemy types debut at these
missions and mix into later encounters:

| Enemy | Debut | Movement | Bullets | Fire / aim | Ricochets | Live shots | Mines | Behavior |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Brown | 1 | Stationary | Normal | Slow | 1 | 1 | 0 | Passive |
| Ash | 2 | Slow | Normal | Slow | 1 | 1 | 0 | Defensive |
| Marine | 5 | Slow | Fast missiles | Slow | 0 | 1 | 0 | Defensive |
| Yellow | 8 | Normal | Normal | Slow | 1 | 1 | 4 | Incautious |
| Pink | 10 | Slow | Normal | Fast | 1 | 3 | 0 | Offensive |
| Green | 12 | Stationary | Fast missiles | Fast | 2 | 2 | 0 | Active |
| Violet | 15 | Fast | Normal | Fast | 1 | 5 | 2 | Offensive |
| White | 20 | Slow | Normal | Fast | 1 | 5 | 2 | Offensive |
| Black | 50 | Very fast | Fast missiles | Fast | 0 | 3 | 2 | Dynamic |

Yellow deploys mines rapidly. Green predicts the player's future position and
only fires missiles when it finds a valid one- or two-ricochet path. It never
fires directly at the player and holds fire when no bank angle is available.
All fast-shot tanks (Marine, Green and Black) fire missiles with visible exhaust
and a longer smoke trail. White fades to invisibility
at mission start while leaving visible ground tracks. Defensive tanks keep their
distance and evade threats; offensive tanks pursue; Black alternates pursuit and
retreat. AI avoids firing through allies, but friendly fire remains possible.
Routes account for the tank's round body at wall corners. Enemies clear tight
turns before advancing to the next route point; if movement stalls, they back
into checked free space and find a fresh route while still avoiding mines.

Campaign shots have no time limit. A ricochet is a reflection before the final
wall hit: the player's one-ricochet shots break on their second wall hit;
Green's two-ricochet shots break on their third. Marine and Black shots break on
their first wall hit. All projectiles, including missiles, can intercept
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
- `tests/tank_weight_smoke.gd`: Actual keyboard/controller acceleration, cornering and reversal, controlled coasting, analog speed, independent aiming, repair/revive locks, wall collisions, consistent handling at 30/60/120 physics ticks, and matching movement in both campaigns.
- `tests/tank_kiss_smoke.gd`: Tank contact effects across duel, classic, and four-player co-op; cooldowns, pause, and round cleanup.
- `tests/duel_smoke.gd`: Duel regression checks.
- `tests/campaign_smoke.gd`: Campaign, AI, mine, and mission checks.
- `tests/projectile_smoke.gd`: Projectile interception and ammunition checks.
- `tests/enemy_navigation_smoke.gd`: Rounded corner clearance, the actual stage 15 Commander escaping a previously trapped position, both boss phases, physical back-out and replanning, and mine-safe recovery for solo and four-player crews.
- `tests/enemy_spacing_smoke.gd`: Three- and seven-tank alternate routes and actual movement in Classic Missions and solo/four-player story, pair behavior, narrow-passage fallback and mine-safe crowd detours.
- `tests/layout_smoke.gd`: Authored layout loading, wall editing, navigation, and direct mission previews.
- `tests/story_smoke.gd`: Co-op inputs, tutorial, story progression, choices and checkpoints.
- `tests/onboarding_smoke.gd`: Stage protection and fades, readable lesson progression, both tutorial skips, fortress balance, and checkpoint migration.
- `tests/robot_assembly_smoke.gd`: Gripped transport, fitted parts, reachable robot poses, seam welding, and complete one-to-four-player assembly and tutorial handoff.
- `tests/intro_startup_smoke.gd`: Engine cue timing, retimed intros, exhaust and track motion, the worker's escape, real tutorial movement reactions, pause, retry, and skip cleanup.
- `tests/repair_mines_smoke.gd`: Real repair holds and controller ownership, movement lock, mine detours and blocked lanes, and visible White tank introductions.
- `tests/field_guide_smoke.gd`: Pause-menu guide access, all nine enemy entries, controller navigation, frozen combat, and returning to the same battle in every mode.
- `tests/factory_escape_smoke.gd`: Looping alarm and red pulse, pause behavior, real tank blocking and shell damage at the blast gate, retry, and crew escape.
- `tests/story_expansion_smoke.gd`: Extended routes, timed offscreen pursuit, village arrival, and save migration.
- `tests/checkpoint_debug_smoke.gd`: Menu and co-op lobby checkpoint selection, all stage starts, paused combat, controller ownership, retries, safe transitions, and normal save preservation.
- `tests/mission_debug_smoke.gd`: All 50 mission starts, menu and pause selection, retries, completion, and isolated regular unlocks.
- `tests/crumbly_mines_smoke.gd`: Real shell ricochets, tank collisions, mine-only wall breaches, navigation updates, retry restoration, self/friendly mine damage, and mine-layer escapes.
- `tests/region_finales_smoke.gd`: Entering and clearing all three added stages, protected powerup selection, both forest bridges, and soundtrack compatibility.
- `tests/coop_smoke.gd`: All party-size budgets, squad tactics, fortress gates, role pickups, bank damage, and saved parts.
- `tests/scenery_smoke.gd`: Real ricochets off rubble/trunks and firing beneath foliage.
- `tests/environment_barricades_smoke.gd`: Real shell bounces on all six cover families, portrait resizing, editable scene serialization and matching biome styles.

Campaign layouts are editable in the numbered mission scenes. Live tank and
physics instances are created at runtime; use Godot's **Remote** scene tree while
running to inspect those. The local duel still generates a new maze each round.

## Verify gameplay

After Godot has imported the project, run:

```sh
godot --headless --path . --script tests/tank_weight_smoke.gd
godot --headless --path . --script tests/tank_kiss_smoke.gd
godot --headless --path . --script tests/duel_smoke.gd
godot --headless --path . --script tests/campaign_smoke.gd
godot --headless --path . --script tests/projectile_smoke.gd
godot --headless --path . --script tests/enemy_navigation_smoke.gd
godot --headless --path . --script tests/enemy_spacing_smoke.gd
godot --headless --path . --script tests/layout_smoke.gd
godot --headless --path . --script tests/story_smoke.gd
godot --headless --path . --script tests/onboarding_smoke.gd
godot --headless --path . --script tests/robot_assembly_smoke.gd
godot --headless --path . --script tests/intro_startup_smoke.gd
godot --headless --path . --script tests/repair_mines_smoke.gd
godot --headless --path . --script tests/field_guide_smoke.gd
godot --headless --path . --script tests/factory_escape_smoke.gd
godot --headless --path . --script tests/story_expansion_smoke.gd
godot --headless --path . --script tests/checkpoint_debug_smoke.gd
godot --headless --path . --script tests/mission_debug_smoke.gd
godot --headless --path . --script tests/crumbly_mines_smoke.gd
godot --headless --path . --script tests/coop_smoke.gd
godot --headless --path . --script tests/scenery_smoke.gd
godot --headless --path . --script tests/environment_barricades_smoke.gd
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
ricochets, self-inflicted and friendly mine blasts, armor,
revives, targeting another player when P1 is down, pause/disconnect recovery,
chapter geometry/routes, damaged tanks, boss phases/reinforcements, both village
choices and repairs, persistence, checkpoint retry, crew exit gating, and the
capital ending. Tests use their own save path and never overwrite story progress.
