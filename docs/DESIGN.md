# Mech Mania: Design Doc

> Living document. **Locked** = decided, **Open** = still being discussed.
> The user designs and makes the calls. Claude builds, and either of us can challenge or pitch ideas.

## The pitch

Giant cyborg sword fights in a destructible PSX Tokyo. Move like Phantom Pain, fight like Metal Gear Rising, and everything is exaggerated like a Tarantino movie: oil gushes, sparks, slow motion, limbs flying, buildings coming down.

## Inspirations

| Source | What we take from it |
|---|---|
| Metal Gear Rising | Blade Mode (time slows, cut along a line you choose), parry, cutting enemies apart, repairing on a finishing cut |
| MGSV: The Phantom Pain | Movement: walk / jog / sprint, dive out of a sprint, crouch, close over-the-shoulder camera |
| Tarantino films | Exaggeration: oil gushing in arcs, puddles, slow-motion kills |
| PS1-era mech games | Lanky low-poly machines, wobbly vertices, warped textures. Vibes only: no names, designs or signature parts from real franchises |

## Locked decisions

- **Name:** Mech Mania
- **Look:** heavy PSX on the world (vertex snapping, affine textures, 200-line dithered screen). The mechs get less jitter so moving bodies stay smooth. Night Tokyo, 3x3 blocks, neon, lit windows, hazy skyline
- **Scale:** mechs about 10 m; shops reach the chest, towers loom over you
- **Hero:** khaki-grey humanoid mech with rusty orange trim, red visor slit, antenna and a trailing head cable, katana
- **Enemies:**
  - Gunners: crimson with gold trim, horned shoulders, rifle
  - Swordsmen: gunmetal with red trim, katana
  - Visors: cyan calm, amber suspicious, red fighting, blue flashing weakened, white flash about to strike
- **Movement (Phantom Pain):** a light push walks (2.5 to 4 m/s), a full push jogs (9), holding SPRINT runs at 16 with a heavy lean, wider FOV and momentum. B: crouch when standing, roll when moving, dive when sprinting (launch at 24 m/s, slide to a stop, untouchable). The camera sits close over the right shoulder
- **Sword:**
  - Quick slash: 2 damage, a 3-hit combo along different lines
  - Heavy: 4 damage, breaks guard, longer windup
  - Guard: blocks slashes from the front and deflects bullets
  - Parry: guard within 0.25 s of a slash landing; the attacker staggers 1.2 s and is exposed for 2.5 s
  - Hits stagger and knock back, with hit-stop, sparks and oil
  - A normal-slash kill takes off the upper body or the head
- **Blade Mode (hold L2):** time scale 0.12 (you move at real speed). The cut line sits on the nearest enemy within 18 m. The right stick sets its angle and the left stick slides it (up to 4.5 m). Flick the stick or press X to cut.
  - The line severs every part it passes within reach of: head, either arm, either leg. A roughly horizontal line through the waist, or a vertical line down the chest, cuts the mech in half
  - Head and torso cuts only work when the enemy is weakened (half armor or less) or exposed. Otherwise the armor holds (3 damage, sparks) and only limbs come off
  - Each cut costs 12 energy, and Blade Mode drains 18 per second. Hits give 8 (12 for a heavy), parries 25, and energy regenerates slowly
  - A finishing cut through the head or torso repairs 8 armor and refills energy
  - The line also cuts buildings and props along it
- **Dismemberment:** the real pieces break off as physics debris; stumps gush oil in pulses. An arm off means the weapon is gone and the mech brawls (a telegraphed slam). One leg off means a limp; two means stuck. The head or upper body off means dead
- **Oil:** black and dirty amber gouts arcing out of every wound, landing as puddles that stay on the street (up to 70)
- **Enemy AI:**
  - Gunners hold 20 to 48 m, back off if you close in, and laser-sight you for 0.75 s before each 3-round burst
  - Swordsmen hold about 8 m and circle. Their windups are 3.6x yours (about 0.36 s light, 1.2 s heavy) with a white visor flash. They guard about 45% of your swings, and a heavy breaks it. They counter quickly after blocking
- **Stealth:** a slash from behind on an unaware enemy exposes him (he's wide open to a Blade Mode finisher)
- **Armor:** you 30, enemies 16
- **Destruction:** slashes and Blade Mode lines cut buildings down; sprinting, rolling or diving into low buildings smashes through them; props fly
- **Platforms:** AYN Thor (APK) and iPhone (web). On touch, Blade Mode is a toggle and you swipe to cut

## Previous directions (dropped)

Caveman catching, space chimp vs robot monkeys, PS1 horror watchman vs cymbal monkeys, a human-size mech punching soldiers, bird-legged mechs with Bushido Blade stance swords (too slow, confusing stances, unclear hits, the camera fought you), and Syphon Filter-style humanoid gunplay with lock-on part targeting (the user wanted more exaggeration, swords on the right stick, and a closer camera).

## Ideas parked for later

- Sound pass: blade ring, clangs, servo whine, oil splatter, heavy stomps
- Ninja-run style parkour over cars and low roofs while sprinting
- Throwing a cut-off arm or weapon
- Boss mech
- Rain on the streets, neon reflections in the oil

## Open questions

1. Story: who are you, and why is this neighborhood a battlefield?
2. Is Blade Mode too strong or too stingy on energy?
3. Should the camera lock onto a duel target, or stay free?
4. A level goal beyond "beat 4 mechs"?
