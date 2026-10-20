-- Cursor pagination for shipment list (replaces offset + total count).
DROP FUNCTION IF EXISTS public.list_global_shipments_paginated(bigint, integer, integer, text, text);
DROP FUNCTION IF EXISTS public.list_global_shipments_paginated(bigint, integer, integer, text, text, boolean);
DROP FUNCTION IF EXISTS public.list_global_shipments_paginated(bigint, integer, integer, text, text, boolean, bigint, bigint);
CREATE OR REPLACE FUNCTION public."list_global_shipments_paginated"(p_tenant_id bigint, p_page_size integer DEFAULT 20, p_cursor bigint DEFAULT NULL::bigint, p_search "text" DEFAULT NULL::"text", p_status "text" DEFAULT NULL::"text", p_is_archived boolean DEFAULT false, p_vendor_id bigint DEFAULT NULL::bigint, p_cargo_company_id bigint DEFAULT NULL::bigint) RETURNS jsonb
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_archived_count bigint;
  v_data jsonb;
  v_limit integer;
  v_fetched integer;
  v_has_more boolean := false;
  v_next_cursor bigint;
begin
  v_limit := greatest(coalesce(p_page_size, 20), 1);

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
      and (p_vendor_id is null or s.vendor_id = p_vendor_id)
      and (p_cargo_company_id is null or s.cargo_company_id = p_cargo_company_id)
      and (p_cursor is null or s.id < p_cursor)
    order by s.id desc
    limit v_limit + 1
  ) q;

  v_fetched := coalesce(jsonb_array_length(v_data), 0);
  if v_fetched > v_limit then
    v_has_more := true;
    v_data := coalesce(
      (
        select jsonb_agg(elem order by (elem->>'id')::bigint desc)
        from (
          select elem
          from jsonb_array_elements(v_data) as elem
          limit v_limit
        ) trimmed
      ),
      '[]'::jsonb
    );
  end if;

  if coalesce(jsonb_array_length(v_data), 0) > 0 then
    v_next_cursor := (v_data->(jsonb_array_length(v_data) - 1)->>'id')::bigint;
  else
    v_next_cursor := null;
  end if;

  if not v_has_more then
    v_next_cursor := null;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'page_size', v_limit,
      'next_cursor', v_next_cursor,
      'has_more', v_has_more,
      'archived_total', v_archived_count
    )
  );
end;
$_$;


ALTER FUNCTION public."list_global_shipments_paginated"(p_tenant_id bigint, p_page_size integer, p_cursor bigint, p_search "text", p_status "text", p_is_archived boolean, p_vendor_id bigint, p_cargo_company_id bigint) OWNER TO "postgres";

REVOKE ALL ON FUNCTION public.list_global_shipments_paginated(bigint, integer, bigint, text, text, boolean, bigint, bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.list_global_shipments_paginated(bigint, integer, bigint, text, text, boolean, bigint, bigint) TO authenticated;
