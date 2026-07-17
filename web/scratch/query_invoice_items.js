import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config({ path: '../.env' });
dotenv.config({ path: '.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseSecretKey = process.env.SUPABASE_SECRET_KEY;

if (!supabaseUrl || !supabaseSecretKey) {
  console.error('Missing VITE_SUPABASE_URL or SUPABASE_SECRET_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseSecretKey);

async function inspectInvoiceItems() {
  console.log('=== INSPECTING INVOICE ITEM ID 72 ===');

  const { data: item, error: itemErr } = await supabase
    .from('global_invoice_items')
    .select('*')
    .eq('id', 72)
    .single();

  if (itemErr) {
    console.error('Error fetching global_invoice_items:', itemErr);
    return;
  }
  console.log('Invoice Item (ID 72):', item);

  console.log('\n=== INSPECTING GLOBAL STOCK WITH ID', item.global_stock_id, '===');
  const { data: stock, error: stockErr } = await supabase
    .from('global_stocks')
    .select('*')
    .eq('id', item.global_stock_id)
    .single();

  if (stockErr) {
    console.error('Error fetching global_stocks:', stockErr);
  } else {
    console.log('Global Stock:', stock);
  }

  console.log(
    '\n=== INSPECTING SHIPMENT ITEM WITH ID',
    item.shipment_item_id,
    '(FROM INVOICE ITEM) ===',
  );
  if (item.shipment_item_id) {
    const { data: shipmentItem, error: shipmentItemErr } = await supabase
      .from('global_shipment_items')
      .select('*')
      .eq('id', item.shipment_item_id)
      .single();

    if (shipmentItemErr) {
      console.error('Error fetching shipment item:', shipmentItemErr);
    } else {
      console.log('Shipment Item (from invoice item):', shipmentItem);
    }
  } else {
    console.log('No shipment_item_id on global_invoice_items.');
  }

  console.log(
    '\n=== INSPECTING SHIPMENT ITEM WITH ID',
    stock?.shipment_item_id,
    '(FROM GLOBAL STOCK) ===',
  );
  if (stock?.shipment_item_id) {
    const { data: shipmentItemStock, error: shipmentItemStockErr } = await supabase
      .from('global_shipment_items')
      .select('*')
      .eq('id', stock.shipment_item_id)
      .single();

    if (shipmentItemStockErr) {
      console.error('Error fetching shipment item from stock:', shipmentItemStockErr);
    } else {
      console.log('Shipment Item (from stock):', shipmentItemStock);
    }
  }

  console.log('\n=== INSPECTING ALL SHIPMENT ITEMS FOR PRODUCT ID', item.product_id, '===');
  const { data: productItems, error: productItemsErr } = await supabase
    .from('global_shipment_items')
    .select('*')
    .eq('product_id', item.product_id);
  if (productItemsErr) {
    console.error('Error fetching all shipment items for product:', productItemsErr);
  } else {
    console.log('All Shipment Items for Product ID:', productItems);
  }
}

inspectInvoiceItems();
