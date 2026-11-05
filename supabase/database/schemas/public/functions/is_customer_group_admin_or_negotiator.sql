CREATE FUNCTION public.is_customer_group_admin_or_negotiator (
  p_customer_group_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.customer_group_members cgm
    where cgm.customer_group_id = p_customer_group_id
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.role in ('admin', 'manager')
      and cgm.is_active = true
  )
$function$;

GRANT ALL ON FUNCTION public.is_customer_group_admin_or_negotiator(bigint) TO anon;

GRANT ALL ON FUNCTION public.is_customer_group_admin_or_negotiator(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.is_customer_group_admin_or_negotiator(bigint) TO service_role;