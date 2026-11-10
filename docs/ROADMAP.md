# Mech Mania: Roadmap

The rule for this project: **prove it's fun before making it big.** Each phase ends with something playable and a gut check: "Do I actually want to keep playing this?" If the answer is no, we fix the fun before moving on, not after.

Art comes late on purpose. Everything starts as grey boxes and capsules.


## Prototype 5: old space chimp vs janky robot monkeys (current)

- [x] New concept: a grumpy old space chimp (shadowed eyes, smokes inside his helmet, robot arm) catching janky, broken robot monkeys in the jungle. Moon later
- [x] Touch controls and a web version for iPhone, hosted on GitHub Pages
- [x] Tried: escaped robots gone for good plus a 30s area alert. **Verdict:** didn't like the alert system either
- [x] Back to Ape Escape style: spotted robots just run away and calm down if they lose you. The chase is the challenge
- [x] Kept: real aiming with a red-on-target crosshair, delayed darts, 5 darts
- [x] Rubber hose art style test (now **off by default**: the user prefers the calmer plain mode; STYLE button / Select / T flips it off to compare):
  - Ink outlines, toon shading, old-film filter (sepia, grain, flicker, scratches, vignette)
  - Noodle limbs, big shoes, white glove; bouncy idle and toe-tap on a shared beat; tiptoe sneak with hands up; windmill run; midair flail; springy head; big landing squash
  - Robots bob in sync to the beat, waddle, scissor-run with arms straight up, heads boing up on spring necks when startled
  - Trees swayed to the beat. **Removed:** too distracting, trees stay still
- [x] Playtest: removed the old-film filter and the hero's outline (robots and world keep theirs). Rubber hose animation stays
- [x] Headlock takedown: grab into a headlock, tap to unwind their key (4 taps unaware, ~9 alert), stop and they break free. Locked in place while holding; cranks clank
- [x] Plain style is now the default; trees no longer sway
- [x] Net replaced: grab robots and stuff them in the satchel (R1/R2). Short range with a forward lunge; the satchel bulges and rattles as it fills
- [x] Pixel low-poly look from the user's reference: faceted flat shading on every shape, mottled 16x16 pixel textures (nearest filtering, triplanar)
- [x] Playtest tweaks: no helmet, cigarette floats still at his mouth, thicker trailing smoke, more 3D shape on hero and robots (brow, muzzle, chest, pads, pouch flaps, soles; robot panels, rivets, bezel), no flat toon shading, cool back light for depth
- [x] New hero from the user's sketch: lanky chimp with helmet, droopy eye + X eye, chewed ear, cigarette through the helmet, harness, pouches, satchel, knee pads, robot arm
- [x] Tranq felt overpowered once spotting was harmless. **Removed the tranq gun**: net only, pure Ape Escape. Triggers now double up crouch (L2) and net (R2)


## Prototype 9: humanoid mechs, Syphon Filter gunplay (current)

- [x] Playtest of prototype 8. **Verdict:** swords too slow, stances confusing, hard to tell what hit, the camera fought you
- [x] Humanoid mech bodies (forward knees, broad chest, visor helmet), still lanky, rifle in both hands
- [x] Syphon Filter movement: camera behind, always facing forward, strafe and backpedal, jog vs quiet walk, crouch-walk, combat roll with dodge
- [x] Hold-to-lock aiming with brackets that close in and turn red; full lock does double damage; firing loosens it
- [x] Ammo and reload, tracers, muzzle flash, impact sparks, hit marker, enemy health bars, red damage flash
- [x] Silent kill: full-lock shot on an unaware enemy
- [x] Enemies hold range, strafe, laser-sight you before every burst, aim worse when you move
- [x] Bullets damage buildings until they collapse; stray shots knock props over; rolling smashes low buildings
- [ ] Play it on the Thor and phone: does it feel like Syphon Filter? Are the lasers enough warning?
- [ ] Sound pass
- [ ] Weapon pickups

## Prototype 8: giant sword mechs in Tokyo (dropped)

