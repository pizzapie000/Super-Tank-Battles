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

Assign Player 1–4 in **Player Setup** on the main menu, then choose **New Adventure**.
The same saved controls apply to every mode: missions use Player 1 only, local
duels use Players 1–2, and the campaign uses every active seat. Use consecutive
seats, with unused seats set to Off. Keyboard + mouse / trackpad, shared ESDF / arrows,
ordinary gamepads, and calibrated Wii Remotes are available here. Each controller
can occupy only one seat. Saved Wii assignments follow the remote’s identity;
returning to the main menu starts its bridge automatically when a Wii seat is saved.
The laptop trackpad works with **Keyboard + mouse / trackpad**; no external mouse
is required. After a shared-keyboard duel, choose that option for Player 1 and
set the other seats to **Off** to return to a solo WASD adventure.
The screen fades to black for a short tank assembly and polishing sequence with
an original temporary music cue. Three articulated handling robots grip the
chassis, tracks, armor, turret and cannon, seat them, then open their jaws and
retract. A separate welding robot follows the fitted seams with an arc, sparks
and a little smoke. Each joined player gets an assembly bay with their actual
tank color and number; crews of two to four are built together.
Enter / controller A or Start (Wii A / Plus) skips the intro.
While the technician polishes, the engine cranks and catches with a short puff of
exhaust. The tank rolls forward, and the startled worker drops his cloth and runs
away. The engine sound and animation follow **Intro Duration**; **Engine Start Sound**
on `Adventure.tscn` can replace the original startup cue. Skipping stops the cue
immediately. If skipped before the worker runs, he flees when a crew tank first
moves in the tutorial. Retry resets him, and pausing freezes his reaction.

For testing, choose **True Campaign → Debug Checkpoints** on the main menu.
Pick a numbered stage; it starts with the player controls already selected on the main menu.
The list reads stage titles directly from `StoryWorld.tscn`, including added levels.
Debug runs skip the opening movie and start at the selected stage with a fresh
crew and two supplies, with no checkpoint countdown. They never change
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
The stages each have their own checkpoint, powerup carriers, and co-op attack entries.

Checkpoints start immediately after the short screen transition, with no
powerup-selection countdown or tank fade. The HUD shows the stage title and
checkpoint number. The factory tutorial remains safe for practice.

The tutorial has six large, readable lesson cards: welcome, movement, firing at
two inactive tanks, mines, equipping a powerup, and crew support. Each stays until
the practice is complete, its reading time has elapsed, and a player presses
**Enter / A**. The inactive tanks cannot fire, and the crew cannot take tutorial
damage. Confirm the final lesson to sound the alarm and activate real security.
The main menu's **Skip factory tutorial** checkbox remembers your preference.

Control hints follow the assigned, connected player controls throughout the
tutorial, intro, HUD, menus, missions and duels. Keyboard-only games show keyboard
buttons; ordinary controller and Wii prompts appear only for connected devices
assigned to players in that mode. Mixed crews see each control family in use.
Hints update when devices connect, disconnect, or change seats; an unused paired
Wii Remote does not change a keyboard player's tutorial.

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

Player 1 starts with keyboard + mouse; Players 2–4 start Off. Change the four
main-menu **Player Setup** dropdowns to choose each player's controls. Use **Wii
Remote Setup** below them to pair or calibrate remotes, then assign them to seats.
No separate mode lobby is required. Controls are saved and reused across modes.
ESDF shared-keyboard extras: G mine, H interact, T repair. Arrow-key extras:
/ mine, . interact, , repair. Shared-keyboard aiming follows the tank's hull.

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
state, or return to the main menu to change Player Setup. Physical pads still need a
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
  free repair refuge and the upgrade shop. You can travel back from the capital with your crew.
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

