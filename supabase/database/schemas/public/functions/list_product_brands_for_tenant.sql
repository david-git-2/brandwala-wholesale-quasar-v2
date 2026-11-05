CREATE FUNCTION public.list_product_brands_for_tenant (
  p_tenant_id   bigint,
  p_vendor_code text   DEFAULT NULL::text,
  p_vendor_id   bigint DEFAULT NULL::bigint
)
  RETURNS SETOF public.product_brands
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_vendor_code text;
  v_scope_tenant_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_scope_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_vendor_code := nullif(upper(trim(coalesce(p_vendor_code, ''))), '');

  return query
  select pb.*
  from public.product_brands pb
  where pb.parent_tenant_id = v_scope_tenant_id
    and (v_vendor_code is null or pb.vendor_code = v_vendor_code)
    and (p_vendor_id is null or pb.vendor_id = p_vendor_id)
  order by pb.name asc;
end;
$function$;

GRANT ALL ON FUNCTION public.list_product_brands_for_tenant(bigint, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_product_brands_for_tenant(bigint, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_product_brands_for_tenant(bigint, text, bigint) TO service_role;