- [x] Renamed to Mech Mania
- [x] Playtest of prototype 7. **Verdict:** punching felt mushy, stealth was slow, soldiers weren't a match, mech moved badly
- [x] Mechs scaled to ~10 m; the same lanky rig is shared by the hero and the enemies
- [x] Small night Tokyo: 3×3 blocks of shops, houses, offices and towers, neon signs, lit windows, vending machines, poles, lamps, cars, plaza in the middle
- [x] Destruction: props fly when touched, sword cuts topple buildings, charging smashes low buildings, debris chunks and rubble, collapses alert enemies
- [x] Bushido Blade-style swords: HIGH / MID / LOW stances, guard, guard break, clash, crippled legs, interrupts, feint by dashing
- [x] Hit-stop, camera shake, blade trails, sparks
- [x] Crimson enemy mechs that patrol streets, see and hear you, duel with telegraphed stance flashes, guard and back-step
- [x] One-cut backstab on unaware enemies
- [x] Lock-on camera that frames both mechs
- [ ] Play it on the Thor and phone: do duels feel tense and fair? Is destruction fun or just noise?
- [ ] Sound pass
- [ ] Limb cutting

## Prototype 7: PSX mechs (human-size, dropped)

- [x] New direction: a lanky scout mech sneaking up on soldiers. Get caught and you have to fight
- [x] Heavy PSX rendering: custom surface shader with vertex snapping and affine texture warping on everything, ground cut into 2 m tiles, screen down to 200 lines with stronger dithering and color banding
- [x] Lanky reverse-jointed mech (~2.7 m) with long arms, big fists, red sensor slit and head lamp. Heavy stomping walk, camera pulled back
- [x] Lanky soldiers (~1.9 m): winter camo, gas mask, helmet lamp shows mood, shock baton
- [x] Stealth takedown: lift by the collar, tap GRAB to put him out. Downed soldiers stay down
- [x] Brawl: telegraphed baton swings, PUNCH staggers, GRAB a staggered soldier to throw him, 6 armor, MECH DOWN game over, COMBAT banner
- [x] Mech-sized cover: bigger rocks, rusted shipping containers, taller pines
- [x] Head lamp starts off; quieter vision cones; faint fill light so the mech reads in the dark
- [ ] Play it on the Thor and phone: is sneaking satisfying? Is the brawl fun or just a punishment? Are swings fair to dodge?
- [ ] Sound pass (biggest missing piece)
- [ ] Soldiers noticing knocked-out buddies
- [ ] Enemy mechs

## Prototype 6: PS1 horror direction

- [x] Night in snowy woods: dark fog, falling snow, snowy pines and rocks, warm lamp posts with pools of light, weak moonlight
- [x] Flashlight with real stealth tradeoff: on = you can see, robots spot you from full range; off = half range. Lamplight lights you up
- [x] PS1 screen: low resolution, chunky pixels, ordered color dithering
- [x] Heavier movement (slower acceleration, barely any bounce) and a close over-the-shoulder camera
- [x] Characters redesigned for horror: old night watchman (flashlight in hand, shadowed eyes, canvas bag) vs creepy wind-up cymbal monkeys from a shut-down toy factory that clap their cymbals in the dark
- [ ] Sound: wind, crunching snow footsteps, distant cymbal clacks (the biggest missing piece for scary)
- [ ] Maybe: fixed cinematic camera angles in places, like classic Resident Evil

---

## Prototype 1: one Gatherer (current)

The smallest playable thing. Grey shapes only.

- [x] Grey-box jungle clearing with rocks and trees to hide behind
- [x] Player capsule: move, crouch, third-person camera
- [x] One standard caveman type (Gatherer), three of them in the area
- [x] Vision cone you can see: green (calm), yellow (suspicious), red (spotted)
- [x] Crouching shrinks how far they can see you; rocks block their view
- [x] Spotted Gatherers run away, then calm down if they lose you
- [x] Net swing to catch, beam-away effect, catch counter
- [x] Play it on the Thor. Verdict: works, but too easy and the cavemen felt too simple

## Prototype 2: sound and smarter cavemen (current)

Still one caveman type, still grey boxes.

