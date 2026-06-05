import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: '../.env' });
dotenv.config({ path: '.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;
const secretKey = process.env.SUPABASE_SECRET_KEY;

console.log("Supabase URL:", supabaseUrl);
console.log("Anon Key exists:", !!supabaseAnonKey);

const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Try to sign in or perform basic check
async function run() {
  // Try directly selecting tags
  const { data: tags, error: tagsErr } = await supabase.from('tags').select('*');
  console.log("Tags:", tagsErr ? `Error: ${tagsErr.message}` : tags);

  // Try directly selecting items
  const { data: items, error: itemsErr } = await supabase.from('items').select('*').limit(5);
  console.log("Items:", itemsErr ? `Error: ${itemsErr.message}` : items);
}

run();
