CREATE FUNCTION public.resolve_customer_group_notification_user_ids (
  p_customer_group_id bigint
)
  RETURNS uuid[]
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select coalesce(array_agg(distinct u.id), array[]::uuid[])
  from public.customer_group_members cgm
  join auth.users u on lower(trim(u.email)) = lower(trim(cgm.email))
  where cgm.customer_group_id = p_customer_group_id
    and cgm.is_active = true;
$function$;

GRANT ALL ON FUNCTION public.resolve_customer_group_notification_user_ids(bigint) TO anon;

GRANT ALL ON FUNCTION public.resolve_customer_group_notification_user_ids(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.resolve_customer_group_notification_user_ids(bigint) TO service_role;