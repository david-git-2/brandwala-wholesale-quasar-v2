import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';

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
  console.log("=== INVOICES ===");
  const { data: invoices, error: invErr } = await supabase
    .from('commerce_invoices')
    .select('id, order_id, tenant_id, total_amount, is_customer_group_paid')
    .order('id', { ascending: false })
    .limit(5);

  if (invErr) {
    console.error("Invoices error:", invErr);
  } else {
    console.log(JSON.stringify(invoices, null, 2));
  }

  console.log("\n=== COMMERCE ORDER ITEMS ===");
  const { data: orderItems, error: itemsErr } = await supabase
    .from('commerce_order_items')
    .select('id, order_id, invoice_id, product_id, quantity, inventory_item_id, cost_bdt, sell_price_bdt, recipient_price_bdt')
    .order('id', { ascending: false })
    .limit(5);

  if (itemsErr) {
    console.error("Order items error:", itemsErr);
  } else {
    console.log(JSON.stringify(orderItems, null, 2));
  }

  console.log("\n=== INVENTORY ACCOUNTING ENTRIES (type = 'commerce') ===");
  const { data: entries, error: entriesErr } = await supabase
    .from('inventory_accounting_entries')
    .select('id, type, commerce_order_item_id, commerce_invoice_id, tenant_id, inventory_item_id, product_id, quantity, total_cost_amount, status')
    .eq('type', 'commerce')
    .order('id', { ascending: false })
    .limit(5);

  if (entriesErr) {
    console.error("Entries error:", entriesErr);
  } else {
    console.log(JSON.stringify(entries, null, 2));
  }

  console.log("\n=== COMMERCE ACCOUNTING VIEW ===");
  const { data: viewData, error: viewErr } = await supabase
    .from('commerce_accounting')
    .select('*')
    .order('id', { ascending: false })
    .limit(5);

  if (viewErr) {
    console.error("View error:", viewErr);
  } else {
    console.log(JSON.stringify(viewData, null, 2));
  }
}

run();
