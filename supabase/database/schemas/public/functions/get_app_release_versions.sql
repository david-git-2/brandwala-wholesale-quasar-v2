CREATE FUNCTION public.get_app_release_versions()
  RETURNS TABLE (
    backend_version     text,
    frontend_version    text,
    backend_updated_at  timestamp with time zone,
    frontend_updated_at timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.get_app_release_versions() TO anon;

GRANT ALL ON FUNCTION public.get_app_release_versions() TO authenticated;

GRANT ALL ON FUNCTION public.get_app_release_versions() TO service_role;