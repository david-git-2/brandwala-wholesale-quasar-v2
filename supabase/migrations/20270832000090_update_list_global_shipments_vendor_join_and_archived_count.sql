-- Migration: 20270832000090_update_list_global_shipments_vendor_join_and_archived_count.sql
-- Description: Update list_global_shipments_paginated to join vendors table and embed vendor_name, vendor_code, and calculate archived_total count

CREATE OR REPLACE FUNCTION public.list_global_shipments_paginated(
  p_tenant_id bigint,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 20,
  p_search text DEFAULT NULL::text,
  p_status text DEFAULT NULL::text,
  p_is_archived boolean DEFAULT false
) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
declare
  v_total_count bigint;
  v_archived_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  -- Total count matching query filters
  select count(*)
  into v_total_count
  from public.global_shipments s
  where s.parent_tenant_id = p_tenant_id
    and (p_is_archived is null or s.is_archived = p_is_archived)
    and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
    and (
      p_search is null or p_search = '' or (
        s.name ilike '%' || p_search || '%'
        or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
      )
    );

  -- Count of all archived shipments for tenant (for toolbar badge)
  select count(*)
  into v_archived_count
  from public.global_shipments s
  where s.parent_tenant_id = p_tenant_id
    and s.is_archived = true;

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      s.id as sort_id,
      (
        to_jsonb(s)
        || jsonb_build_object(
          'vendor_name', v.name,
          'vendor_code', v.code,
          'progress_tag',
          case
            when t.id is null then null
            else jsonb_build_object(
              'id', t.id,
              'name', t.name,
              'slug', t.slug,
              'group_name', t.group_name,
              'sort_order', t.sort_order,
              'color', t.color
            )
          end
        )
      ) as row_json
    from public.global_shipments s
    left join public.vendors v
      on v.id = s.vendor_id
    left join public.tags t
      on t.id = s.progress_tag_id
     and t.group_name = 'shipment_progress'
    where s.parent_tenant_id = p_tenant_id
      and (p_is_archived is null or s.is_archived = p_is_archived)
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
  ) q;

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
      'total_pages', v_total_pages,
      'archived_total', v_archived_count
    )
  );
end;
$_$;

ALTER FUNCTION public.list_global_shipments_paginated(bigint, integer, integer, text, text, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.list_global_shipments_paginated(bigint, integer, integer, text, text, boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.list_global_shipments_paginated(bigint, integer, integer, text, text, boolean) TO authenticated;