Flashing, labeled enemy tanks carry campaign powerups. Their movement, armor or
weapons reflect that upgrade. Destroy one, including with a mine, to make it drop
a labeled powerup at its position. Move beside the drop and press **F** on keyboard
or **A** on a controller or Wii Remote to equip it. A nearby prompt identifies the
player, button, and whether it replaces or improves their current upgrade.
Walking over drops or holding the button before approaching never equips them.
Shared keyboard seats use **H** (ESDF) or **.** (arrows). Any living crew member can
collect a drop, regardless of who destroyed the carrier. One press equips only
the nearest drop; drops wait until collected or the checkpoint ends. Equipping
is disabled while paused.
Carriers add no extra enemies to an encounter;
bosses, Green ricochet specialists and White cloaking reveals keep their usual roles.

| Powerup | Level I benefit | Higher levels |
| --- | --- | --- |
| Loader | 0.22s reload | Faster reload |
| Armor | Four armor, slower movement | Five / six armor |
| Bank Shot | Extra bounce and ricochet damage | More bounces and bank damage |
| Engine | Faster movement, two armor | More speed |
| Gatling | Rapid fire, larger shell capacity | Faster reload and more active shots |
| Shotgun | Five-shell spread | Faster reload and more active blasts |
| Heat Seeker | Smoke-trailing missiles seek enemies | Faster reload and stronger steering |

Each tank has one upgrade slot. A different type replaces it at level I; collecting another
copy of the same type raises its level, up to III. Campaign weapons do not use the
PvP ammo limits. Friendly fire, self hits and shell collisions remain active.
Collecting a drop also gives one supply outside training. Types and levels carry between
checkpoints and Continue saves. Retry restores the stage's starting loadout and
supplies, so repeating a kill within the stage cannot stack rewards.

Spare the village to unlock its **Upgrade Shop**, beside the green repair station.
The shop opens after the chief's decision; hold **F / A** beside the gold workbench
to return later. Choose a crew member, upgrade their current powerup (2 supplies
to level II, 4 to III), or switch types for 3 supplies. Switching starts at level I.
Purchases use shared supplies, preserve the crew's injuries, and save together
with the village decision. Shopping pauses combat and works with Wii pointing,
stick navigation, normal controllers, or keyboard and mouse. Raiding the village
closes the shop and repair refuge in exchange for the existing immediate reward.
Old saved parts load at level I.

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
`UpgradePart.tscn` design markers with a **Part Type** property. These are hidden
at runtime and select the passive upgrades carried by marked enemies. The first
carrier in a combat section rotates through the three special weapon types.

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

Set Players 1–2 in the main-menu **Player Setup**, then choose **Play Local Duel**.
The match starts directly with those controls. Missing or duplicate assignments
cannot start a match. A controller disconnect pauses both tanks; reconnect and
resume, or choose **Player Setup / Main Menu** from pause to change the setup.

Shared keyboard keeps the original controls:

| Player | Drive | Turn | Fire |
| --- | --- | --- | --- |
| Royal blue / P1 (left) | E / D | S / F | Q |
| Orange / P2 (right) | Up / Down | Left / Right | M |

With keyboard + controller, P1 uses WASD / arrows to move, mouse to aim and
Click / Space to fire. Controller players use left stick to move, right stick
to aim, RT / R2 or RB / R1 to fire, and Start / Options to pause or resume.
Both setups use the campaign's directional driving and weighted hull movement.
Shared-keyboard steering stays relative to the tank's hull.

Two different weapon crates appear **five combat seconds after GO**, followed
by another every seven seconds, up to three on the map. They spawn in clear
maze corridors away from tanks, expire after 22 seconds, and freeze while paused.
Drive over a crate to equip it; a new pickup replaces the current weapon.

| Weapon | Ammunition | Behavior |
| --- | --- | --- |
| Gatling | 36 rounds | Rapid automatic fire; up to 16 active shells. |
| Shotgun | 5 blasts | Five spreading pellets per blast; up to 20 active pellets. |
| Heat seeker | 3 missiles | Smoke trail; turns toward the nearest other living player at a limited rate, so it can be dodged or shot down. |

When special ammunition runs out, normal shells return with their five-shot
cap. Existing projectiles keep flying. Every shot can destroy another shot or
hit any tank, including its owner; guided missiles never *target* their owner,
but can still hit them after a ricochet. Shots have no time limit and break on
their third wall hit. One hit ends the round; first to seven points wins. A new
connected maze, empty loadouts and a fresh five-second timer start each round.
The HUD shows each player's controls, weapon and ammunition.

