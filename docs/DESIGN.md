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
- **Perspective:** 3D, PS1-style low-poly with crunchy, low-res textures
- **Hero:** a lanky old space chimp, from the user's sketch ([sketch](concept/hero-sketch.png), [in game](concept/hero-ingame.png)). No helmet. Hair tuft, brow ridge, muzzle, droopy half-lidded eye and an X eye, a chewed left ear, a cigarette floating at his mouth (cartoon style, doesn't bob with his head) with thick smoke that trails behind him, V harness, belt with three pouches, satchel on his back, wristbands, knee pads, banded boots with soles, chest and shoulder pads, robot arm on his left, net in his right hand. Long noodle limbs (rubber hose). Worn grey suit with olive gear. Gruff vet who hates the robots that replaced him
- **Targets:** escaped cavemen and cavewomen
- **Setting for first area:** jungle planet
- **Catch flow:** spot target, sneak up, net them, beam them away
- **Tools:**
  - **Net:** silent, but you have to sneak in close
- **Detection:** sight (vision cones) and sound (footsteps, landings, yells). Sounds make cavemen investigate; only sight can fully spot you
- **Movement:** MGS-style. Light stick tilt sneaks quietly, full tilt runs loudly, crouch creeps silently. Jump, but landings are loud
- **When spotted:** cavemen flee, fight back, or raise an alarm
- **Getting spotted (Ape Escape style):** the robot leaps, yells (nearby robots hear it) and runs. Chase him down and net him. Lose him and he calms down. No countdowns, no game over for being seen. Tried burrows, instant game over and an area alert; the user disliked all three
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
5. Gadget list beyond the net
6. Level structure: hub world with missions, or linear levels?
7. Is the Thor the only target, or also PC/Mac later?
