import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config({ path: '../.env' });
dotenv.config({ path: '.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const secretKey = process.env.SUPABASE_SECRET_KEY;

const supabase = createClient(supabaseUrl, secretKey, {
  auth: { persistSession: false }
});

async function run() {
  const { data, error } = await supabase
    .from('v_shipment_accounting_ledger')
    .select('*')
    .eq('type', 'commerce')
    .limit(5);

  if (error) {
    console.error(error);
  } else {
    console.log(JSON.stringify(data, null, 2));
  }
}
run();
