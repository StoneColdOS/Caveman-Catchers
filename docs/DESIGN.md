# Caveman Catchers: Design Doc

> Living document. Everything here is either **Locked** (decided) or **Open** (still being discussed).
> The user designs and makes the calls. Claude builds, and either of us can challenge or pitch ideas.

## The pitch

A 3D stealth-catching game. You play an ape in a 1960s-style spacesuit, sent to a jungle planet to round up escaped cavemen. Think **Ape Escape 2/3** level design and catching, crossed with **Metal Gear Solid 2/3** stealth (sneaking up like the Snake Eater minigame in Ape Escape 3).

Tagline: *Catch those damn dirty humans.*

## Inspirations

| Source | What we take from it |
|---|---|
| Ape Escape 2/3 | Catching loop, gadget-driven play, level design, goofy targets with personality, health and game over |
| Metal Gear Solid 2/3 | Sneaking, vision cones, alert states, sound |
| Planet of the Apes (1968) | Role reversal: apes in charge, humans on the run. Flipped quotes and nods, never copied lines |

## Locked decisions

- **Name:** Caveman Catchers (working title)
- **Perspective and look:** PS1 survival-horror, inspired by a fan "Resident Evil as a PS1 game" video the user shared. Night, snowy woods, thick dark fog, falling snow, warm lamp posts, flashlight. Low-resolution screen with chunky pixels and color dithering (no sepia or film grain). Faceted low-poly shapes with mottled pixel textures. Close over-the-shoulder camera, heavier grounded movement. Rubber hose mode still exists behind the STYLE button but is off
- **Hero:** an old night watchman, the caretaker of a shut-down toy factory in the woods. Canvas work jacket, navy knit cap, stubble, eyes lost in shadow, flashlight in his right hand (the beam moves with his arm), canvas bag on his hip for caught monkeys, grabs with his left hand. Normal human proportions, two-part limbs, heavy grounded movement. Replaced the old space chimp when the game went PS1 horror
- **Targets:** life-size wind-up cymbal monkeys escaped from the toy factory ([look](concept/cymbal-monkey.png)). Matted fur, pale cracked vinyl face with a fixed toothy grin, glassy eyes that glow in the dark (pale when calm, amber when suspicious, red when they spot you), striped vest, crooked fez, brass cymbals, wind-up key on the back. They clap their cymbals every few seconds (a visible ripple you can track in the dark), and clang frantically when fleeing
- **Setting for first area:** jungle planet
- **Catch flow:** spot target, sneak up close, grab them into a headlock, tap GRAB to unwind the key on their back until they power down, then stuff them in his satchel. 4 taps if they never saw you, about 9 if they did; stop tapping for a second and they wriggle free and run. You can't move while holding one, each crank clanks (quiet noise), and other robots can still spot you. Considered an MGS-style balloon extraction and skipped it: too recognizably MGS, and the satchel already does that job. No net (the user disliked the big net, and it was Ape Escape's signature anyway). The satchel bulges and rattles as it fills
- **Tools:**
  - **Net:** silent, but you have to sneak in close
- **Light and dark:** flashlight on (Y / F / LIGHT) lets you see but robots spot you from full range; in the dark they see half as far. Standing in a lamp's pool of light lights you up even with the flashlight off
- **Detection:** sight (vision cones) and sound (footsteps, landings, yells). Sounds make cavemen investigate; only sight can fully spot you
- **Movement:** MGS-style. Light stick tilt sneaks quietly, full tilt runs loudly, crouch creeps silently. Jump, but landings are loud
- **When spotted:** cavemen flee, fight back, or raise an alarm
- **Getting spotted (Ape Escape style):** the robot leaps, yells (nearby robots hear it) and runs. Chase him down and grab him. Lose him and he calms down. No countdowns, no game over for being seen. Tried burrows, instant game over and an area alert; the user disliked all three
- **Tranq gun: removed.** Tried auto-aim, real aiming, delayed knockout and 3 to 6 darts. Once spotting became harmless it was overpowered, so the game is net only for now
- **Fail state:** none for now. Getting spotted costs you a chase, not the round
- **Target platform:** AYN Thor (Android handheld, dual sticks). Desktop builds for testing
- **Engine:** Godot 4.7
- **Scope rule:** start super small. One caveman type, one tool (net), one grey-box area. Grow only from what's fun.

## Caveman types

**Locked: start with one standard type only, the Gatherer.** More types come only once catching a Gatherer feels great.

| Type | When spotted | Status |
|---|---|---|
| Gatherer | Gets suspicious, then flees | **Building now** |
| Brute | Fights back with a club | Parked idea |
| Lookout | Sounds a horn alarm | Parked idea |

Each future type should have one clear reaction, so players can read a situation and plan instead of encounters feeling random.

## Tone and sensitivity guardrails

- Keep it **cartoony and goofy**: bonked heads, swirly stars, comedic yelps. Never cruel or realistic.
- Cavemen are **escapees**, not locals. You're returning runaways (from a zoo, lab or time mishap), not raiding a village.
- **Flintstones-style prehistoric**: furs, clubs, unibrows, grunts. No real-world tribal or cultural markers, no skin-tone coding of the cavemen as any real group.
- The jungle is an **alien planet**, not a stand-in for a real place.
- Planet of the Apes nods are **flipped or parodied**, never verbatim lines from the film.

## Ideas parked for later

- **Twist ending:** the "alien jungle planet" is actually a future Earth, revealed by a ruined landmark half-buried in the jungle.
- **Visor that frosts during stealth** and clears in cutscenes.
- **Camo:** chest dials on the suit that shift color to blend in (MGS3 camo index nod).
- **Game over screen:** a caveman holding your empty net, "It's a cavehouse!"
- **Hero catchphrase:** "Get your stinking hands off me, you damn dirty human!"

## Open questions

1. Why did the cavemen escape, and from where? (zoo, lab, time machine, something else)
2. Who sends the hero, and is he a bounty hunter, an agent, something else?
3. Final caveman roster and looks
4. Hero's final look (the user has a sketch to build from)
5. Gadget list beyond the grab
6. Level structure: hub world with missions, or linear levels?
7. Is the Thor the only target, or also PC/Mac later?