- **Esc:** Pause or resume.
- **R:** Generate a new arena while keeping the score.
- **Enter:** Start a rematch after a match ends.
- **Start / Options:** Controller pause/resume, or a rematch after the final score.

### Wii Remote + Nunchuk setup (experimental)

The project now includes a native macOS bridge for up to four directly paired
Nintendo Wii Remotes / Wii Remote Plus with wired Nunchuks and a powered IR
sensor bar. It works with Classic Missions, True Campaign and PvP; keyboard and
ordinary gamepads continue to work alongside it. Bluetooth pairing, Nunchuk
input, pointer calibration and in-game aiming have been tested with a physical
Nintendo Wii Remote Plus on this Mac. Automated checks also use simulated
reports; other controller models and four-remote setups still need hardware testing.

1. Restart Godot after the project update, then run the main menu and choose
   **Wii Remote Setup**. The same setup is accessible from both player lobbies.
2. Choose **Start Wii Bridge**. In the bridge window, choose **Pair Remotes**,
   or use **Open Pairing App** on the setup screen. Allow Bluetooth access if
   macOS asks. The locally compiled pairing utility is installed at
   `~/Applications/WiimotePair.app`.
3. Press the red **SYNC** button under the remote's battery cover once, then
   wait for **Wii Remote Connected** in WiimotePair. The updated helper keeps
   the pairing session alive and verifies real controller input before calling
   it ready. For more remotes, choose **Pair Another Remote** and repeat.
   Quit WiimotePair after the remotes are ready. **Show Details** displays the
   Bluetooth and native controller stages if connection stalls.
4. Connect the Nunchuks, power your sensor bar separately, wake the remotes
   with **A** and choose **Scan** in the bridge. Red SYNC is for fresh pairing;
   regular buttons reconnect an already paired remote. The bridge pauses
   connection attempts while WiimotePair is open. Close Dolphin and other Wii controller
   software so they do not compete for the remotes' Bluetooth HID channels.
5. Return to the game. Select a remote and choose **Calibrate Pointer**. Keep
   the remote upright and the bar in view; aim physically at the top-left
   target and press **A**, then at the bottom-right target and press **A**.
   Repeat for the other remotes. Calibration handles reversed camera axes and
   saves per remote, independently of its current player slot.
6. If the stick drifts, release it and choose **Center Nunchuk Stick**.
   The test area shows stick movement, buttons and sensor-bar tracking.
7. Return to the main menu and assign each remote to Player 1–4 in **Player Setup**.
   Missions use only Player 1; PvP uses the first two seats; campaign uses every active seat.

| Wii control | Action |
| --- | --- |
| Nunchuk stick | Drive with the same weighted directional movement as controllers. |
| Point at the screen | Aim the turret; each player has a separate colored cursor. |
| Wii Remote B | Fire. |
| Nunchuk Z | Place a campaign mine. |
| A | Select / confirm, help / revive, or open the village workshop. |
| Nunchuk C or Minus | Hold to repair in battle; hold to skip the tutorial during training. |
| Plus | Pause/resume; skip the intro; continue / retry a mission result. |
| 1 | Back/leave in lobbies (also maps to the mine button in battle). |

Menus also work from the Wii Remote: point at a button and press **A**, or use
the Nunchuk stick / directional pad to move the highlight and **A** to select.
Use **B**, **Z**, or **1** to go back. Dropdowns open with **A**; choose an item
with the stick / pad, then confirm with **A** or cancel with a back button.
Choose each player’s controller from the shared setup dropdowns. Modes launch
directly from the main menu. **Plus** pauses during battle; missions also use
**A / Plus** to continue or retry after a result.
Skip the assembly cutscene with **A** or **Plus**; skip factory training by
holding **C** or **Minus** for two seconds. The main-menu tutorial checkbox is
also selectable with the remote. Menus fall back to stick / pad navigation if
the sensor bar leaves view, without injecting keyboard or mouse input into macOS.

