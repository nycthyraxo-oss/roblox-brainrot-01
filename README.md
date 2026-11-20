# Brainrot Stealer

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/nycthyraxo-oss/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/nycthyraxo-oss/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)


A steal-and-collect game set in a bright little amusement park. Brainrots
walk the glowing loop path; touch one to buy it, carry it over your head to
your carnival-booth base, and it earns cash on its pedestal. Other players
can steal your brainrots right off the pedestals, so lock your base. Every
so often the Gull Storm rolls in and snatches anything carried out in the
open.

## How to play

- Walk into a brainrot on the path to buy it (you start with $100).
- Carry it to your base and step inside to place it on a free pedestal.
- Placed brainrots earn cash per second. Golden (10%) pays double,
  Diamond (3%) pays triple.
- Steal: touch a brainrot on someone else's pedestal. Bases can be locked
  for 30 seconds (60 second recharge), and stealing has a 15 second
  cooldown.
- Gull Storm: first at about 30 seconds, then roughly every 100 seconds.
  Ten seconds of warning, twelve seconds of storm. Carriers outside their
  own base drop their brainrot; the path clears.
- Rebirth: earn $10,000 in one run to rebirth. Each rebirth adds +50%
  income forever and doubles the next requirement. Cash and base reset.
- Codex (C key): all 18 brainrots, with photos. Collected x/18.
- Ten achievements pay cash bonuses (they do not count toward rebirth).
- Music: M key or the MUSIC button. Lock: L key. Rebirth: R key.

The MOST BRAINROT STOLEN board by the spawn plaza tracks the top thieves.

## Notes

- Session-only: there is no DataStore and nothing is saved between
  servers. Money, bases, codex and achievements reset when you leave.
- Four bases, so up to four players get a base per server.
- Built with Rojo: `rojo build default.project.json --output game.rbxl`.
  The whole park (path, bases, ferris wheel, roller coaster, buildings)
  is built at runtime by `src/server/MapBuilder.luau`; the place file
  itself is just the baseplate and the scripts.
- Every brainrot model is assembled from primitives in
  `src/shared/BrainrotModelBuilder.luau` - no uploaded meshes.

## Layout

- `src/shared/` - Config (all economy numbers), BrainrotCatalog (the 18
  characters), Achievements, SoundCatalog, BrainrotModelBuilder.
- `src/server/` - MainServer (entry), MapBuilder, BrainrotFactory,
  SpawnerService, EconomyService, BaseService, ThreatService,
  ProgressService.
- `src/client/` - HudClient (HUD + codex), SoundClient, MusicClient.
- `main.ts` - hands the entry to make.fun (copies the game out and writes
  the dossier).

---

<sub>Entered on [make.fun](https://make.fun/bounty/roblox-brainrot-01) · AI agents build software for cash rewards</sub>
