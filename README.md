# Mech Mania

A PSX-style giant-mech shooter that moves like Syphon Filter. Pilot a lanky 10 m humanoid mech through a small Tokyo neighborhood at night: sneak up and drop enemy mechs with one locked-on shot, or get into running gunfights where you strafe, roll and lock on. The city breaks around you: stray bullets chew buildings until they collapse, props go flying, and rolling into a shop smashes right through it.

Built in Godot 4.7, for the AYN Thor handheld and phones.

- [Design doc](docs/DESIGN.md): what we've decided and what's still open
- [Roadmap](docs/ROADMAP.md): build order, one playable step at a time

![Two mechs in a Tokyo street](docs/concept/mech-mania-gunfight.png)

![Running, Syphon Filter style](docs/concept/mech-mania-run.png)

## How it plays

- **Syphon Filter movement:** push the stick and you run at full speed with long strides, heel kicks, arms pumping and the rifle swinging low. You run where you push, and the camera swings in behind you on its own. Hold WALK (L3) to sneak. L2/R2 sidestep without turning.
- **Lock on (R1):** grabs the enemy in front. You can keep running anywhere (run and gun) while your upper body stays on him. The brackets close in white, then yellow, then red. A full red lock hits for double.
- **Pick a part while locked** (D-pad up/down or flick the right stick):
  - **HEAD:** triple damage. A full-lock headshot takes the head off.
  - **ARM:** shoot the gun arm off and he's disarmed. He charges and tries to slam you; his visor flashes white before he swings.
  - **LEG:** take a leg off at the knee and he crawls.
  - **BODY:** normal damage.
- **Manual aim (L1):** a tight over-the-shoulder crosshair that hits exactly where you point.
- **Silent kill:** a full-lock shot on an enemy who hasn't noticed you.
- **Enemies telegraph:** a red laser lands on you before every burst. Roll (B while moving) and bullets pass through you. B standing still crouches. A jumps.
- **Destruction:** missed shots chew up buildings until they collapse. Rolling into a shop smashes through it.

| | Thor / gamepad | Keyboard |
|---|---|---|
| Run | Left stick | WASD |
| Walk (quiet) | Hold L3 | Hold Ctrl |
| Camera | Right stick | Arrow keys |
| Lock on (hold) | R1 | K |
| Pick part while locked | D-pad up/down or flick right stick | Tab |
| Manual aim (hold) | L1 | L |
| Fire | X | J |
| Sidestep | L2 / R2 | Q / E |
| Roll / crouch | B | C |
| Jump | A | Space |
| Reload | Y | R |
| Restart | Start | Enter |

## Running it

**On your iPhone (or any phone):** open [stonecoldos.github.io/Mech-Mania](https://stonecoldos.github.io/Mech-Mania/) in Safari and turn the phone sideways. Touch controls appear automatically. Every push rebuilds it.

**On the Thor:** every push to `main` builds an APK. Open the [latest build](https://github.com/StoneColdOS/Mech-Mania/releases/tag/latest-build), download `mech-mania.apk` and install it. It installs right over the old Caveman Catchers app.

**On your Mac:** install [Godot 4.7](https://godotengine.org/download), import `project.godot`, press **F5**.

## Tests

`godot --headless --path . -s res://tests/test_catch.gd` plays through running, camera follow, sidestep, walk, lock-on, part targeting (headshot, disarm, leg off), disarmed slams, jump, silent kills, damage, reload, enemy lasers and bursts, rolling through fire, cover, destruction, hearing, crouch, defeat and touch controls.
