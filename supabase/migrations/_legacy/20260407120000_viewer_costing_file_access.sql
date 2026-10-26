-- =========================================================
-- Viewer costing-file access
-- Adds viewer membership support to app_role.
-- =========================================================

do $$
begin
  if not exists (
    select 1
    from pg_enum e
    inner join pg_type t
      on t.oid = e.enumtypid
    where t.typnamespace = 'public'::regnamespace
      and t.typname = 'app_role'
      and e.enumlabel = 'viewer'
  ) then
    alter type public.app_role add value 'viewer';
  end if;
end
$$;
