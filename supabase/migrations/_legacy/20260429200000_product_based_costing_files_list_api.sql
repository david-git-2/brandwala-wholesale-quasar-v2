drop function if exists public.list_product_based_costing_files(integer, integer, text, text, bigint);

create function public.list_product_based_costing_files(
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_status text default null,
  p_tenant_id bigint default null
)
returns jsonb
language sql
security invoker
set search_path = public
stable
as $$
  with filtered as (
    select
      f.*,
      count(*) over() as total_count
    from public.product_based_costing_files f
    where
      (p_tenant_id is null or f.tenant_id = p_tenant_id)
      and (
        coalesce(trim(p_search), '') = ''
        or coalesce(f.name, '') ilike ('%' || trim(p_search) || '%')
        or coalesce(f.order_for, '') ilike ('%' || trim(p_search) || '%')
        or coalesce(f.note, '') ilike ('%' || trim(p_search) || '%')
      )
      and (
        coalesce(trim(p_status), '') = ''
        or f.status = trim(p_status)
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
        else ceil(coalesce(max(paged.total_count), 0)::numeric / greatest(coalesce(p_page_size, 20), 1))::int
      end
    )
  )
  from paged;
$$;

grant execute on function public.list_product_based_costing_files(integer, integer, text, text, bigint)
to authenticated;