Losing sight of the bar retains the last aim. Losing the bridge's input stream for 0.75
seconds releases its buttons and pauses active play. The bridge also drops a
remote if that remote has not reported input for one second. Unplugging a Nunchuk also
pauses its match. The bridge stays open across game scenes and stops when the
game process exits. Click its Dock icon to reopen a closed bridge window.
The bridge window includes connection errors and a **Retry Camera** button.
The game opens the `.app` bundle through macOS Launch Services so Bluetooth
permission belongs to **Wii Remote Bridge**, independently of Godot. Its
permission prompt is asynchronous; if access is denied, enable the bridge in
**System Settings → Privacy & Security → Bluetooth**. Closing its window leaves
the bridge running; **Quit Bridge** stops it, and **Start Wii Bridge** opens it again.
If a listed remote cannot connect, quit WiimotePair, press A and choose Scan.
If pairing never completed, use the updated pairing helper with red SYNC and
wait for controller input; a saved Bluetooth entry alone does not verify a
working controller connection. As a
connection-only test, turn off nearby Wii/Wii U consoles; a powered sensor bar
is needed for aiming, not for pairing or testing the remote's buttons.

The bridge reads Nintendo's physical Bluetooth controller through macOS IOHID,
matching vendor 057e and products 0306/0330 and excluding synthetic gamepads.
macOS owns the low-level Bluetooth HID channels; the bridge does not compete
for them with direct L2CAP connections. It reads raw controller reports:
Nunchuk reports and raw IR points arrive together in report 0x37. The native
bridge sends versioned, session-token-protected JSON only to the game's
loopback socket. It does not install a kernel driver, login item or global
keyboard/mouse injector. It does not enable SDL's competing Wii HID driver.
The ordinary gamepad path still uses Godot's SDL controller support.

