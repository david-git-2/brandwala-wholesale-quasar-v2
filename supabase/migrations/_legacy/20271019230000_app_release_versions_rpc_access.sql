-- Any active tenant member can read deploy versions (profile menu).
create or replace function public.get_app_release_versions()
returns table (
  backend_version text,
  frontend_version text,
  backend_updated_at timestamptz,
  frontend_updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path to public
as $$
begin
  if not (
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.is_active = true
        and lower(trim(m.email)) = public.current_user_email()
    )
  ) then
    raise exception 'not allowed';
  end if;

  return query
  select
    v.backend_version,
    v.frontend_version,
    v.backend_updated_at,
    v.frontend_updated_at
  from public.app_release_versions v
  where v.id = 1;
end;
$$;
