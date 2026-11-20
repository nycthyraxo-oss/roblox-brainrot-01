// Brainrot Stealer, entered for make.fun's roblox-brainrot-01.
//
// The game is a Rojo project: `rojo build default.project.json --output game.rbxl`
// turns src/ into the place file. This program (Node 22, standard library
// only) hands the entry in: it copies game.rbxl, PLAY.json, src/ and
// screenshots/ from beside this file into the output directory and writes
// dossier.json there with the vendored make.fun library, which is the
// summary the judge reads.
//
// Output names may only hold letters, digits, . _ and -, and may not start
// with a dot, so the copies skip any dotted name at any depth.
//
// Outside the grader's container, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

const notDotted = (path: string): boolean => !basename(path).startsWith('.');

copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: notDotted });
mkdirSync(join(out, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) {
  cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: notDotted });
}

// The scorer's caps: text_max_bytes shapes the dossier bytes; the rest make
// this program refuse exactly what the scorer would refuse (over 4
// screenshots or one over 256 KiB, a place over 500000 instances, script
// sources over 8 MiB in all, script paths over 1048576 characters in all).
writeFileSync(
  join(out, 'dossier.json'),
  buildDossier(out, {
    text_max_bytes: 65536,
    screenshots: { max: 4, max_bytes: 262144 },
    max_instances: 500000,
    scripts_max_source_bytes: 8388608,
    scripts_max_path_chars: 1048576,
  }),
);