- [x] MGS-style movement: light stick tilt sneaks (quiet), full tilt runs (loud), crouch creeps (silent)
- [x] Sound detection with visible rings: footsteps, jump landings, caveman yells
- [x] Gatherers hear noises and walk over to investigate, then look around
- [x] Lose sight of you and they check where they last saw you
- [x] Foraging: head down and half blind, your window to sneak in
- [x] Jumping for the player; cavemen hop when startled, leap and yell when they spot you, panic-hop when fleeing
- [x] Spotted yells alert nearby cavemen
- [x] 5 cavemen
- [x] Play it on the Thor. Verdict: way more challenging, crouching is a great addition, feels like a real Ape Escape x MGS crossover. Jumping onto alerted cavemen to catch them works

## Prototype 3: stakes when spotted

- [x] Burrows: spotted cavemen hide in a burrow and pop out elsewhere. **Cut:** didn't like it
- [x] Tranq gun with auto-aim and 6 darts. **Verdict:** way too easy, could tranq everyone

## Prototype 4: the radio-in alert

- [x] Spotted = alert. The caveman yells and runs to warn the tribe with a 5 second countdown over his head and on screen. Net him or dart him in time, or it's game over
- [x] Real aiming: hold L2 for an over-the-shoulder view with a crosshair, R2 fires. No auto-aim. Crouch moved to L1 only
- [x] Delayed knockout: a dart takes 2 seconds to kick in. He staggers and yelps (nearby cavemen hear it), then sleeps 8 seconds
- [x] 3 darts per round
- [ ] Play it: is the alert scary but fair? Is aiming fun on the Thor's sticks? Are 3 darts the right number?

Health, other caveman types and art wait until this feels good.

---

## Phase 0: Setup

Get the project running on desktop and the Thor before writing real gameplay.

- [ ] Confirm engine (Godot 4)
- [ ] Create the Godot project in the repo, with a sensible folder layout
- [ ] Empty test scene with a floor and a capsule
- [ ] Export a build and install it on the Thor
- [ ] Controller input works on the Thor (both sticks, triggers, face buttons)

**Done when:** a capsule sits in an empty room on the Thor and responds to the sticks.

## Phase 1: Movement and camera

The feel of moving around is half the game. Get it right early.

- [ ] Third-person movement: walk, run, crouch, crawl
- [ ] Camera that follows smoothly, controllable with the right stick
- [ ] Simple grey-box jungle test area: grass patches, rocks, trees, a hill
- [ ] Tall grass that hides you when crouching or crawling

**Done when:** running around the grey-box jungle on the Thor just feels good.

## Phase 2: One caveman (the core loop)

The most important phase. If this isn't fun, nothing else matters.

- [ ] One Gatherer caveman that wanders an area
- [ ] Vision cone with a visible "noticed you" indicator
- [ ] Alert states: unaware, suspicious, spotted
- [ ] When spotted: flees
- [ ] Net: swing at close range to catch
- [ ] Tranq pistol: aim and shoot, knocks him out, but makes noise
- [ ] Beam-away effect after a catch
- [ ] Basic HUD: health, catches

**Done when:** sneaking up and catching one caveman is satisfying, and choosing tranq vs net feels like a real decision.

## Phase 3: Three caveman types

- [ ] Brute: fights back with a club, can hurt you
- [ ] Lookout: sounds a horn that alerts nearby cavemen
- [ ] Health, taking damage, and game over
- [ ] A small mixed encounter that makes you think about who to catch first

**Done when:** a group of mixed cavemen becomes a little puzzle you have to plan.

## Phase 4: One full level

- [ ] A real jungle level layout (still grey-boxed)
- [ ] Catch X cavemen to finish the level
- [ ] Health pickups
- [ ] Level start and end, retry on game over
- [ ] Simple title screen

**Done when:** you can play one complete level start to finish and want to replay it.

## Phase 5: Look and feel

Only now does art take center stage.

- [ ] Final hero design (user leads)
- [ ] Caveman designs
- [ ] PS1-style rendering: low-res textures, vertex wobble, limited color
- [ ] Jungle planet art pass
- [ ] Sound effects and music

## Phase 6 and beyond (not committed yet)

Pull from the "Ideas parked for later" list in the design doc once the core is proven. Likely candidates:

- Sound-based detection
- More gadgets
- More levels and a hub
- Story and the twist ending
