# Caveman Catchers: Design Doc (working title, the game is now about mechs)

> Living document. Everything here is either **Locked** (decided) or **Open** (still being discussed).
> The user designs and makes the calls. Claude builds, and either of us can challenge or pitch ideas.

## The pitch

A PSX-style stealth brawler. You pilot a lanky scout mech through snowy woods at night. Sneak up on enemy soldiers and put them out quietly. If they catch you, it becomes a heavy, clumsy fistfight. Stealth is the smart play; brawling is the fallback.

## Inspirations

| Source | What we take from it |
|---|---|
| Metal Gear Solid 2/3 | Sneaking, vision cones, sound, takedowns from behind |
| Ape Escape 2/3 | Snappy grab mechanic, readable enemy moods ("?" / "!") |
| PS1-era mech games | Low-poly lanky machines, chunky textures, wobbly vertices. Vibes only: no names, designs or signature parts from any real franchise |

## Locked decisions

- **Look:** heavy, over-emphasized PSX. Every surface uses a custom shader with vertex snapping (shapes jitter and swim as the camera moves) and affine texture mapping (textures warp across each triangle). Low-res screen (200 lines), ordered dithering and color banding, nearest-filtered 16x16 pixel textures, faceted low-poly shapes, dark fog. The ground is cut into 2 m tiles like a real PS1 level so the warping stays readable
- **Proportions:** lanky everywhere. Long thin limbs, small heads, narrow waists. This is the main style signature on top of the PSX rendering
- **Hero:** a lanky scout mech, about 2.7 m. Reverse-jointed bird legs, wasp waist with an exposed spine, narrow cockpit chest with a slanted plate, shoulder blocks, two exhaust stacks, very long arms with big blocky fists, small head with one red sensor slit and a head lamp. Worn khaki-grey with rusty hazard stripes ([look](concept/mech-and-soldier.png))
- **Enemies:** lanky soldiers on foot, about 1.9 m (enemy mechs come later). Winter-camo coat, dark vest with pouches, radio pack, gas mask, helmet with a brow lamp that shows mood (pale = calm, amber = suspicious, red = fighting), shock baton with a glowing tip
- **Setting for the first area:** snowy woods at night with lamp posts and rusted shipping containers as mech-sized cover
- **Stealth takedown:** sneak up, GRAB lifts the soldier by the collar, tap GRAB to put him out. 4 taps if he never saw you, about 9 if he was wary. Stop tapping for a second and he twists free and fights. Each tap is a quiet servo whine. Subdued soldiers stay down in the snow ("zz"), knocked out, not killed
- **Getting spotted:** he shouts (soldiers within 12 m hear it and investigate) and comes at you. No instant game over
- **Brawl:** soldiers close in and swing overhead with the baton. Every swing is telegraphed (baton raised, tip flashing) for about half a second. PUNCH staggers them and is loud. You can't grab someone mid-fight unless he's staggered, and then GRAB throws him. Soldiers have 3 HP: three punches, or punch + throw. The mech has 6 armor; zero is MECH DOWN
- **Escape:** you outrun soldiers (5.2 vs 3.6 m/s). Out of sight for 5 seconds and they go back to searching
- **Light and dark:** head lamp starts off. On: you can see, but soldiers spot you from full range (12 m). Off: half range. Lamplight lights you up even with the lamp off
- **Detection:** sight (vision cones, blocked by rocks, containers and trees) and sound (footsteps, landings, punches, shouts). Sound makes soldiers investigate; only sight can spot you
- **Movement:** MGS-style. Light stick tilt sneaks quietly, full tilt stomps loudly, crouch creeps silently. Jump, but landings are loud
- **Target platforms:** AYN Thor (Android APK) and iPhone (web build). Desktop for testing
- **Engine:** Godot 4.7
- **Scope rule:** start super small. One soldier type, one area. Grow only from what's fun

## History (what we tried and dropped)

Caveman catching (Ape Escape × MGS), then an old space chimp vs robot monkeys, then a PS1 horror night watchman vs cymbal monkeys. Dropped along the way: burrows, instant game over, the radio-in alert countdown, the tranq gun (too strong), the big net, rubber hose style, the old-film filter. What survived into the mech version: the stealth AI, sound rings, light/dark stealth, the tap-to-subdue grab, touch controls, and the PS1 screen.

## Enemy types

**Locked: start with one soldier type.** More only once the stealth/brawl loop feels great.

| Type | When spotted | Status |
|---|---|---|
| Baton soldier | Shouts, then brawls with telegraphed swings | **Built** |
| Enemy mech | Mech vs mech brawl, much tougher | Planned |
| Lookout | Fires a flare that alerts the whole area | Parked idea |

Each type should have one clear reaction, so players can read a situation and plan.

## Tone

- Tense night stealth, but not gory. Soldiers get knocked out ("zz"), never killed on screen.
- Original designs only. No real franchise names, mech designs, or signature parts.

## Ideas parked for later

- Soldiers who find a knocked-out buddy raise the alarm (classic MGS)
- Enemy mechs, mech vs mech brawl
- Sound pass: wind, crunching snow under heavy feet, servo whines, baton crackle
- Hiding bodies, or a mech-size "drag"
- Fixed cinematic camera angles in places, like classic Resident Evil

## Open questions

1. Name: "Caveman Catchers" no longer fits. Needs a new title
2. Who are you, who are the soldiers, and why are you sneaking around?
3. What's the goal of a level beyond "put everyone down"? (reach a point, steal something, rescue someone)
4. Mech upgrades or different mech frames?
5. Level structure: hub with missions, or linear levels?
