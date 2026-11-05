CREATE FUNCTION public.list_koba_orders (
  p_tenant_id         bigint,
  p_customer_group_id bigint  DEFAULT NULL::bigint,
  p_page              integer DEFAULT 1,
  p_page_size         integer DEFAULT 20,
  p_status            text    DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with filtered as (
    select
      o.*,
      count(*) over() as total_count
    from public.koba_orders o
    where o.tenant_id = p_tenant_id
      and public.koba_context_access_allowed(p_tenant_id, o.customer_group_id)
      and (
        p_customer_group_id is null
        or o.customer_group_id = p_customer_group_id
      )
      and (
        p_status is null
        or o.status::text = p_status
      )
  ),
  paged as (
    select *
    from filtered
    order by created_at desc, id desc
    offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
    limit greatest(coalesce(p_page_size, 20), 1)
  )
  select jsonb_build_object(
    'data',
    coalesce(jsonb_agg(to_jsonb(paged) - 'total_count'), '[]'::jsonb),
    'meta',
    jsonb_build_object(
      'total', coalesce(max(paged.total_count), 0),
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', greatest(coalesce(p_page_size, 20), 1),
      'total_pages',
        case
          when coalesce(max(paged.total_count), 0) = 0 then 1
          else ceil(
            coalesce(max(paged.total_count), 0)::numeric
            / greatest(coalesce(p_page_size, 20), 1)
          )::int
        end
    )
  )
  from paged;
$function$;

GRANT ALL ON FUNCTION public.list_koba_orders(bigint, bigint, integer, integer, text) TO anon;

GRANT ALL ON FUNCTION public.list_koba_orders(bigint, bigint, integer, integer, text) TO authenticated;

GRANT ALL ON FUNCTION public.list_koba_orders(bigint, bigint, integer, integer, text) TO service_role;