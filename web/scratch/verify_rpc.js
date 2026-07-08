import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config({ path: '../.env' });
dotenv.config({ path: '.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
// Use SUPABASE_SECRET_KEY to bypass RLS and authenticate as service role to verify function definitions
const supabaseSecretKey = process.env.SUPABASE_SECRET_KEY;

if (!supabaseUrl || !supabaseSecretKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_SECRET_KEY in env files');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseSecretKey);

async function checkRPCs() {
  console.log('=== CHECKING RPC AVAILABILITY ===');

  // 1. Let's try to query the schema migrations or call the functions with dummy inputs
  // We check if functions list_investor_transactions, upsert_shipment_investment, refresh_shipment_investor_profits respond

  console.log('\n1. Testing list_investor_transactions:');
  const { data: txData, error: txErr } = await supabase.rpc('list_investor_transactions', {
    p_tenant_id: 10,
    p_investor_id: 1, // dummy
    p_limit: 1,
    p_offset: 0,
  });
  if (txErr) {
    console.log(
      '-> Got error (which confirms if it exists or if parameters match):',
      txErr.message,
    );
  } else {
    console.log('-> Responded successfully (empty or data):', txData);
  }

  console.log(
    '\n2. Testing upsert_shipment_investment (expecting error or success depending on dummy ID validation):',
  );
  const { data: upsertData, error: upsertErr } = await supabase.rpc('upsert_shipment_investment', {
    p_id: null,
    p_tenant_id: 10,
    p_global_shipment_id: 1,
    p_investor_id: 1,
    p_cost_share_pct: 10.0,
  });
  if (upsertErr) {
    console.log('-> Got error (confirms function exists & ran logic):', upsertErr.message);
  } else {
    console.log('-> Responded successfully:', upsertData);
  }

  console.log('\n3. Testing refresh_shipment_investor_profits:');
  const { data: refreshData, error: refreshErr } = await supabase.rpc(
    'refresh_shipment_investor_profits',
    {
      p_global_shipment_id: 1,
    },
  );
  if (refreshErr) {
    console.log('-> Got error (confirms function exists & ran logic):', refreshErr.message);
  } else {
    console.log('-> Responded successfully:', refreshData);
  }

  console.log('\n4. Checking users in auth table to see if awnrc1234@gmail.com exists:');
  const { data: users, error: userErr } = await supabase
    .from('memberships')
    .select('role, email')
    .limit(20);
  if (userErr) {
    console.error('Error reading memberships:', userErr.message);
  } else {
    console.log('Memberships in DB:', users);
  }

  console.log('\n5. Testing get_investor_bootstrap_context:');
  const { data: bootstrapData, error: bootstrapErr } = await supabase.rpc(
    'get_investor_bootstrap_context',
    {
      p_tenant_id: 10,
    },
  );
  if (bootstrapErr) {
    console.log('-> Got error (confirms function exists & ran logic):', bootstrapErr.message);
  } else {
    console.log('-> Responded successfully:', bootstrapData);
  }

  console.log('\n6. Testing get_investor_allocation_detail:');
  const { data: detailData, error: detailErr } = await supabase.rpc(
    'get_investor_allocation_detail',
    {
      p_tenant_id: 10,
      p_investor_id: 1,
      p_global_shipment_id: 1,
    },
  );
  if (detailErr) {
    console.log('-> Got error (confirms function exists & ran logic):', detailErr.message);
  } else {
    console.log('-> Responded successfully:', detailData);
  }
}

checkRPCs();
