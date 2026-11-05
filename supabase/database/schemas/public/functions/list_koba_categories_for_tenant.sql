CREATE FUNCTION public.list_koba_categories_for_tenant (
  p_tenant_id bigint
)
  RETURNS jsonb
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select coalesce(
    jsonb_agg(
      jsonb_build_object('id', kc.id, 'name', kc.name)
      order by kc.name asc
    ),
    '[]'::jsonb
  )
  from public.koba_categories kc
  where kc.tenant_id = p_tenant_id
    and exists (
      select 1
      from public.koba_products kp
      where kp.category_id = kc.id
        and kp.tenant_id   = p_tenant_id
        and kp.source_type = 'retail'
        and kp.in_stock    = true
    );
$function$;

GRANT ALL ON FUNCTION public.list_koba_categories_for_tenant(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_koba_categories_for_tenant(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_koba_categories_for_tenant(bigint) TO service_role;