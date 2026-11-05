CREATE FUNCTION public.is_superadmin()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'superadmin'
      and m.is_active = true
      and m.tenant_id is null
  )
$function$;

GRANT ALL ON FUNCTION public.is_superadmin() TO anon;

GRANT ALL ON FUNCTION public.is_superadmin() TO authenticated;

GRANT ALL ON FUNCTION public.is_superadmin() TO service_role;