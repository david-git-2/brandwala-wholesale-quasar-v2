-- =========================================================
-- Costing file status rename: completed -> po_placed
-- =========================================================

do $$
begin
  if exists (
    select 1
    from pg_type t
    join pg_enum e on e.enumtypid = t.oid
    where t.typnamespace = 'public'::regnamespace
      and t.typname = 'costing_file_status'
      and e.enumlabel = 'completed'
  ) then
    alter type public.costing_file_status rename value 'completed' to 'po_placed';
  end if;
end
$$;
