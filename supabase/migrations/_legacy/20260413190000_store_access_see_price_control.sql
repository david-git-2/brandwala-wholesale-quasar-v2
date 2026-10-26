-- =========================================================
-- Store access: see_price control for customer product visibility
-- =========================================================

alter table public.store_access
add column if not exists see_price boolean not null default false;

create or replace function public.can_customer_see_store_price(p_store_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.store_access sa
    join public.customer_group_members cgm
      on cgm.customer_group_id = sa.customer_group_id
    where sa.store_id = p_store_id
      and sa.status = true
      and sa.see_price = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
  )
$$;

grant execute on function public.can_customer_see_store_price(bigint)
to authenticated;

create or replace function public.create_store_access(
  p_store_id bigint,
  p_customer_group_id bigint,
  p_status boolean default true,
  p_see_price boolean default false
)
returns public.store_access
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.store_access;
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.stores
  where id = p_store_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  end if;

  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  insert into public.store_access (
    store_id,
    customer_group_id,
    status,
    see_price
  )
  values (
    p_store_id,
    p_customer_group_id,
    p_status,
    p_see_price
  )
  on conflict (store_id, customer_group_id)
  do update
  set
    status = excluded.status,
    see_price = excluded.see_price,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.create_store_access(bigint, bigint, boolean, boolean)
to authenticated;

create or replace function public.update_store_access_fields(
  p_id bigint,
  p_status boolean default null,
  p_see_price boolean default null
)
returns public.store_access
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.store_access;
  v_tenant_id bigint;
begin
  select s.tenant_id into v_tenant_id
  from public.store_access sa
  join public.stores s on s.id = sa.store_id
  where sa.id = p_id;

  if v_tenant_id is null then
    raise exception 'store access not found';
  end if;

  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  update public.store_access
  set
    status = coalesce(p_status, status),
    see_price = coalesce(p_see_price, see_price)
  where id = p_id
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.update_store_access_fields(bigint, boolean, boolean)
to authenticated;

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
  v_can_see_price boolean;
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

  v_can_see_price := v_has_internal_access or public.can_customer_see_store_price(p_store_id);

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

  if not v_can_see_price then
    select coalesce(array_agg(field_name), '{}'::text[])
    into v_selected_fields
    from unnest(v_selected_fields) as field_name
    where field_name <> 'price_gbp';
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
          (
            select jsonb_agg(
              (
                select jsonb_object_agg(field_name, to_jsonb(p) -> field_name)
                from unnest($6::text[]) as field_name
              )
            )
            from paged p
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
          'sort_dir', $11,
          'total', (select count(*) from filtered),
          'can_see_price', $12
        )
      )
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
    v_sort_dir,
    v_can_see_price;

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
        'sort_dir', v_sort_dir,
        'total', 0,
        'can_see_price', v_can_see_price
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
