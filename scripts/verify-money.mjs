#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const PGTEST_FILES = [
  'supabase/tests/000_money_kernel_bootstrap.sql',
  'supabase/tests/001_cross_module_golden_helpers.sql',
  'supabase/tests/002_shipment_ap_bill_v2_create_multiline.sql',
  'supabase/tests/shipment_ap_lifecycle_enforce.sql',
  'supabase/tests/shipment_s54_money_golden.sql',
  'supabase/tests/shipment_money_scenarios.sql',
];

function fail(section, detail = '') {
  const suffix = detail ? ` ${detail}` : '';
  console.error(`VERIFY MONEY: FAIL ${section}${suffix}`);
  process.exit(1);
}

function run(cmd, args, opts = {}) {
  const result = spawnSync(cmd, args, {
    cwd: root,
    stdio: 'inherit',
    ...opts,
  });
  if (result.status !== 0) {
    fail('pgtap', `(${cmd} ${args.join(' ')})`);
  }
}

const pgArgs = ['test', 'db', ...PGTEST_FILES];
const pg = spawnSync('supabase', pgArgs, { cwd: root, stdio: 'inherit' });
if (pg.status !== 0) {
  fail('pgtap');
}

const vitest = spawnSync(
  'pnpm',
  ['--filter', 'web', 'exec', 'vitest', 'run', 'src/shared/shipment-engine', 'src/modules/procurement_stock/utils'],
  { cwd: root, stdio: 'inherit' },
);
if (vitest.status !== 0) {
  fail('vitest');
}

const driftSql = readFileSync(path.join(root, 'supabase/verify/shipment_money_drift.sql'), 'utf8');
const drift = spawnSync(
  'docker',
  [
    'exec',
    'supabase_db_brandwala-wholesale-quasar',
    'psql',
    '-U',
    'postgres',
    '-d',
    'postgres',
    '-v',
    'ON_ERROR_STOP=1',
    '-f',
    '-',
  ],
  { cwd: root, input: driftSql, stdio: ['pipe', 'inherit', 'inherit'] },
);
if (drift.status !== 0) {
  fail('drift');
}

console.log('VERIFY MONEY: PASS');