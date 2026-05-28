-- Migration to add source and hazardous to public.products table
begin;

alter table public.products add column if not exists source text check (source in ('website', 'excel'));
alter table public.products add column if not exists hazardous boolean default null;

commit;