The bridge was built for this Apple Silicon Mac. Its source and build scripts
are in `tools/wii/`; **build.command** rebuilds and signs the bridge locally for
the current Mac architecture. **build_pairing.command** builds the separate
pairing utility from the included Dolphin release source; it refuses to replace
an existing installation. Both need Apple's Command Line Tools. The pairing
app's source and GPL license are also included inside its installed bundle.
The official prebuilt pairing download failed signature verification here, so
it was not installed. The local source build now incorporates the
[WiimotePairPlus](https://github.com/GabrielLascoskiFerraz/WiimotePairPlus)
pairing-session and physical controller fixes, with local app entry and checks.
Its upstream commit and GPL notices are in `tools/wii/pairing-source/UPSTREAM.txt`.
macOS security settings were not changed.

The protocol implementation follows the primary WiiBrew
[Wii Remote](https://wiibrew.org/wiki/Wiimote) and
[Nunchuk](https://wiibrew.org/wiki/Wiimote/Extension_Controllers/Nunchuck)
documentation. The separate pairing code is from
[Dolphin's WiimotePair 1.0](https://github.com/dolphin-emu/WiimotePair/tree/1.0);
its notices and license are retained in `tools/wii/pairing-source/`.
MotionPlus gyro aiming, Classic Controllers, Balance Boards, DolphinBar USB
transport, Windows/Linux bridges and packaged game exports are not implemented
by this first Mac development setup. The powered sensor bar supplies IR light;
it does not need to be connected to the game as a controller.

## Project layout

- `scenes/game/MainMenu.tscn`: Mode selection and enemy guide.
- `scripts/input/player_setup.gd` / `player_hub.gd`: Saved global controls and four main-menu seats.
- `scenes/story/Adventure.tscn`: Story flow, music slots, co-op and shared camera.
- `scenes/story/StoryWorld.tscn` / `regions/`: Connected, editable story locations.
- `scripts/story/`: Tutorial, story state, crew controls, damaged enemies and bosses.
- `scenes/story/props/`: Editable overhead trees, solid rubble and animated conveyors.
- `scripts/tank_art.gd`: Shared tank components for gameplay and assembly animation.
- `scenes/game/CampaignArena.tscn`: Single-player campaign.
- `scenes/game/DuelArena.tscn`: Local two-player arena.
- `scripts/input/mission_tank.gd`: Player 1 controls for singleplayer missions.
- `scripts/pvp/`: PvP input assignments, temporary weapons, crates, and match rules.
- `scripts/input/` / `scenes/game/WiiSetup.tscn`: Wii bridge input, calibration, controller abstraction and setup.
- `tools/wii/`: Native Mac bridge, pairing source, local build scripts and notices.
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
- `tests/wii_input_smoke.gd`: Native report fixtures through UDP, per-remote calibration, lobby joining, independent PvP/campaign controls, repairs, mines and disconnect handling.
- `tests/pvp_controls_smoke.gd`: Setup, simulated controller hotplug, independent keyboard/analog driving and aiming, trigger fire, pause, disconnect and rematch.
- `tests/pvp_weapons_smoke.gd`: Five-second pickup timing, collection/cleanup, gatling cap, shotgun spread, wall-safe muzzles, guided hits and missile interceptions.
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
- `tests/checkpoint_debug_smoke.gd`: Menu and co-op checkpoint selection, all stage starts, paused combat, controller ownership, retries, safe transitions, and normal save preservation.
- `tests/mission_debug_smoke.gd`: All 50 mission starts, menu and pause selection, retries, completion, and isolated regular unlocks.
- `tests/crumbly_mines_smoke.gd`: Real shell ricochets, tank collisions, mine-only wall breaches, navigation updates, retry restoration, self/friendly mine damage, and mine-layer escapes.
- `tests/region_finales_smoke.gd`: Entering and clearing all three added stages without a countdown, deliberate powerup equipping, both forest bridges, and soundtrack compatibility.
- `tests/coop_smoke.gd`: All party-size budgets, squad tactics, fortress gates, drop collection, bank damage, and saved parts.
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

- `tests/global_setup_powerups_smoke.gd`: Four saved player identities, Wii missions, singleplayer isolation, drop collection, real special weapons, workshop costs and level persistence.
- `tests/control_hints_smoke.gd`: Keyboard-only, Wii-only and mixed tutorials; unused and disconnected devices; menu seat changes; singleplayer mission isolation; matching HUD, movie and duel prompts.
- `tests/player_setup_dropdown_smoke.gd`: Real dropdown selections from duel controls back to keyboard/trackpad, repeated switches, Off seats, saved settings, Wii assignments and duplicate-control recovery.
- `tests/forest_performance_smoke.gd`: Thousands of reference ray comparisons, parallel and inside-wall edge cases, broken-cover refresh, mine-safe navigation fallback, cached scenery, village smoke and staggered enemy planning.
- `tests/navigation_search_smoke.gd`: Independent minimum-cost route comparisons, dynamic mine removal, broken-cover connectivity refresh, both Forest 3 bridges, and 2,000 exact wall-clearance comparisons.

The forest optimization keeps the same enemy counts, bank-shot candidates, mine
avoidance and scenery. Ricochet searches reuse prepared wall boxes and native
intersection tests; static terrain keeps its canvas commands until something
changes. Initial enemy planning stays staggered instead of bunching into one frame.
Cover and flank selection check cached connectivity instead of building throwaway
routes. Ordinary routes use Godot's native A* graph; routes with mines or crowd
costs use a heap-backed search. Short steering checks skip distant walls before
testing full circular tank clearance. Breaking cover rebuilds the graph and its
connectivity labels, while mines and traffic remain specific to each request.

For a repeatable CPU benchmark of **Deep in the Ruins** (the second forest stage),
run `godot --headless --fixed-fps 60 --path . --script res://tests/forest_benchmark.gd -- 1`.
Use `-- 4` for the four-player encounter. Add a checkpoint argument to select
another forest stage: `-- 1 7` or `-- 4 7` benchmarks **The Overgrown Crossroads**
(Forest 3); checkpoint `5` selects Forest 1, and `6` selects Forest 2.
The test prints median, 95th-percentile
and worst frame work in milliseconds after warming up. These measure CPU work
per simulated frame, rather than displayed FPS. Saves and layouts are untouched.
