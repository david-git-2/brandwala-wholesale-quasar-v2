CREATE FUNCTION public.list_koba_retail_products (
  p_tenant_id   bigint,
  p_page        integer DEFAULT 1,
  p_page_size   integer DEFAULT 20,
  p_search      text    DEFAULT NULL::text,
  p_brand_id    bigint  DEFAULT NULL::bigint,
  p_category_id bigint  DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with filtered as (
    select
      kp.id,
      kp.name,
      kp.sku,
      kp.barcode,
      kp.description,
      kp.stock_quantity,
      kp.in_stock,
      kp.price                   as price_gbp,
      kp.regular_price,
      kp.sale_price,
      kp.commission_percentage,
      kp.commission,
      kp.image_url,
      kp.brand_id,
      kb.name                    as brand,
      kp.category_id,
      kc.name                    as category,
      kp.created_at,
      kp.updated_at,
      count(*) over()            as total_count
    from public.koba_products kp
    left join public.koba_brands     kb on kb.id = kp.brand_id
    left join public.koba_categories kc on kc.id = kp.category_id
    where
      kp.tenant_id  = p_tenant_id
      and kp.source_type = 'retail'
      and kp.in_stock    = true
      -- search across name, sku, barcode
      and (
        coalesce(trim(p_search), '') = ''
        or kp.name    ilike ('%' || trim(p_search) || '%')
        or kp.sku     ilike ('%' || trim(p_search) || '%')
        or kp.barcode ilike ('%' || trim(p_search) || '%')
      )
      -- brand filter
      and (p_brand_id    is null or kp.brand_id    = p_brand_id)
      -- category filter
      and (p_category_id is null or kp.category_id = p_category_id)
  ),
  paged as (
    select *
    from filtered
    order by name asc, id asc
    offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
    limit  greatest(coalesce(p_page_size, 20), 1)
  )
  select jsonb_build_object(
    'data',
    coalesce(jsonb_agg(to_jsonb(paged) - 'total_count'), '[]'::jsonb),
    'meta',
    jsonb_build_object(
      'total',       coalesce(max(paged.total_count), 0),
      'page',        greatest(coalesce(p_page, 1), 1),
      'page_size',   greatest(coalesce(p_page_size, 20), 1),
      'total_pages',
      case
        when coalesce(max(paged.total_count), 0) = 0 then 1
        else ceil(coalesce(max(paged.total_count), 0)::numeric
               / greatest(coalesce(p_page_size, 20), 1))::int
      end
    )
  )
  from paged;
$function$;

GRANT ALL ON FUNCTION public.list_koba_retail_products(bigint, integer, integer, text, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_koba_retail_products(bigint, integer, integer, text, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_koba_retail_products(bigint, integer, integer, text, bigint, bigint) TO service_role;