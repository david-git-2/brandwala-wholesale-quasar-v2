-- Inbound shipment list workspace: paginated shipments + vendors + cargo in one RPC.
CREATE OR REPLACE FUNCTION public."list_inbound_shipments_workspace"(p_tenant_id bigint, p_page_size integer DEFAULT 20, p_cursor bigint DEFAULT NULL::bigint, p_search "text" DEFAULT NULL::"text", p_status "text" DEFAULT NULL::"text", p_is_archived boolean DEFAULT false, p_vendor_id bigint DEFAULT NULL::bigint, p_cargo_company_id bigint DEFAULT NULL::bigint, p_include_reference_data boolean DEFAULT true) RETURNS jsonb
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_books_id bigint;
  v_archived_count bigint;
  v_data jsonb;
  v_vendors jsonb := '[]'::jsonb;
  v_cargo jsonb := '[]'::jsonb;
  v_limit integer;
  v_fetched integer;
  v_has_more boolean := false;
  v_next_cursor bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_limit := greatest(coalesce(p_page_size, 20), 1);

  select count(*)
  into v_archived_count
  from public.global_shipments s
  where s.parent_tenant_id = v_books_id
    and s.is_archived = true;

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      s.id as sort_id,
      jsonb_build_object(
        'id', s.id,
        'name', s.name,
        'tenant_shipment_id', s.tenant_shipment_id,
        'vendor_id', s.vendor_id,
        'vendor_name', v.name,
        'vendor_code', v.code,
        'type', s.type,
        'status', s.status,
        'created_at', s.created_at,
        'cargo_company_id', s.cargo_company_id
      ) as row_json
    from public.global_shipments s
    left join public.vendors v on v.id = s.vendor_id
    where s.parent_tenant_id = v_books_id
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

  if coalesce(p_include_reference_data, true) then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', ven.id,
          'name', ven.name,
          'code', ven.code,
          'market_code', ven.market_code,
          'parent_tenant_id', ven.parent_tenant_id,
          'is_default', ven.is_default
        )
        order by ven.id asc
      ),
      '[]'::jsonb
    )
    into v_vendors
    from public.vendors ven
    where ven.parent_tenant_id = v_books_id;

    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', cc.id,
          'name', cc.name,
          'code', cc.code,
          'is_default', cc.is_default
        )
        order by cc.is_default desc, cc.name asc
      ),
      '[]'::jsonb
    )
    into v_cargo
    from public.cargo_companies cc
    where cc.parent_tenant_id = v_books_id
      and cc.is_active = true;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'page_size', v_limit,
      'next_cursor', v_next_cursor,
      'has_more', v_has_more,
      'archived_total', v_archived_count
    ),
    'vendors', v_vendors,
    'cargo_companies', v_cargo
  );
end;
$_$;


ALTER FUNCTION public."list_inbound_shipments_workspace"(p_tenant_id bigint, p_page_size integer, p_cursor bigint, p_search "text", p_status "text", p_is_archived boolean, p_vendor_id bigint, p_cargo_company_id bigint, p_include_reference_data boolean) OWNER TO "postgres";

REVOKE ALL ON FUNCTION public.list_inbound_shipments_workspace(bigint, integer, bigint, text, text, boolean, bigint, bigint, boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.list_inbound_shipments_workspace(bigint, integer, bigint, text, text, boolean, bigint, bigint, boolean) TO authenticated;
