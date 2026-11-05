CREATE FUNCTION public.update_costing_file (
  p_id                bigint,
  p_name              text   DEFAULT NULL::text,
  p_market            text   DEFAULT NULL::text,
  p_customer_group_id bigint DEFAULT NULL::bigint
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
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with updated as (
    update public.costing_files cf
    set
      name = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
          or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
        then coalesce(trim(p_name), cf.name)
        else cf.name
      end,
      market = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
          or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
        then coalesce(trim(p_market), cf.market)
        else cf.market
      end,
      customer_group_id = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
        then coalesce(p_customer_group_id, cf.customer_group_id)
        else cf.customer_group_id
      end
    where cf.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
      )
    returning
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
  )
  select *
  from updated;
$function$;

GRANT ALL ON FUNCTION public.update_costing_file(bigint, text, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.update_costing_file(bigint, text, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.update_costing_file(bigint, text, text, bigint) TO service_role;