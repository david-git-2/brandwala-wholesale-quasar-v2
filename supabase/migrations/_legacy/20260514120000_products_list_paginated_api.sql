-- =========================================================
-- Products module: list_products_paginated returns data+meta
-- =========================================================

create or replace function public.list_products_paginated(
  p_tenant_id bigint default null,
  p_search text default null,
  p_search_field text default 'name',
  p_category text default null,
  p_brand text default null,
  p_vendor_code text default null,
  p_market_code text default null,
  p_is_available boolean default null,
  p_sort_by text default 'name',
  p_sort_dir text default 'asc',
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit integer;
  v_offset integer;
  v_sort_by text;
  v_sort_dir text;
  v_search_field text;
  v_result jsonb;
begin
  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  v_sort_by := lower(trim(coalesce(p_sort_by, 'name')));
  if not (v_sort_by = any (array[
    'id',
    'name',
    'product_code',
    'barcode',
    'brand',
    'category',
    'price_gbp',
    'available_units',
    'created_at',
    'updated_at'
  ])) then
    v_sort_by := 'name';
  end if;

  v_sort_dir := lower(trim(coalesce(p_sort_dir, 'asc')));
  if v_sort_dir not in ('asc', 'desc') then
    v_sort_dir := 'asc';
  end if;

  v_search_field := lower(trim(coalesce(p_search_field, 'name')));
  if v_search_field not in ('name', 'barcode', 'product_code', 'id') then
    v_search_field := 'name';
  end if;

  execute format(
    $sql$
      with filtered as (
        select p.*
        from public.products p
        where
          ($1 is null or p.tenant_id = $1)
          and ($2 is null or trim($2) = '' or (
            ($3 = 'name' and p.name ilike ('%%' || trim($2) || '%%'))
            or ($3 = 'barcode' and p.barcode ilike ('%%' || trim($2) || '%%'))
            or ($3 = 'product_code' and p.product_code ilike ('%%' || trim($2) || '%%'))
            or ($3 = 'id' and trim($2) ~ '^[0-9]+$' and p.id = trim($2)::bigint)
          ))
          and ($4 is null or trim($4) = '' or lower(coalesce(p.category, '')) = lower(trim($4)))
          and ($5 is null or trim($5) = '' or lower(coalesce(p.brand, '')) = lower(trim($5)))
          and ($6 is null or trim($6) = '' or upper(coalesce(p.vendor_code, '')) = upper(trim($6)))
          and ($7 is null or trim($7) = '' or upper(coalesce(p.market_code, '')) = upper(trim($7)))
          and ($8 is null or p.is_available = $8)
      ),
      paged as (
        select f.*
        from filtered f
        order by %I %s nulls last, f.id asc
        limit $9
        offset $10
      )
      select jsonb_build_object(
        'data',
        coalesce((select jsonb_agg(to_jsonb(p)) from paged p), '[]'::jsonb),
        'meta',
        jsonb_build_object(
          'total', (select count(*) from filtered),
          'page', (($10 / $9) + 1),
          'page_size', $9,
          'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $9::numeric))
        )
      )
    $sql$,
    v_sort_by,
    v_sort_dir
  )
  into v_result
  using
    p_tenant_id,
    p_search,
    v_search_field,
    p_category,
    p_brand,
    p_vendor_code,
    p_market_code,
    p_is_available,
    v_limit,
    v_offset;

  return coalesce(
    v_result,
    jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'total', 0,
        'page', ((v_offset / v_limit) + 1),
        'page_size', v_limit,
        'total_pages', 1
      )
    )
  );
end;
$$;

grant execute on function public.list_products_paginated(
  bigint,
  text,
  text,
  text,
  text,
  text,
  text,
  boolean,
  text,
  text,
  integer,
  integer
)
to authenticated;
