#!/usr/bin/env node
/**
 * Flags disallowed color patterns in Vue SFCs (see docs/guides/ui-standards.md).
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const srcDir = path.resolve(__dirname, '../web/src');

const HEX_RE = /#[0-9a-fA-F]{3,8}\b/g;
const RAW_PALETTE_RE = /color=["'](?:red|green|blue|orange|purple|pink|teal|cyan|indigo|amber|lime|deep-orange)(?:-\d+)?["']/g;
const PUSH_GLOSSY_RE = /<q-btn\b[^>]*\s(?:push|glossy)(?=[\s=>])/gi;
const BTN_NO_CAPS_RE = /<q-btn\b(?![^>]*\bno-caps\b)[^>]*>/gi;

const ALLOW_HEX_FILES = new Set([
  // none — hex belongs in app.scss only
]);

const violations = [];

function walk(dir, out = []) {
  for (const name of fs.readdirSync(dir)) {
    const p = path.join(dir, name);
    const st = fs.statSync(p);
    if (st.isDirectory()) {
      if (name === 'types') continue;
      walk(p, out);
    } else if (name.endsWith('.vue')) {
      out.push(p);
    }
  }
  return out;
}

for (const file of walk(srcDir)) {
  const rel = path.relative(path.resolve(__dirname, '..'), file);
  const content = fs.readFileSync(file, 'utf8');
  const lines = content.split('\n');

  if (!ALLOW_HEX_FILES.has(rel)) {
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (HEX_RE.test(line)) {
        HEX_RE.lastIndex = 0;
        violations.push({ file: rel, line: i + 1, rule: 'hardcoded-hex', snippet: line.trim().slice(0, 120) });
      }
      HEX_RE.lastIndex = 0;
    }
  }

  let m;
  while ((m = RAW_PALETTE_RE.exec(content))) {
    const line = content.slice(0, m.index).split('\n').length;
    violations.push({ file: rel, line, rule: 'raw-quasar-palette', snippet: m[0] });
  }
  RAW_PALETTE_RE.lastIndex = 0;

  while ((m = PUSH_GLOSSY_RE.exec(content))) {
    const line = content.slice(0, m.index).split('\n').length;
    violations.push({ file: rel, line, rule: 'q-btn-push-glossy', snippet: m[0].slice(0, 80) });
  }
  PUSH_GLOSSY_RE.lastIndex = 0;

  while ((m = BTN_NO_CAPS_RE.exec(content))) {
    const line = content.slice(0, m.index).split('\n').length;
    violations.push({ file: rel, line, rule: 'q-btn-missing-no-caps', snippet: m[0].slice(0, 80) });
  }
  BTN_NO_CAPS_RE.lastIndex = 0;
}

const byRule = {};
for (const v of violations) {
  byRule[v.rule] = (byRule[v.rule] || 0) + 1;
}

console.log('TradeFlow BD — UI color / button lint\n');
console.log('Summary:', byRule);
console.log(`Total violations: ${violations.length}\n`);

const maxShow = 40;
for (const v of violations.slice(0, maxShow)) {
  console.log(`${v.file}:${v.line} [${v.rule}] ${v.snippet}`);
}
if (violations.length > maxShow) {
  console.log(`… and ${violations.length - maxShow} more`);
}

if (violations.length > 0) {
  console.log('\n(Listed violations — migrate to tokens / TfBtn / semantic Quasar colors.)');
  process.exit(process.env.STRICT_UI_COLORS === '1' ? 1 : 0);
}

console.log('\nUI color check PASSED');
