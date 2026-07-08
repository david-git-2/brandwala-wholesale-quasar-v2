import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

dotenv.config({ path: '../.env' });
dotenv.config({ path: '.env' });

const url = process.env.VITE_SUPABASE_URL;
const key = process.env.SUPABASE_SECRET_KEY;
if (!url || !key) {
  console.error('Missing VITE_SUPABASE_URL or SUPABASE_SECRET_KEY');
  process.exit(1);
}

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const registrySrc = fs.readFileSync(
  path.join(__dirname, '../src/modules/navigation/moduleRegistry.ts'),
  'utf8',
);
const registryKeys = new Set(
  [...registrySrc.matchAll(/key:\s*'([^']+)'/g)].map((m) => m[1]),
);

const supabase = createClient(url, key, { auth: { persistSession: false } });
const { data, error } = await supabase
  .from('modules')
  .select('id,key,name,is_active,parent_module_key')
  .order('id');

if (error) {
  console.error(error);
  process.exit(1);
}

const orphans = data.filter((m) => !registryKeys.has(m.key));
const missingSeeds = [...registryKeys].filter((k) => !data.some((m) => m.key === k));

console.log(`DB modules: ${data.length} | registry keys: ${registryKeys.size}`);
console.log('\n=== ORPHANS (in DB, NOT in registry = no longer a feature) ===');
console.log(orphans.length ? JSON.stringify(orphans, null, 2) : 'none');
console.log('\n=== MISSING SEEDS (in registry, NOT in DB) ===');
console.log(missingSeeds.length ? missingSeeds.join(', ') : 'none');
