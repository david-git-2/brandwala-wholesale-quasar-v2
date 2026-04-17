begin;

alter table public.product_based_costing_items
  add column if not exists note text null;

create index if not exists product_based_costing_items_note_idx
  on public.product_based_costing_items using gin (to_tsvector('simple', coalesce(note, '')));

commit;
