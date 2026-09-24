// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

// Empaqueta la extensión en dist/: bundle de src/popup.ts + archivos
// estáticos de public/. Cargar dist/ como extensión descomprimida.
import { build } from 'esbuild';
import { cpSync, rmSync } from 'node:fs';

rmSync('dist', { recursive: true, force: true });
cpSync('public', 'dist', { recursive: true });

await build({
  entryPoints: ['src/popup.ts'],
  bundle: true,
  format: 'iife',
  target: 'chrome120',
  outfile: 'dist/popup.js',
  // Sin sourcemaps en el paquete: no hacen falta y engordan la revisión.
  sourcemap: false,
  legalComments: 'none',
});

console.log('extension/dist listo');
