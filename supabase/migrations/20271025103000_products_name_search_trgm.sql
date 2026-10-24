-- Product name search: pg_trgm GIN indexes + ILIKE token match (replaces per-row regex).
-- pg_trgm already enabled via supabase/schemas/_extensions.sql on fresh DBs.

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;

CREATE INDEX IF NOT EXISTS products_name_trgm_idx
  ON public.products USING gin (name public.gin_trgm_ops);

CREATE INDEX IF NOT EXISTS products_brand_trgm_idx
  ON public.products USING gin (brand public.gin_trgm_ops);

CREATE OR REPLACE FUNCTION public.list_products_paginated(
  p_tenant_id bigint DEFAULT NULL::bigint,
  p_search text DEFAULT NULL::text,
  p_search_field text DEFAULT 'name'::text,
  p_category text DEFAULT NULL::text,
  p_brand text DEFAULT NULL::text,
  p_vendor_code text DEFAULT NULL::text,
  p_market_code text DEFAULT NULL::text,
  p_is_available boolean DEFAULT NULL::boolean,
  p_sort_dir text DEFAULT 'asc'::text,
  p_limit integer DEFAULT 20,
  p_cursor_name text DEFAULT NULL::text,
  p_cursor_id bigint DEFAULT NULL::bigint
) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
declare
  v_limit integer;
  v_sort_dir text;
  v_search_field text;
  v_scope_tenant_id bigint;
  v_rows jsonb;
  v_n integer;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_last_name text;
  v_last_id bigint;
  v_tokens text[] := '{}'::text[];
  v_cursor_name text;
