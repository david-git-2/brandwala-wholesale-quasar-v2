#!/usr/bin/env node
/**
 * WCAG contrast gate for TradeFlow BD color tokens (see web/src/css/app.scss).
 * Text pairs: >= 4.5:1. Large / UI pairs: >= 3:1 (reported only).
 */

const SCOPES = ['platform', 'app', 'shop', 'investor'];

const NEUTRALS = {
  light: {
    canvas: '#f4f6f8',
    surface: '#ffffff',
    ink: '#0f172a',
    muted: '#475569',
    chromeText: '#5b6b80',
    disabledBg: '#eef1f5',
    disabledInk: '#94a3b8',
    success: '#15803d',
    warning: '#b45309',
    error: '#b91c1c',
    info: '#0e7490',
  },
  dark: {
    canvas: '#131316',
    surface: '#1e1e23',
    ink: '#e4e4e7',
    muted: '#b4b4bd',
    chromeText: '#a0a0aa',
    disabledBg: '#26262b',
    disabledInk: '#8a8a94',
    success: '#4ade80',
    warning: '#fbbf24',
    error: '#f87171',
    info: '#22d3ee',
  },
};

const SCOPE_PRIMARY = {
  light: {
    platform: { primary: '#3d3a8c', onPrimary: '#ffffff' },
    app: { primary: '#1f2937', onPrimary: '#ffffff' },
    shop: { primary: '#2b5fa8', onPrimary: '#ffffff' },
    investor: { primary: '#1e3a5f', onPrimary: '#ffffff' },
  },
  dark: {
    platform: { primary: '#a5a3f0', onPrimary: '#0f1020' },
    app: { primary: '#e5e7eb', onPrimary: '#111827' },
    shop: { primary: '#8bb6ee', onPrimary: '#0b1b2e' },
    investor: { primary: '#9db4dc', onPrimary: '#0b1626' },
  },
};

function hexToRgb(hex) {
  const h = hex.replace('#', '');
  const n = h.length === 3
    ? h.split('').map((c) => parseInt(c + c, 16))
    : [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
  return n;
}

function luminance([r, g, b]) {
  const srgb = [r, g, b].map((v) => {
    const c = v / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * srgb[0] + 0.7152 * srgb[1] + 0.0722 * srgb[2];
}

function contrastRatio(fgHex, bgHex) {
  const l1 = luminance(hexToRgb(fgHex));
  const l2 = luminance(hexToRgb(bgHex));
  const lighter = Math.max(l1, l2);
  const darker = Math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

function mixHex(fgHex, bgHex, fgPercent) {
  const [fr, fg, fb] = hexToRgb(fgHex);
  const [br, bg, bb] = hexToRgb(bgHex);
  const t = fgPercent / 100;
  const mix = (a, b) => Math.round(a * t + b * (1 - t));
  const toHex = (n) => n.toString(16).padStart(2, '0');
  return `#${toHex(mix(fr, br))}${toHex(mix(fg, bg))}${toHex(mix(fb, bb))}`;
}

function softBg(semantic, surface, mode) {
  const pct = mode === 'dark' ? 18 : 12;
  return mixHex(semantic, surface, pct);
}

/** @returns {{ failures: string[], warnings: string[], rows: string[] }} */
function runMode(mode) {
  const n = NEUTRALS[mode];
  const failures = [];
  const warnings = [];
  const rows = [];

  const textPairs = [
    ['ink on surface', n.ink, n.surface, 4.5],
    ['muted on surface', n.muted, n.surface, 4.5],
    ['chrome-text on surface', n.chromeText, n.surface, 4.5],
    ['success on surface', n.success, n.surface, 4.5],
    ['warning on surface', n.warning, n.surface, 4.5],
    ['error on surface', n.error, n.surface, 4.5],
    ['info on surface', n.info, n.surface, 4.5],
    ['ink on success-soft', n.ink, softBg(n.success, n.surface, mode), 4.5],
    ['ink on warning-soft', n.ink, softBg(n.warning, n.surface, mode), 4.5],
    ['ink on error-soft', n.ink, softBg(n.error, n.surface, mode), 4.5],
    ['ink on info-soft', n.ink, softBg(n.info, n.surface, mode), 4.5],
    ['ink on canvas', n.ink, n.canvas, 4.5],
  ];

  const uiPairs = [['disabled-ink on disabled-bg (UI)', n.disabledInk, n.disabledBg, 3]];

  for (const [label, fg, bg, min] of textPairs) {
    const ratio = contrastRatio(fg, bg);
    const ok = ratio >= min;
    rows.push(`${mode.padEnd(5)} | ${label.padEnd(28)} | ${ratio.toFixed(2)}:1 | ${ok ? 'PASS' : 'FAIL'}`);
    if (!ok) failures.push(`${mode}/${label}: ${ratio.toFixed(2)}:1 (need ${min}:1)`);
  }

  for (const [label, fg, bg, min] of uiPairs) {
    const ratio = contrastRatio(fg, bg);
    const ok = ratio >= min;
    rows.push(`${mode.padEnd(5)} | ${label.padEnd(28)} | ${ratio.toFixed(2)}:1 | ${ok ? 'PASS (UI)' : 'WARN (UI)'}`);
    if (!ok) warnings.push(`${mode}/${label}: ${ratio.toFixed(2)}:1 (UI min ${min}:1)`);
  }

  for (const scope of SCOPES) {
    const { primary, onPrimary } = SCOPE_PRIMARY[mode][scope];
    const label = `${scope} on-primary on primary`;
    const ratio = contrastRatio(onPrimary, primary);
    const ok = ratio >= 4.5;
    rows.push(`${mode.padEnd(5)} | ${label.padEnd(28)} | ${ratio.toFixed(2)}:1 | ${ok ? 'PASS' : 'FAIL'}`);
    if (!ok) failures.push(`${mode}/${label}: ${ratio.toFixed(2)}:1`);
  }

  return { failures, warnings, rows };
}

// warnings collected per mode but only text failures exit non-zero

const allRows = [];
const allFailures = [];
const allWarnings = [];

for (const mode of ['light', 'dark']) {
  const { failures, warnings, rows } = runMode(mode);
  allRows.push(...rows);
  allFailures.push(...failures);
  allWarnings.push(...warnings);
}

console.log('TradeFlow BD — WCAG contrast (text pairs)\n');
console.log('mode  | pair                         | ratio    | result');
console.log('------+------------------------------+----------+-------');
for (const row of allRows) {
  console.log(row);
}

if (allWarnings.length) {
  console.log(`UI contrast notes (${allWarnings.length}):`);
  for (const w of allWarnings) console.log(`  - ${w}`);
  console.log('');
}

if (allFailures.length) {
  console.error(`Contrast check FAILED (${allFailures.length} text pair(s)):`);
  for (const f of allFailures) console.error(`  - ${f}`);
  process.exit(1);
}

console.log('Contrast check PASSED — all text pairs >= 4.5:1');
