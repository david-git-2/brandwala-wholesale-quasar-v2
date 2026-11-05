CREATE FUNCTION public.is_assigned_costing_file_viewer (
  p_costing_file_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.costing_file_viewers cfv
    inner join public.memberships m
      on m.id = cfv.membership_id
    where cfv.costing_file_id = p_costing_file_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role = 'viewer'
  );
$function$;

GRANT ALL ON FUNCTION public.is_assigned_costing_file_viewer(bigint) TO anon;

GRANT ALL ON FUNCTION public.is_assigned_costing_file_viewer(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.is_assigned_costing_file_viewer(bigint) TO service_role;