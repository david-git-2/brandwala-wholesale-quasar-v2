CREATE FUNCTION public.can_manage_costing_item (
  p_file_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.product_based_costing_files f
    where f.id = p_file_id
      and public.can_manage_costing(f.tenant_id)
  )
$function$;

GRANT ALL ON FUNCTION public.can_manage_costing_item(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_manage_costing_item(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_manage_costing_item(bigint) TO service_role;