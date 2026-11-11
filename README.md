# Shining Slots

A 5x3 slot machine game in x86-64 assembly (GAS, AT&T syntax) rendered with SDL2, inspired by
"Shining Crown"-style machines. It uses original procedurally generated artwork, so no copyrighted
assets are included.

## Features

- 5 reels x 3 rows with sequential reel stopping (left to right).
- 10 fixed paylines, a paytable for 7 fruit symbols, and a live win evaluation.
- 7 bet levels with different win rates (higher bet = more frequent, larger wins).
- A gamble feature: after a win you can double or lose it all on a red/black card guess.
- Confetti animation on wins, a win-rate statistic, and a live CREDITS/BET/WIN panel.
- A "NOT ENOUGH CREDITS" warning when the balance cannot cover the current bet.
- All textures are generated locally from code (33 original BMPs).

## Requirements

- Linux (developed under WSL Ubuntu) with SDL2 and a working display (WSLg on Windows).
- `gcc`, `make`-free build (a simple `gcc` command is enough).
- Python 3 with Pillow only if you want to regenerate the assets.

```bash
sudo apt install libsdl2-dev
pip install pillow
```

`libsdl2-image-dev` is not required: the code loads BMPs through SDL2 core (`SDL_RWFromFile` +
`SDL_LoadBMP_RW`).

## Build

From this directory:

```bash
gcc -no-pie -o slots main.s -lSDL2
```

Or use the helper script:

```bash
bash build.sh
```

Note: `build.sh` currently `cd`s to `~/assembly_project/Slots` before compiling, so either keep the
project at that path or edit the `cd` line.

## Run

```bash
./slots
```

A separate SDL2 window is opened. On Windows, run it from WSL with WSLg enabled.

## Controls

| Input | Action |
| --- | --- |
| `SPACE` / click `SPIN` | Spin the reels |
| `1`-`7` / click a bet button / `+` / `-` | Select bet level (10/20/40/80/100/150/250) |
| `Q` / `ESC` / window close button | Quit |
| `G` / `Enter` / click `DOUBLE` | Enter the gamble after a win |
| `SPACE` / `C` / `Enter` / click `TAKE WIN` | Collect the win and leave the gamble |
| Left arrow / `R` / click the red card | Gamble on red |
| Right arrow / `N` / click the black card | Gamble on black |

Clicks only register inside the defined button rectangles; clicking elsewhere does nothing. The bet
bar is visible while idle and during the win offer, and is hidden during the gamble. The bet can only
be changed while idle.

## Rules

- Initial balance: 1000 credits.
- Bet levels and win rates: `10 -> 30%`, `20 -> 35%`, `40 -> 40%`, `80 -> 45%`, `100 -> 50%`,
  `150 -> 55%`, `250 -> 60%`.
- The win rate is enforced in `resolve_spin`: a spin below the current rate is guaranteed a win, and
  a spin above it is reshuffled until it has no winning line.
- Payouts scale with the bet (`base * bet / 10`).
- A win starts the offer screen: `SPIN` stays, `DOUBLE` appears next to it. Choose `DOUBLE` to gamble
  the entire win or `SPIN`/`TAKE WIN` to keep it and continue.
- The gamble uses a random card (red or black). A correct guess doubles the amount, a wrong guess
  loses it and returns to the main screen. Confetti plays only on spins, not on gamble wins.
- The last win (WIN panel) persists across losing spins until updated.

## Symbols and texture IDs

| ID | Asset |
| --- | --- |
| 0 | Crown |
| 1 | Watermelon |
| 2 | Plum |
| 3 | Orange |
| 4 | Banana |
| 5 | Cherries |
| 6 | Star |
| 7 | Red heart (gamble) |
| 8 | Black heart (gamble) |
| 9 | `SPIN` button (200x60) |
| 10 | `DOUBLE` button (200x60) |
| 11 | `TAKE WIN` button (300x40) |
| 12-18 | Bet buttons (84x32): 10, 20, 40, 80, 100, 150, 250 |
| 19-20 | `CREDITS` / `BET` labels (90x20) |
| 21-30 | Digits 0-9 (16x22) |
| 31 | `WIN` label (90x20) |
| 32 | `NOT ENOUGH CREDITS` (460x36, red, top center) |

Regenerate all assets with:

```bash
python3 gen_simboluri.py
```

## Project structure

| File | Role |
| --- | --- |
| `main.s` | Entry point: `srand`, 60 fps loop (`poll -> update -> draw -> 16 ms delay`) |
| `video.s` | SDL2 window, renderer, textures; `draw_tex` (128x128) and `draw_btn` (variable size) |
| `symbols.s` | BMP paths and symbol names |
| `reels.s` | Reel grid and game state, bet levels/rates, random helpers, `start_spin` |
| `paylines.s` | 10 fixed paylines, paytable, `has_win`, `eval_win` |
| `gamble.s` | Win-rate enforcement, DOUBLE offer, red/black gamble, confetti, statistics, number drawing, bet bar and credit panel |
| `anim.s` | Reel scrolling and sequential stopping, golden borders, main screen layout |
| `input.s` | SDL event polling; routes keys and clicks to the actions above |
| `gen_simboluri.py` | Generates the original BMP assets into `assets/` |
| `assets/` | Generated BMP textures |
