# Caveman Catchers: Roadmap

The rule for this project: **prove it's fun before making it big.** Each phase ends with something playable and a gut check: "Do I actually want to keep playing this?" If the answer is no, we fix the fun before moving on, not after.

Art comes late on purpose. Everything starts as grey boxes and capsules.

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

Tranq, health and other caveman types wait until this feels good.

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
