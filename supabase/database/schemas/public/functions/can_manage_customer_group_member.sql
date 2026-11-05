CREATE FUNCTION public.can_manage_customer_group_member (
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
    from public.customer_groups cg
    where cg.id = p_customer_group_id
      and public.can_manage_customer_group(coalesce(cg.parent_tenant_id, cg.tenant_id))
  );
$function$;

GRANT ALL ON FUNCTION public.can_manage_customer_group_member(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_manage_customer_group_member(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_manage_customer_group_member(bigint) TO service_role;