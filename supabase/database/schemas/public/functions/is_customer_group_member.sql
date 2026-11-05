CREATE FUNCTION public.is_customer_group_member (
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
    from public.customer_group_members
    where customer_group_id = p_customer_group_id
      and lower(trim(email)) = public.current_user_email()
      and is_active = true
  );
$function$;

GRANT ALL ON FUNCTION public.is_customer_group_member(bigint) TO anon;

GRANT ALL ON FUNCTION public.is_customer_group_member(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.is_customer_group_member(bigint) TO service_role;