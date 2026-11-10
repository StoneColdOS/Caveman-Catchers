# Mech Mania: Design Doc

> Living document. **Locked** = decided, **Open** = still being discussed.
> The user designs and makes the calls. Claude builds, and either of us can challenge or pitch ideas.

## The pitch

Giant-mech sword duels in a destructible PSX Tokyo. Bushido Blade tension (few hits, every swing readable) with a light stealth layer: sneak up for a one-cut kill, or get spotted and duel.

## Inspirations

| Source | What we take from it |
|---|---|
| Bushido Blade (PS1) | Stances, few-hit kills, crippled legs, slow tense duels |
| Metal Gear Solid | Sneaking, sound, takedowns from behind |
| PS1-era mech games | Lanky low-poly machines, wobbly vertices, warped textures. Vibes only: no names, designs or signature parts from real franchises |

## Locked decisions

- **Name:** Mech Mania (renamed from Caveman Catchers, Nov 9 2026)
- **Look:** heavy, over-emphasized PSX. Vertex snapping and affine texture warping on every surface, 200-line screen with dithering and color banding, pixel textures, faceted low-poly. Lanky proportions everywhere
- **Scale:** mechs are about 10 m. Shops and houses come up to the chest, offices are head height, and a few apartment towers loom over you
- **Hero mech:** khaki-grey scout with reverse-jointed legs, a wasp waist, long arms, a small head with a red sensor slit, and a long straight sword held in both hands
- **Enemy mechs:** crimson lacquer with gold trim, big layered shoulder plates, a swept-back crest and a visor bar. The visor shows mood (cyan calm, amber suspicious, red dueling) and flashes the stance of each windup
- **Map:** a small night-time Tokyo neighborhood, 3×3 blocks around a central plaza. Neon signs, lit windows, vending machines, power poles, street lamps and parked cars. Tall indestructible towers ring the edge
- **Destruction:** walking into props knocks them flying. A sword strike cuts down any building it passes through. Running or dashing into a building up to 13 m tall smashes through it. Buildings collapse into tumbling chunks and leave rubble. Destruction is loud (80 m), so it pulls enemies in, and it removes cover
- **Sword combat:**
  - Stances: HIGH (0.7 s windup, 3 damage, breaks guard), MID (0.42 s, 2 damage), LOW (0.28 s, 1 damage, cripples a leg)
  - Getting hit interrupts your swing. Guard blocks MID and LOW, and the attacker recoils. Strikes landing at the same moment clash
  - Dash cancels a windup (feint) and also works as a back-step
  - Hit-stop and camera shake on impact so hits feel heavy
  - Player has 5 armor and enemies have 3. A crippled mech moves at half speed
- **Stealth (light):** enemies patrol the streets and see about 55 m in a 110° cone; buildings block sight. Walking footsteps carry 22 m, running 60 m, a dash 45 m, a swing 30 m. A hit from behind on an enemy who isn't dueling you kills in one cut
- **Duel AI:** squares up at sword range, circles, picks a stance (HIGH when you're guarding), guards against your MID/LOW about half the time, and back-steps from your HIGH. A shout when he spots you alerts others within 80 m. Lose him for 6 seconds and he goes back to searching
- **Camera:** free third person. It locks on automatically when an enemy duels you, framed over your shoulder so both mechs are visible. R1 toggles lock-on
- **Platforms:** AYN Thor (APK) and iPhone (web). Engine: Godot 4.7

## Previous directions (dropped)

Caveman catching, space chimp vs robot monkeys, PS1 horror watchman vs cymbal monkeys, then a human-sized scout mech punching soldiers. The punching felt mushy, stealth was slow, soldiers were no match for a mech and movement felt bad, so it pivoted to giant-mech sword duels.

## Ideas parked for later

- Cutting limbs off (sword arm gone = one-handed, slower)
- Sound pass: heavy stomps, servo whine, blade ring on clash, crumbling concrete
- Different enemy types: a fast twin-blade mech, a heavy with a long spear
- Rain on the streets, neon reflections
- Civilians fleeing (cars driving off), or just keeping it empty

## Open questions

1. What's the story: who are you, and why is this neighborhood a battlefield?
2. One-hit backstab: too strong, or just right?
3. Is 5 armor the right amount, or should you die as fast as enemies do, true Bushido Blade style?
4. A full level goal beyond "beat 3 mechs"?
