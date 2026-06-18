import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config({ path: '../.env' });
dotenv.config({ path: '.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const secretKey = process.env.SUPABASE_SECRET_KEY;

if (!supabaseUrl || !secretKey) {
  console.error("Missing VITE_SUPABASE_URL or SUPABASE_SECRET_KEY in environment.");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, secretKey, {
  auth: {
    persistSession: false
  }
});

async function run() {
  console.log("=== TESTING BARCODE GENERATION RPC ===");
  
  try {
    const { data: tenants, error: tenantError } = await supabase
      .from('tenants')
      .select('id, name')
      .limit(1);

    if (tenantError) {
      console.error("Error fetching tenants:", tenantError);
      return;
    }

    if (!tenants || tenants.length === 0) {
      console.error("No tenants found.");
      return;
    }

    const tenantId = tenants[0].id;
    console.log(`Using Tenant: ${tenants[0].name} (ID: ${tenantId})`);

    const qty = 50;
    const email = "test@brandwala.com";

    const { data, error } = await supabase.rpc('generate_thrift_barcodes', {
      p_tenant_id: tenantId,
      p_quantity: qty,
      p_inserted_by: email
    });

    if (error) {
      console.error("RPC Error:", error);
    } else {
      console.log(`Successfully generated ${data.length} barcodes!`);
      console.log("First 5 barcodes:", data.slice(0, 5));
      console.log("Last 5 barcodes:", data.slice(-5));
    }
  } catch (err) {
    console.error("Execution error:", err);
  }
}

run();
