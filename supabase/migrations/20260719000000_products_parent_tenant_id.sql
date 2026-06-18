-- Products parent/child visibility: parent sees all child products; child sees own only.
-- Mirrors vendor / brand / category pattern from 20260710000000.
begin;

-- =========================================================
-- 1. parent_tenant_id on products
-- =========================================================

alter table public.products
  add column if not exists parent_tenant_id bigint null references public.tenants(id) on delete set null;

create index if not exists products_parent_tenant_id_idx on public.products (parent_tenant_id);

update public.products p
set parent_tenant_id = t.parent_id
from public.tenants t
where p.tenant_id = t.id
  and p.parent_tenant_id is null
  and t.parent_id is not null;

update public.products p
set parent_tenant_id = p.tenant_id
from public.tenants t
where p.tenant_id = t.id
  and p.parent_tenant_id is null
  and t.parent_id is null;

update public.products p
set
  tenant_id = coalesce(p.tenant_id, v.tenant_id),
  parent_tenant_id = coalesce(p.parent_tenant_id, v.parent_tenant_id)
from public.vendors v
where p.vendor_id = v.id
  and p.parent_tenant_id is null
  and v.parent_tenant_id is not null;

-- =========================================================
-- 2. Triggers
-- =========================================================

drop trigger if exists trg_products_set_parent_tenant_id on public.products;
create trigger trg_products_set_parent_tenant_id
before insert or update of tenant_id on public.products
for each row execute function public.set_parent_tenant_id_from_tenant();

create or replace function public.sync_product_tenant_from_vendor()
returns trigger
language plpgsql
as $$
declare
  v_tenant_id bigint;
  v_parent_tenant_id bigint;
begin
  if new.vendor_id is not null then
    select v.tenant_id, v.parent_tenant_id
    into v_tenant_id, v_parent_tenant_id
    from public.vendors v
    where v.id = new.vendor_id;

    if v_tenant_id is not null then
      new.tenant_id := v_tenant_id;
    end if;

    if v_parent_tenant_id is not null then
      new.parent_tenant_id := v_parent_tenant_id;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_products_sync_tenant_from_vendor on public.products;
create trigger trg_products_sync_tenant_from_vendor
before insert or update of vendor_id on public.products
for each row execute function public.sync_product_tenant_from_vendor();

-- =========================================================
-- 3. list_products_paginated — parent/child tenant scope
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
  if p_tenant_id is not null and not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

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
          (
            $1 is null
            or (
              public.is_child_tenant($1)
              and p.tenant_id = $1
            )
            or (
              not public.is_child_tenant($1)
              and p.parent_tenant_id = $1
            )
          )
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
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.is_child_tenant(p_tenant_id) then
    select * into v_row
    from public.products
    where id = p_id
      and tenant_id = p_tenant_id;
  else
    select * into v_row
    from public.products
    where id = p_id
      and parent_tenant_id = p_tenant_id;
  end if;

  return v_row;
end;
$$;

grant execute on function public.get_product_for_tenant(bigint, bigint) to authenticated;

-- =========================================================
-- 4. RLS — parent admins can read hierarchy rows
-- =========================================================

drop policy if exists "products_select" on public.products;
create policy "products_select"
on public.products
for select
to authenticated
using (
  public.can_view_products_internal(tenant_id)
  or public.can_view_products_customer(tenant_id)
  or (
    parent_tenant_id is not null
    and public.user_can_manage_parent_tenant(parent_tenant_id)
  )
);

drop policy if exists product_brands_read_authenticated on public.product_brands;
create policy product_brands_read_authenticated
on public.product_brands
for select
to authenticated
using (
  exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.tenant_id is not null
      and product_brands.tenant_id = m.tenant_id
  )
  or (
    parent_tenant_id is not null
    and public.user_can_manage_parent_tenant(parent_tenant_id)
  )
);

drop policy if exists product_categories_read_authenticated on public.product_categories;
create policy product_categories_read_authenticated
on public.product_categories
for select
to authenticated
using (
  exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.tenant_id is not null
      and product_categories.tenant_id = m.tenant_id
  )
  or (
    parent_tenant_id is not null
    and public.user_can_manage_parent_tenant(parent_tenant_id)
  )
);

commit;
