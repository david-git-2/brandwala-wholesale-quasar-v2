CREATE FUNCTION public.list_product_categories_for_tenant (
  p_tenant_id   bigint,
  p_vendor_code text   DEFAULT NULL::text,
  p_vendor_id   bigint DEFAULT NULL::bigint
)
  RETURNS SETOF public.product_categories
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
  select pc.*
  from public.product_categories pc
  where pc.parent_tenant_id = v_scope_tenant_id
    and (v_vendor_code is null or pc.vendor_code = v_vendor_code)
    and (p_vendor_id is null or pc.vendor_id = p_vendor_id)
  order by pc.name asc;
end;
$function$;

GRANT ALL ON FUNCTION public.list_product_categories_for_tenant(bigint, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_product_categories_for_tenant(bigint, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_product_categories_for_tenant(bigint, text, bigint) TO service_role;