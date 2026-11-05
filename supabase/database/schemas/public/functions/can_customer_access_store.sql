CREATE FUNCTION public.can_customer_access_store (
  p_store_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.store_access sa
    join public.customer_group_members cgm
      on cgm.customer_group_id = sa.customer_group_id
    where sa.store_id = p_store_id
      and sa.status = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
  )
$function$;

GRANT ALL ON FUNCTION public.can_customer_access_store(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_customer_access_store(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_customer_access_store(bigint) TO service_role;