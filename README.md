# HVH 2018

CS:GO **2018 matchmaking HvH** on official **de_mirage**. Cheats are the game, not a overlay on someone else's client: ragebot, Auto-Revolver, LBY breaker, resolver, chams, ESP, thirdperson Real/Fake/LBY.

This is a Godot 4.7 project (GL Compatibility, 64-tick physics). The Web export in `export/web` is a static site: publish it to Vercel (or any static host) for a public URL anyone can open in a browser.

## Play online

The game is already exported. In this Cursor chat, click **Publish** to put `export/web` on Vercel. That URL is public — share it and anyone can play without installing Godot.

Local preview (same files):

```bash
python3 tools/serve.py --port 43187 --dir export/web
```

## Rules (MM competitive, not a $16k HvH server)

- Start money **$800**, cap $16000
- Freeze **15s**, buy **20s**, round **1:55**, bomb **40s**
- MR15, first to 16, halftime swap, overtime
- Loss bonus $1400–$3400; win $3250 / bomb or defuse $3500; plant $300 + $800 team if T plant and lose
- **Pistol rounds** (1 and 16): Dual Berettas, Desert Eagle, or R8 Revolver
- **Gun rounds:** SSG 08, AWP, or Auto (G3SG1 T / SCAR-20 CT)

## Cheats (2018 skeet / gamesense flavour)

- **Ragebot** — hitchance, mindmg, autowall, autoscope, autostop, silent, hitboxes, multipoint
- **Auto-Revolver** — cocks the R8 (`postpone` ~0.207s), holds attack, fires when ready and hitchance lands
- **Anti-aim** — pitch, yaw, fake, jitter, freestanding, manual Z/X/C, fake lag, fake duck, slowwalk
- **LBY breaker** — moving LBY = real; stop 0.22s then 1.1s; flick real onto LBY, hold real away between flicks
- **Resolver** — moving LBY, breaker inverse delta, brute on misses. **Resolved yaw is the visual yaw**: enemy chams and skeleton follow it. Misses rotate brute/delta.
- **Thirdperson** — local Real (red), Fake (blue), LBY (yellow) layers
- Insert opens the menu. Config saves to `user://mm_hvh.json`

## Controls

| Key | Action |
| --- | --- |
| WASD / mouse | Move / look |
| LMB / RMB | Fire / scope (R8 RMB = fan fire) |
| E | Plant / defuse (hold) |
| B | Buy menu |
| Insert | Cheat menu |
| Tab | Scoreboard |
| F | Thirdperson |
| Z / X / C | Manual AA left / back / right |
| 1–2 | Rifle / pistol |

## Run locally (Godot)

Godot **4.7** with GL Compatibility.

```bash
godot --path . --display-driver x11
```

Or open the project in the editor and press Play. Main scene is `scenes/main_menu.tscn`.

## Web export (rebuild)

```bash
mkdir -p export/web
godot --headless --path . --export-release Web export/web/index.html
```

Threads are **off**, so the build runs on ordinary HTTPS (Vercel, nginx, GitHub Pages) without SharedArrayBuffer / COOP-COEP. After a fresh Godot export, set `ensureCrossOriginIsolationHeaders` to `false` in `export/web/index.html` if Godot turned it back on.

## Docker

```bash
docker build -t hvh2018 .
docker run --rm -p 8080:80 hvh2018
```

Serves the contents of `export/web` through nginx.

## Map

`assets/maps/de_mirage/` is converted from CS:GO `de_mirage.bsp` (VBSP v21) via `tools/convert_bsp.py` (Source inches → meters, Godot `x, z, -y`). Radar uses playable spawn/site bounds, not the skybox AABB.

## Credits

Weapon sounds and map geometry come from CS:GO. This project is a standalone HvH game, not a cheat for the live game.
