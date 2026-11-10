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
- **Movement (Syphon Filter, from the user's reference clip, smoothed after playtest):** you run where you push. Speed ramps smoothly (22 m/s² up, 30 down) from a 7 m/s jog on a light push to a 13 m/s sprint on a full push. The run cycle derives stride length from speed so feet don't slide, the body bobs once per footfall, shoulders counter-rotate the hips, and the mech banks into turns. The camera sits centered behind and swings in as you turn. WALK (L3) is quiet at 4.5 m/s. L2/R2 sidestep. B rolls while moving (bullets pass through) and crouches when standing. A jumps. The mechs get less vertex jitter than the city so moving bodies stay smooth
- **Lock-on (R1), full body:** grabs the best target in front within 110 m with a clear line. You run and gun freely while the upper body tracks him. The right stick slides an aim dot from center mass toward his head (up), gun arm (sideways) or leg (down); full deflection lands right on the part, and the HUD names the part under the dot. Bullets hit whatever part they actually land on. The lock settles over about 1.1 s standing still, slower while you move and much slower while he moves, and his dodge rolls shake it. Spread goes from 4.5 m down to 0.35 m. Full lock does 4 damage instead of 2
- **Body parts:** HEAD takes triple damage, and losing its 8 HP takes the head off and kills. ARM has 8 HP, then the gun arm comes off and he's disarmed. LEG has 10 HP, then the leg comes off at the knee and he moves at a third of the speed. Limbs pass half their damage to the body, and pieces fly off as physics debris
- **Enemy evasion:** when you're locked on, they jink at full run speed and switch direction every 0.7 to 1.5 s. When your lock passes about 55% or you open fire, they dodge-roll sideways (every 2.2 to 4 s at most)
- **Thumb conflict fix (playtest):** you couldn't hold the aim and press fire with the same thumb. Fire moved to R2 (X still works) so the right thumb stays on the aim stick; L2 is a dodge roll; the sidestep buttons are gone (the left stick strafes while locked). On a phone, while locked, HEAD / ARM / LEG / BODY buttons appear: tapping one makes the aim stick to that part, so the thumb is free to fire. Number keys 1-4 do the same on keyboard
- **No sound rings or alert banners** (removed after playtest). Hit feedback stays
- **Manual aim (L1):** tight over-the-shoulder crosshair, walking pace, 4-damage shots that land exactly on the crosshair; whichever part the bullet hits takes the damage
- **Silent kill:** a full-lock shot on an enemy who isn't fighting you kills instantly
- **Enemy combat:** holds 22 to 48 m, strafes, and before every 3-round burst puts a red laser sight on you for 0.75 s. His accuracy drops the faster you move, and rolling dodges entirely. A shout when he spots you alerts others within 80 m. Lose him for 6 s and he goes back to searching
- **Armor:** you have 20, enemies 16, and enemy bullets do 1 each
- **Disarmed enemies** charge and slam you (3 damage). The visor flashes white for 0.7 s before the swing
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
