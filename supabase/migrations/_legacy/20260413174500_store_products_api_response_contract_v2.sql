-- =========================================================
-- Store module: list_store_products response contract v2
-- - Keep product rows in data[]
-- - Move paging/query details to meta
-- - Do not return total_count
-- =========================================================

drop function if exists public.list_store_products(
  bigint,
  text[],
  text,
  text,
  text,
  text,
  text,
  integer,
  integer
);

create or replace function public.list_store_products(
  p_store_id bigint,
  p_fields text[] default null,
  p_search text default null,
  p_category text default null,
  p_brand text default null,
  p_sort_by text default 'id',
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
  v_tenant_id bigint;
  v_vendor_code text;
  v_sort_by text;
  v_sort_dir text;
  v_limit integer;
  v_offset integer;
  v_has_internal_access boolean;
  v_has_customer_access boolean;
  v_allowed_fields text[] := array[
    'id',
    'tenant_id',
    'product_code',
    'barcode',
    'name',
    'price_gbp',
    'country_of_origin',
    'brand',
    'category',
    'available_units',
    'tariff_code',
    'languages',
    'batch_code_manufacture_date',
    'image_url',
    'expire_date',
    'minimum_order_quantity',
    'product_weight',
    'package_weight',
    'is_available',
    'created_at',
    'updated_at',
    'vendor_code',
    'market_code'
  ];
  v_selected_fields text[];
  v_result jsonb;
begin
  select s.tenant_id, s.vendor_code
  into v_tenant_id, v_vendor_code
  from public.stores s
  where s.id = p_store_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  end if;

  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.tenant_id = v_tenant_id
      and m.role in ('admin', 'staff')
  ) into v_has_internal_access;

  v_has_customer_access := public.can_customer_access_store(p_store_id);

  if not v_has_internal_access and not v_has_customer_access then
    raise exception 'not allowed';
  end if;

  v_sort_by := lower(trim(coalesce(p_sort_by, 'id')));
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
    v_sort_by := 'id';
  end if;

  v_sort_dir := lower(trim(coalesce(p_sort_dir, 'asc')));
  if v_sort_dir not in ('asc', 'desc') then
    v_sort_dir := 'asc';
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  select coalesce(array_agg(distinct field_name), '{}'::text[])
  into v_selected_fields
  from unnest(coalesce(p_fields, v_allowed_fields)) as field_name
  where field_name = any (v_allowed_fields);

  if coalesce(array_length(v_selected_fields, 1), 0) = 0 then
    v_selected_fields := array['id', 'name', 'vendor_code', 'brand', 'category'];
  end if;

  execute format(
    $sql$
      with filtered as (
        select p.*
        from public.products p
        where p.vendor_code = $1
          and p.tenant_id = $2
          and (
            $3 is null
            or trim($3) = ''
            or p.name ilike ('%%' || trim($3) || '%%')
            or p.product_code ilike ('%%' || trim($3) || '%%')
            or p.barcode ilike ('%%' || trim($3) || '%%')
          )
          and (
            $4 is null
            or trim($4) = ''
            or lower(coalesce(p.category, '')) = lower(trim($4))
          )
          and (
            $5 is null
            or trim($5) = ''
            or lower(coalesce(p.brand, '')) = lower(trim($5))
          )
      ),
      paged as (
        select f.*
        from filtered f
        order by %I %s nulls last, f.id asc
        limit $7
        offset $8
      )
      select jsonb_build_object(
        'data',
        coalesce(
          jsonb_agg(
            (
              select jsonb_object_agg(field_name, to_jsonb(paged) -> field_name)
              from unnest($6::text[]) as field_name
            )
          ),
          '[]'::jsonb
        ),
        'meta',
        jsonb_build_object(
          'store_id', $9,
          'limit', $7,
          'offset', $8,
          'current_page', (($8 / $7) + 1),
          'sort_by', $10,
          'sort_dir', $11
        )
      )
      from paged
    $sql$,
    v_sort_by,
    v_sort_dir
  )
  into v_result
  using
    v_vendor_code,
    v_tenant_id,
    p_search,
    p_category,
    p_brand,
    v_selected_fields,
    v_limit,
    v_offset,
    p_store_id,
    v_sort_by,
    v_sort_dir;

  return coalesce(
    v_result,
    jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'store_id', p_store_id,
        'limit', v_limit,
        'offset', v_offset,
        'current_page', ((v_offset / v_limit) + 1),
        'sort_by', v_sort_by,
        'sort_dir', v_sort_dir
      )
    )
  );
end;
$$;

grant execute on function public.list_store_products(
  bigint,
  text[],
  text,
  text,
  text,
  text,
  text,
  integer,
  integer
)
to authenticated;
