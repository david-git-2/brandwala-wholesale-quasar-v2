-- Products list/detail: scope by parent_tenant_id via resolve_parent_tenant_id.
-- Fixes regression from 20260901 which filtered on products.tenant_id only.

begin;

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
  v_scope_tenant_id bigint;
  v_result jsonb;
begin
  if p_tenant_id is not null and not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_scope_tenant_id := case
    when p_tenant_id is null then null
    else public.resolve_parent_tenant_id(p_tenant_id)
  end;

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
    'list_price_amount',
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
          ($1 is null or p.parent_tenant_id = $1)
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
    v_scope_tenant_id,
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

create or replace function public.get_product_for_tenant(
  p_id bigint,
  p_tenant_id bigint
)
returns public.products
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_row public.products;
  v_scope_tenant_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_scope_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_row
  from public.products
  where id = p_id
    and parent_tenant_id = v_scope_tenant_id;

  return v_row;
end;
$$;

create or replace function public.list_product_brands_for_tenant(
  p_tenant_id bigint,
  p_vendor_code text default null,
  p_vendor_id bigint default null
)
returns setof public.product_brands
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_vendor_code text;
  v_scope_tenant_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_scope_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_vendor_code := nullif(upper(trim(coalesce(p_vendor_code, ''))), '');

  return query
  select pb.*
  from public.product_brands pb
  where pb.parent_tenant_id = v_scope_tenant_id
    and (v_vendor_code is null or pb.vendor_code = v_vendor_code)
    and (p_vendor_id is null or pb.vendor_id = p_vendor_id)
  order by pb.name asc;
end;
$$;

create or replace function public.list_product_categories_for_tenant(
  p_tenant_id bigint,
  p_vendor_code text default null,
  p_vendor_id bigint default null
)
returns setof public.product_categories
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_vendor_code text;
  v_scope_tenant_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_scope_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_vendor_code := nullif(upper(trim(coalesce(p_vendor_code, ''))), '');

  return query
  select pc.*
  from public.product_categories pc
  where pc.parent_tenant_id = v_scope_tenant_id
    and (v_vendor_code is null or pc.vendor_code = v_vendor_code)
    and (p_vendor_id is null or pc.vendor_id = p_vendor_id)
  order by pc.name asc;
end;
$$;

do $$
begin
  perform pg_notify('pgrst', 'reload schema');
exception
  when others then
    null;
end;
$$;

commit;
