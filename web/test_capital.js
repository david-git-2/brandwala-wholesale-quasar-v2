import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config({ path: '../.env' });
dotenv.config({ path: '.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing SUPABASE_URL or VITE_SUPABASE_ANON_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function run() {
  console.log('=== SIGNING IN ===');
  const email = process.env.KOBA_EMAIL;
  const password = process.env.KOBA_PASSWORD;

  if (!email || !password) {
    console.error('Missing KOBA_EMAIL or KOBA_PASSWORD in env files');
    process.exit(1);
  }

  const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (authErr) {
    console.error('Auth error:', authErr.message);
    return;
  }
  console.log('Auth successful! User:', authData.user.email);

  // Get user memberships to determine active tenants
  const { data: memberships, error: membErr } = await supabase
    .from('memberships')
    .select('tenant_id, role, is_active');

  if (membErr) {
    console.error('Memberships Fetch Error:', membErr.message);
    return;
  }
  console.log('User memberships:', memberships);

  const activeMemb = memberships.find((m) => m.is_active);
  if (!activeMemb) {
    console.error('No active memberships found for user.');
    return;
  }

  const tid = activeMemb.tenant_id;
  console.log(`Using Tenant ID: ${tid}`);

  console.log('\n=== CALLING list_investor_profiles ===');
  const { data: profiles, error: profErr } = await supabase.rpc('list_investor_profiles', {
    p_tenant_id: tid,
    p_limit: 10,
  });
  if (profErr) {
    console.error('list_investor_profiles error:', profErr.message);
  } else {
    console.log('Profiles list:', profiles);
  }

  console.log('\n=== CALLING list_investor_transactions ===');
  const { data: txs, error: txErr } = await supabase.rpc('list_investor_transactions', {
    p_tenant_id: tid,
    p_limit: 5,
  });
  if (txErr) {
    console.error('list_investor_transactions error:', txErr.message);
  } else {
    console.log('Transactions list:', txs);
  }
}

run();
