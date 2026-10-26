-- =========================================================
-- Costing status compatibility:
-- - accept legacy input "completed"
-- - normalize persisted value to "po_placed"
-- =========================================================

do $$
begin
  if exists (
    select 1
    from pg_type t
    where t.typnamespace = 'public'::regnamespace
      and t.typname = 'costing_file_status'
  ) and not exists (
    select 1
    from pg_type t
    join pg_enum e on e.enumtypid = t.oid
    where t.typnamespace = 'public'::regnamespace
      and t.typname = 'costing_file_status'
      and e.enumlabel = 'completed'
  ) then
    alter type public.costing_file_status add value 'completed';
  end if;
end
$$;

create or replace function public.normalize_costing_file_status_po_placed()
returns trigger
language plpgsql
as $$
begin
  if new.status::text = 'completed' then
    new.status = 'po_placed'::public.costing_file_status;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_costing_files_normalize_status_po_placed on public.costing_files;
create trigger trg_costing_files_normalize_status_po_placed
before insert or update on public.costing_files
for each row execute function public.normalize_costing_file_status_po_placed();