begin
  if p_tenant_id is not null and not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_scope_tenant_id := case
    when p_tenant_id is null then null
    else public.resolve_parent_tenant_id(p_tenant_id)
  end;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));

  v_sort_dir := lower(trim(coalesce(p_sort_dir, 'asc')));
  if v_sort_dir not in ('asc', 'desc') then
    v_sort_dir := 'asc';
  end if;

  v_search_field := lower(trim(coalesce(p_search_field, 'name')));
  if v_search_field not in ('name', 'barcode', 'product_code', 'id') then
    v_search_field := 'name';
  end if;

  if v_search_field = 'name' and p_search is not null and trim(p_search) <> '' then
    select coalesce(array_agg(tok), '{}'::text[])
    into v_tokens
    from unnest(regexp_split_to_array(trim(p_search), E'[^[:alnum:]]+')) as tok
    where tok <> ''
      and length(tok) >= 2
      and lower(tok) not in ('a', 'an', 'the', 'and', 'or', 'of', 'for', 'to', 'in', 'on');

    if cardinality(v_tokens) = 0 then
      v_tokens := array[trim(p_search)];
    end if;
  end if;

  v_cursor_name := coalesce(p_cursor_name, '');

  if v_sort_dir = 'asc' then
    select coalesce(jsonb_agg(to_jsonb(q) ORDER BY q._sort_name ASC, q.id ASC), '[]'::jsonb)
    into v_rows
    from (
      select
        p.*,
        coalesce(p.name, '') as _sort_name
      from public.products p
      where
        (v_scope_tenant_id is null or p.parent_tenant_id = v_scope_tenant_id)
        and (p_search is null or trim(p_search) = '' or (
          (v_search_field = 'name' and (
            cardinality(v_tokens) = 0
            or (
              select coalesce(bool_and(
                coalesce(p.name, '') ilike ('%' || t || '%')
                or coalesce(p.brand, '') ilike ('%' || t || '%')
              ), true)
              from unnest(v_tokens) t
            )
          ))
          or (v_search_field = 'barcode' and p.barcode ilike ('%' || trim(p_search) || '%'))
          or (v_search_field = 'product_code' and p.product_code ilike ('%' || trim(p_search) || '%'))
          or (v_search_field = 'id' and trim(p_search) ~ '^[0-9]+$' and p.id = trim(p_search)::bigint)
        ))
        and (p_category is null or trim(p_category) = '' or lower(coalesce(p.category, '')) = lower(trim(p_category)))
        and (p_brand is null or trim(p_brand) = '' or lower(coalesce(p.brand, '')) = lower(trim(p_brand)))
        and (p_vendor_code is null or trim(p_vendor_code) = '' or upper(coalesce(p.vendor_code, '')) = upper(trim(p_vendor_code)))
        and (p_market_code is null or trim(p_market_code) = '' or upper(coalesce(p.market_code, '')) = upper(trim(p_market_code)))
        and (p_is_available is null or p.is_available = p_is_available)
        and (
          p_cursor_id is null
          or (coalesce(p.name, ''), p.id) > (v_cursor_name, p_cursor_id)
        )
      order by coalesce(p.name, '') asc, p.id asc
      limit v_limit + 1
    ) q;
  else
    select coalesce(jsonb_agg(to_jsonb(q) ORDER BY q._sort_name DESC, q.id DESC), '[]'::jsonb)
    into v_rows
    from (
      select
        p.*,
        coalesce(p.name, '') as _sort_name
      from public.products p
      where
        (v_scope_tenant_id is null or p.parent_tenant_id = v_scope_tenant_id)
        and (p_search is null or trim(p_search) = '' or (
          (v_search_field = 'name' and (
            cardinality(v_tokens) = 0
            or (
              select coalesce(bool_and(
                coalesce(p.name, '') ilike ('%' || t || '%')
                or coalesce(p.brand, '') ilike ('%' || t || '%')
              ), true)
              from unnest(v_tokens) t
            )
          ))
          or (v_search_field = 'barcode' and p.barcode ilike ('%' || trim(p_search) || '%'))
          or (v_search_field = 'product_code' and p.product_code ilike ('%' || trim(p_search) || '%'))
          or (v_search_field = 'id' and trim(p_search) ~ '^[0-9]+$' and p.id = trim(p_search)::bigint)
        ))
        and (p_category is null or trim(p_category) = '' or lower(coalesce(p.category, '')) = lower(trim(p_category)))
        and (p_brand is null or trim(p_brand) = '' or lower(coalesce(p.brand, '')) = lower(trim(p_brand)))
        and (p_vendor_code is null or trim(p_vendor_code) = '' or upper(coalesce(p.vendor_code, '')) = upper(trim(p_vendor_code)))
        and (p_market_code is null or trim(p_market_code) = '' or upper(coalesce(p.market_code, '')) = upper(trim(p_market_code)))
        and (p_is_available is null or p.is_available = p_is_available)
        and (
          p_cursor_id is null
          or (coalesce(p.name, ''), p.id) < (v_cursor_name, p_cursor_id)
        )
      order by coalesce(p.name, '') desc, p.id desc
      limit v_limit + 1
    ) q;
  end if;

  v_n := jsonb_array_length(v_rows);
  if v_n > v_limit then
    v_has_more := true;
    select elem->>'name', (elem->>'id')::bigint
    into v_last_name, v_last_id
    from jsonb_array_elements(v_rows) with ordinality as t(elem, ord)
    where ord = v_limit;

    v_next_cursor := jsonb_build_object(
      'name', coalesce(v_last_name, ''),
      'id', v_last_id
    );

    select coalesce(jsonb_agg(elem - '_sort_name' order by ord), '[]'::jsonb)
    into v_rows
    from (
      select (elem - '_sort_name') as elem, ord
      from jsonb_array_elements(v_rows) with ordinality as t(elem, ord)
      where ord <= v_limit
    ) trimmed;
  else
    select coalesce(jsonb_agg(elem - '_sort_name' order by ord), '[]'::jsonb)
    into v_rows
    from (
      select (elem - '_sort_name') as elem, ord
      from jsonb_array_elements(v_rows) with ordinality as t(elem, ord)
    ) trimmed;
  end if;

  return jsonb_build_object(
    'data', coalesce(v_rows, '[]'::jsonb),
    'meta', jsonb_build_object(
      'has_more', v_has_more,
      'next_cursor', v_next_cursor,
      'limit', v_limit
    )
  );
end;
$_$;
