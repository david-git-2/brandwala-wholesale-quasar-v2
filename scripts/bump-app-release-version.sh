#!/usr/bin/env bash
set -euo pipefail

# Bump patch in root + web package.json; print new semver on stdout.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

node - "${ROOT_DIR}" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

const rootDir = process.argv[2];
const rootPkgPath = path.join(rootDir, 'package.json');
const webPkgPath = path.join(rootDir, 'web', 'package.json');

const rootPkg = JSON.parse(fs.readFileSync(rootPkgPath, 'utf8'));
const parts = String(rootPkg.version || '0.0.0').trim().split('.').map((n) => Number.parseInt(n, 10) || 0);
while (parts.length < 3) parts.push(0);
parts[2] += 1;
const next = parts.join('.');
rootPkg.version = next;
fs.writeFileSync(rootPkgPath, `${JSON.stringify(rootPkg, null, 2)}\n`);

const webPkg = JSON.parse(fs.readFileSync(webPkgPath, 'utf8'));
webPkg.version = next;
fs.writeFileSync(webPkgPath, `${JSON.stringify(webPkg, null, 2)}\n`);

process.stdout.write(next);
NODE
