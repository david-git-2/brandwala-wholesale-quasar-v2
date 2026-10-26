-- Migration to add paginated jsonb shipments search and filtering function
drop function if exists public.list_shipments_paginated(bigint, integer, integer, text, text);

create or replace function public.list_shipments_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_status text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  -- 1. Get total count of matching shipments
  select count(*)
  into v_total_count
  from public.shipments s
  where s.tenant_id = p_tenant_id
    and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
    and (
      p_search is null or p_search = '' or (
        s.name ilike '%' || p_search || '%'
        or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
      )
    );

  -- 2. Get paginated records as a jsonb array
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select *
    from public.shipments s
    where s.tenant_id = p_tenant_id
      and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
      and (
        p_search is null or p_search = '' or (
          s.name ilike '%' || p_search || '%'
          or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
        )
      )
    order by s.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  -- 3. Calculate total pages
  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;

grant execute on function public.list_shipments_paginated(bigint, integer, integer, text, text) to authenticated;
grant execute on function public.list_shipments_paginated(bigint, integer, integer, text, text) to anon;
grant execute on function public.list_shipments_paginated(bigint, integer, integer, text, text) to service_role;
