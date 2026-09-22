alter table public.batch_code_items
  add column if not exists is_arrived boolean not null default false;
