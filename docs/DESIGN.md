# Mech Mania: Design Doc

> Living document. **Locked** = decided, **Open** = still being discussed.
> The user designs and makes the calls. Claude builds, and either of us can challenge or pitch ideas.

## The pitch

Giant humanoid mechs that move and shoot like Syphon Filter, in a destructible PSX Tokyo. Lock on, strafe, roll, and use buildings as cover until they get shot apart. A light stealth layer: sneak into position for a one-shot silent kill, or get spotted and fight.

## Inspirations

| Source | What we take from it |
|---|---|
| Syphon Filter (PS1) | Camera behind your back, strafing, combat roll, hold-to-lock aiming that tightens over time |
| Metal Gear Solid | Sneaking, sound, takedowns from behind |
| PS1-era mech games | Lanky low-poly machines, wobbly vertices, warped textures. Vibes only: no names, designs or signature parts from real franchises |

## Locked decisions

- **Name:** Mech Mania (renamed from Caveman Catchers, Nov 9 2026)
- **Look:** heavy, over-emphasized PSX. Vertex snapping and affine texture warping on every surface, 200-line screen with dithering and color banding, pixel textures, faceted low-poly. Lanky proportions everywhere
- **Scale:** mechs are about 10 m. Shops and houses come up to the chest, offices are head height, and a few apartment towers loom over you
- **Bodies:** humanoid mechs (decided Nov 9 2026): forward knees, broad chest, neck, visor helmet, shoulder armor, backpack thrusters, a rifle in both hands. Still lanky. The bird-legged sword mechs were dropped
- **Hero mech:** khaki-grey with rusty orange trim, red visor slit, antenna
- **Enemy mechs:** crimson lacquer with gold trim, horned shoulders, a crest, and a visor bar showing mood (cyan calm, amber suspicious, red fighting)
- **Map:** a small night-time Tokyo neighborhood, 3×3 blocks around a central plaza. Neon signs, lit windows, vending machines, power poles, street lamps and parked cars. Tall indestructible towers ring the edge
- **Destruction:** props fly when touched or shot. Buildings take hits (6 to 30 depending on size) and then collapse into chunks and rubble, so cover wears away. Rolling into a building up to 13 m tall smashes through it. Collapses are loud (80 m)
- **Movement (Syphon Filter):** you always face down the camera; the left stick strafes and backpedals, the right stick turns. Light tilt walks quietly (4.5 m/s), full tilt jogs loudly (10 m/s), crouch creeps silently (3 m/s). The roll (0.55 s) makes you untouchable through most of it
- **Shooting:** hold AIM to lock onto the enemy nearest the crosshair (within 110 m, with a clear line). The lock fills in about 0.9 s standing still, twice as long while moving. Spread shrinks from 5 m to 0.3 m as it fills. Full-lock shots do 4 damage instead of 2. Each shot loosens the lock by 20%. 12-round magazine, 1.3 s reload. Without a lock you fire straight down the crosshair
- **Silent kill:** a full-lock shot on an enemy who isn't fighting you kills instantly
- **Enemy combat:** holds 22 to 48 m, strafes, and before every 3-round burst puts a red laser sight on you for 0.75 s. His accuracy drops the faster you move, and rolling dodges entirely. A shout when he spots you alerts others within 80 m. Lose him for 6 s and he goes back to searching
- **Armor:** you have 20, enemies 16, and enemy bullets do 1 each
- **Clarity:** tracers, muzzle flash, sparks on hits, a hit marker on the reticle, enemy health bars once hurt, a red screen flash when you're hit, and text for CRITICAL / MECH DOWN / SILENT KILL
- **Platforms:** AYN Thor (APK) and iPhone (web). Engine: Godot 4.7

## Previous directions (dropped)

Caveman catching, space chimp vs robot monkeys, PS1 horror watchman vs cymbal monkeys, then a human-sized scout mech punching soldiers (punching felt mushy, stealth was slow, soldiers were no match, movement felt bad), then giant bird-legged mechs with Bushido Blade swords (too slow, stances confusing, hard to tell what hit, the camera fought you). Now humanoid mechs with Syphon Filter gunplay.

## Ideas parked for later

- A melee finisher or kick up close
- Weapon pickups: shotgun, missile pod (big destruction), sniper
- Sound pass: heavy stomps, servo whine, rifle cracks, crumbling concrete
- Rain on the streets, neon reflections
- Enemy variants: a heavy that soaks damage, a fast flanker

## Open questions

1. What's the story: who are you, and why is this neighborhood a battlefield?
2. Is the silent kill too strong?
3. Should cover be manual (snap to walls) or just "stand behind a building"?
4. A full level goal beyond "beat 3 mechs"?
