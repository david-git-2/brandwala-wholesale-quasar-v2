import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config({ path: '../.env' });
dotenv.config({ path: '.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

console.log("Supabase URL:", supabaseUrl);

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function run() {
  // 1. Sign in
  const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({
    email: process.env.KOBA_EMAIL,
    password: process.env.KOBA_PASSWORD
  });

  if (authErr) {
    console.error("Auth error:", authErr.message);
    return;
  }
  console.log("Auth successful! User:", authData.user.email);

  // 2. Fetch tags to use
  const { data: tags, error: tagsErr } = await supabase.from('tags').select('*').limit(2);
  if (tagsErr) {
    console.error("Fetch tags error:", tagsErr.message);
    return;
  }
  console.log("Fetched tags:", tags.map(t => ({ id: t.id, name: t.name })));

  if (tags.length === 0) {
    console.log("No tags found. Cannot proceed with link test.");
    return;
  }

  // 3. Create a test item
  const { data: item, error: itemErr } = await supabase.from('items').insert({
    title: 'Test RLS Task ' + Date.now(),
    type: 'task',
    status: 'todo',
    priority: 'medium',
    tenant_id: 10 // Let's use tenant_id 10 which is default
  }).select().single();

  if (itemErr) {
    console.error("Create item error:", itemErr.message);
    return;
  }
  console.log("Created item:", { id: item.id, title: item.title });

  // 4. Link tag
  const tagToLink = tags[0];
  console.log(`Linking tag ID ${tagToLink.id} to item ID ${item.id}...`);
  const { error: linkErr } = await supabase.from('item_tags').insert({
    item_id: item.id,
    tag_id: tagToLink.id
  });

  if (linkErr) {
    console.error("Link tag error:", linkErr.message);
    // Cleanup
    await supabase.from('items').delete().eq('id', item.id);
    return;
  }
  console.log("Link successful!");

  // 5. Fetch using list_items_paginated
  console.log("Fetching items via list_items_paginated...");
  const { data: rpcData, error: rpcErr } = await supabase.rpc('list_items_paginated', {
    p_tenant_id: 10,
    p_page: 1,
    p_page_size: 20,
    p_search: item.title
  });

  if (rpcErr) {
    console.error("RPC error:", rpcErr.message);
  } else {
    console.log("RPC Data:", JSON.stringify(rpcData, null, 2));
  }

  // Cleanup
  console.log("Cleaning up test item...");
  await supabase.from('items').delete().eq('id', item.id);
  console.log("Cleanup finished.");
}

run();
