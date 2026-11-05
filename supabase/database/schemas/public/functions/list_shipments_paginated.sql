CREATE FUNCTION public.list_shipments_paginated (
  p_tenant_id bigint,
  p_page      integer DEFAULT 1,
  p_page_size integer DEFAULT 20,
  p_search    text    DEFAULT NULL::text,
  p_status    text    DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.list_shipments_paginated(bigint, integer, integer, text, text) TO anon;

GRANT ALL ON FUNCTION public.list_shipments_paginated(bigint, integer, integer, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.list_shipments_paginated(bigint, integer, integer, text, text) TO service_role;