// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

// Empaqueta la extensión en dist/: bundle de src/popup.ts + archivos
// estáticos de public/. Cargar dist/ como extensión descomprimida.
//
// Con --store (`npm run package`) arma además el .zip para Chrome Web Store
// y Edge Add-ons, con el manifest de storeManifest().
import { build } from 'esbuild';
import { execFileSync } from 'node:child_process';
import {
  cpSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';

import { storeManifest } from './store_manifest.mjs';

rmSync('dist', { recursive: true, force: true });
cpSync('public', 'dist', { recursive: true });

// Popup, service worker y content script (ADR 0034), cada uno en un solo
// archivo: el content script no puede cargar módulos.
for (const name of ['popup', 'background', 'capture']) {
  await build({
    entryPoints: [`src/${name}.ts`],
    bundle: true,
    format: 'iife',
    target: 'chrome120',
    outfile: `dist/${name}.js`,
    // Sin sourcemaps en el paquete: no hacen falta y engordan la revisión.
    sourcemap: false,
    legalComments: 'none',
  });
}

console.log('extension/dist listo');

if (process.argv.includes('--store')) {
  const manifest = JSON.parse(readFileSync('dist/manifest.json', 'utf8'));
  writeFileSync(
    'dist/manifest.json',
    `${JSON.stringify(storeManifest(manifest), null, 2)}
`,
  );
  const zip = `lockspire-extension-${manifest.version}.zip`;
  rmSync(zip, { force: true });
  // tar de Windows (bsdtar) arma .zip con -a; en Linux y macOS, zip.
  if (process.platform === 'win32') {
    const files = readdirSync('dist');
    execFileSync('tar', ['-a', '-c', '-f', `../${zip}`, ...files], {
      cwd: 'dist',
    });
  } else {
    execFileSync('zip', ['-r', '-q', `../${zip}`, '.'], { cwd: 'dist' });
  }
  console.log(`${zip} listo para las tiendas (dist/ queda sin key)`);
}
