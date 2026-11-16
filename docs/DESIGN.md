# Design spec: "Bazaar Board" (v1.1)

## Audit of v1.0 (why it read as generic AI output)

| Problem | Where | Fix |
|---|---|---|
| Dark navy page with violet and mint radial glows | every screen | Warm paper ground, flat colour, no glows |
| Translucent gradient cards with tinted hairline borders | Panel, mode cards | Solid cards, thick ink outline, hard offset shadow |
| Violet as the lead accent | XP, profile, Learn | Violet removed from the palette |
| Emoji used as the icon system | badges, stats, nav | Emoji stay only inside content. Chrome uses solid icons on colour blocks |
| Everything the same visual weight | home | One hero per screen, clear size steps |
| Motion is fades only | all | Spring press, tilt, flip, pop, roll-up numbers |
| No depth | all | Extruded blocks, 3D coin, tilt cards, flip cards, isometric town |
| Quiz interrupts the arcade | game host | Non-blocking quiz chip, optional second chance |

## References (what we take from each)

- **Duolingo**: flat saturated colour, thick bottom edges on buttons, one action per screen, celebration after every unit.
- **Supercell (Brawl Stars, Clash Royale)**: chunky outlined display type, beveled panels, loud reward moments.
- **Monopoly Go / board games**: the app as a physical board. Tokens, cards and tiles with thickness.
- **Balatro**: cards that tilt and wobble under the finger, numbers that punch.
- **Apple fluid interfaces**: feedback on touch-down, springs not fixed curves, interruptible motion, sound and haptic on the same frame.

## Theme

A board game laid on warm paper. Every surface is a physical piece: it has an outline, a thickness and a hard shadow. Nothing glows, nothing is translucent, nothing has a gradient.

### Colour tokens (`AppColors`)

| Token | Hex | Use |
|---|---|---|
| `paper` | `#FFF3DC` | page ground |
| `paperDeep` | `#F7E2B8` | bands, pressed or inactive fills |
| `card` | `#FFFFFF` | cards, sheets |
| `ink` | `#1D1B2E` | text, outlines, hard shadows |
| `inkDim` | `#6B6780` | secondary text |
| `track` | `#E9D6AC` | progress tracks, dividers |
| `green` | `#1FB86B` | primary action, correct, growth |
| `yellow` | `#FFC530` | coins, arcade, rewards |
| `red` | `#FF5348` | wrong, lives, danger |
| `blue` | `#2F8CFF` | XP, knowledge |
| `teal` | `#12B5A6` | story |
| `orange` | `#FF8A2B` | streak, energy |

Rules: colour is always a solid fill. Text on a colour block is `ink` (or white on blue, red, teal). No opacity tints for surfaces. No `LinearGradient`, `RadialGradient` or blurred `BoxShadow` in app screens. (Games paint their own worlds and may use gradients inside the canvas.)

### Shape

- Outline: 2.5px `ink` on every card, button, pill, badge and bar.
- Radius: 18 cards, 14 buttons, 999 pills.
- Depth: hard shadow, `ink`, offset (0, 5) on cards and (0, 4) on buttons, blur 0. Pressing moves the piece down by its depth and removes the shadow.

### Type

- Display: **Baloo 2** ExtraBold (headlines, numbers, button labels). Tight leading (1.05).
- Body: **Nunito** 600 to 800.
- Big numbers and titles over busy art use `OutlinedText` (ink stroke, colour fill).

### Motion

- Touch-down responds in the same frame (press depth, sound, haptic together).
- Springs for anything the finger moved. Default: no overshoot. Overshoot only for rewards and for things the player flicked.
- Entrances: `PopIn` (scale 0.9 to 1 with a spring, staggered 40ms). Once per screen visit, never on scroll.
- 3D: `Tilt3D` (card leans toward the finger, up to 8 degrees), `Coin3D` (spinning coin with thickness), flip cards in lessons, isometric town on Home.
- Numbers roll (`CountUp`) when XP or coins change.
- `MediaQuery.disableAnimations`: tilt, pop, spin and roll are replaced by an instant state change.

### Sound (`Sound.play(Sfx.x)`)

`tap, correct, wrong, coin, powerup, levelUp, crash, jump, drop, perfect, merge, swipe, win, lose, tick`. Only on meaningful events. Muted by a toggle in Profile.

## Arcade rules

1. The run never pauses for a question. A boost shows a **quiz chip** at the bottom: one true/false or myth/fact statement, two buttons, 10 second timer. Correct gives the power-up. Wrong or ignored costs nothing.
2. Death goes straight to results. A **second chance** card offers one question to continue the run. It is optional, once per run, next to Play again and Done.
3. Explanations are not shown mid-run. The results screen lists "What you learned this run" with each answered statement and its explanation.
