CREATE FUNCTION public.update_costing_file_item_enrichment (
  p_id                 bigint,
  p_name               text    DEFAULT NULL::text,
  p_image_url          text    DEFAULT NULL::text,
  p_product_weight     integer DEFAULT NULL::integer,
  p_package_weight     integer DEFAULT NULL::integer,
  p_price_in_web_gbp   numeric DEFAULT NULL::numeric,
  p_delivery_price_gbp numeric DEFAULT NULL::numeric
)
  RETURNS TABLE (
    id                 bigint,
    costing_file_id    bigint,
    name               text,
    image_url          text,
    product_weight     integer,
    package_weight     integer,
    price_in_web_gbp   numeric,
    delivery_price_gbp numeric,
    updated_at         timestamp with time zone
  )
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with updated as (
    update public.costing_file_items cfi
    set
      name = coalesce(trim(p_name), cfi.name),
      image_url = coalesce(trim(p_image_url), cfi.image_url),
      product_weight = coalesce(p_product_weight, cfi.product_weight),
      package_weight = coalesce(p_package_weight, cfi.package_weight),
      price_in_web_gbp = coalesce(p_price_in_web_gbp, cfi.price_in_web_gbp),
      delivery_price_gbp = coalesce(p_delivery_price_gbp, cfi.delivery_price_gbp)
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
      )
    returning
      cfi.id,
      cfi.costing_file_id,
      cfi.name,
      cfi.image_url,
      cfi.product_weight,
      cfi.package_weight,
      cfi.price_in_web_gbp,
      cfi.delivery_price_gbp,
      cfi.updated_at
  )
  select *
  from updated;
$function$;

CREATE FUNCTION public.update_costing_file_item_enrichment (
  p_id                 bigint,
  p_name               text,
  p_item_type          text,
  p_image_url          text,
  p_product_weight     integer,
  p_package_weight     integer,
  p_price_in_web_gbp   numeric,
  p_delivery_price_gbp numeric
)
  RETURNS TABLE (
    id                   bigint,
    costing_file_id      bigint,
    name                 text,
    image_url            text,
    website_url          text,
    quantity             integer,
    product_weight       integer,
    package_weight       integer,
    price_in_web_gbp     numeric,
    delivery_price_gbp   numeric,
    auxiliary_price_gbp  numeric,
    item_price_gbp       numeric,
    cargo_rate           numeric,
    costing_price_gbp    numeric,
    costing_price_bdt    integer,
    offer_price_bdt      integer,
    customer_profit_rate numeric,
    status               public.costing_file_item_status,
    created_by_email     text,
    assigned_shipment_id bigint,
    created_at           timestamp with time zone,
    updated_at           timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return query
    with updated as (
      update public.costing_file_items cfi
      set
        name = coalesce(trim(p_name), cfi.name),
        item_type = coalesce(trim(p_item_type), cfi.item_type),
        image_url = coalesce(trim(p_image_url), cfi.image_url),
        product_weight = coalesce(p_product_weight, cfi.product_weight),
        package_weight = coalesce(p_package_weight, cfi.package_weight),
        price_in_web_gbp = coalesce(p_price_in_web_gbp, cfi.price_in_web_gbp),
        delivery_price_gbp = coalesce(p_delivery_price_gbp, cfi.delivery_price_gbp)
      where cfi.id = p_id
        and public.can_admin_manage_costing_file((select cf.tenant_id from public.costing_files cf where cf.id = cfi.costing_file_id))
      returning
        cfi.id,
        cfi.costing_file_id,
        cfi.name,
        cfi.image_url,
        cfi.website_url,
        cfi.quantity,
        cfi.product_weight,
        cfi.package_weight,
        cfi.price_in_web_gbp,
        cfi.delivery_price_gbp,
        cfi.auxiliary_price_gbp,
        cfi.item_price_gbp,
        cfi.cargo_rate,
        cfi.costing_price_gbp,
        cfi.costing_price_bdt,
        cfi.offer_price_bdt,
        cfi.customer_profit_rate,
        cfi.status,
        cfi.created_by_email,
        cfi.assigned_shipment_id,
        cfi.created_at,
        cfi.updated_at
    )
    select *
    from updated;
end;
$function$;

GRANT ALL ON FUNCTION public.update_costing_file_item_enrichment(bigint, text, text, integer, integer, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.update_costing_file_item_enrichment(bigint, text, text, integer, integer, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.update_costing_file_item_enrichment(bigint, text, text, integer, integer, numeric, numeric) TO service_role;

GRANT ALL ON FUNCTION public.update_costing_file_item_enrichment(bigint, text, text, text, integer, integer, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.update_costing_file_item_enrichment(bigint, text, text, text, integer, integer, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.update_costing_file_item_enrichment(bigint, text, text, text, integer, integer, numeric, numeric) TO service_role;