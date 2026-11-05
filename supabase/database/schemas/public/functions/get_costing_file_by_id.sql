CREATE FUNCTION public.get_costing_file_by_id (
  p_id bigint
)
  RETURNS TABLE (
    id                  bigint,
    name                text,
    cargo_rate_1kg      numeric,
    cargo_rate_2kg      numeric,
    conversion_rate     numeric,
    admin_profit_rate   numeric,
    status              public.costing_file_status,
    market              text,
    customer_group_id   bigint,
    tenant_id           bigint,
    created_by_email    text,
    default_shipment_id bigint,
    created_at          timestamp with time zone,
    updated_at          timestamp with time zone
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    cf.id,
    cf.name,
    cf.cargo_rate_1kg,
    cf.cargo_rate_2kg,
    cf.conversion_rate,
    cf.admin_profit_rate,
    cf.status,
    cf.market,
    cf.customer_group_id,
    cf.tenant_id,
    cf.created_by_email,
    cf.default_shipment_id,
    cf.created_at,
    cf.updated_at
  from public.costing_files cf
  where cf.id = p_id
    and public.can_view_costing_file(cf.id)
  limit 1;
$function$;

GRANT ALL ON FUNCTION public.get_costing_file_by_id(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_costing_file_by_id(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_costing_file_by_id(bigint) TO service_role;