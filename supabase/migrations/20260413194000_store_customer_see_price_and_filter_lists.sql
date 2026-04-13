-- =========================================================
-- Store module:
-- 1) get_stores_for_customer includes see_price
-- 2) dedicated filter list APIs (brand/category)
-- =========================================================

drop function if exists public.get_stores_for_customer();

create or replace function public.get_stores_for_customer()
returns table(
  id bigint,
  name text,
  vendor_code text,
  tenant_id bigint,
  created_at timestamptz,
  updated_at timestamptz,
  see_price boolean
)
language sql
security definer
set search_path = public
stable
as $$
  select
    s.id,
    s.name,
    s.vendor_code,
    s.tenant_id,
    s.created_at,
    s.updated_at,
    bool_or(sa.see_price) as see_price
  from public.stores s
  join public.store_access sa
    on sa.store_id = s.id
  join public.customer_group_members cgm
    on cgm.customer_group_id = sa.customer_group_id
  where sa.status = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
  group by
    s.id,
    s.name,
    s.vendor_code,
    s.tenant_id,
    s.created_at,
    s.updated_at
  order by s.id asc
$$;

grant execute on function public.get_stores_for_customer()
to authenticated;

create or replace function public.get_store_product_brands(
  p_store_id bigint
)
returns table(
  brand text
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id bigint;
  v_vendor_code text;
  v_has_internal_access boolean;
  v_has_customer_access boolean;
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

  return query
  select distinct p.brand
  from public.products p
  where p.tenant_id = v_tenant_id
    and p.vendor_code = v_vendor_code
    and p.brand is not null
    and length(trim(p.brand)) > 0
  order by p.brand asc;
end;
$$;

grant execute on function public.get_store_product_brands(bigint)
to authenticated;

create or replace function public.get_store_product_categories(
  p_store_id bigint
)
returns table(
  category text
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id bigint;
  v_vendor_code text;
  v_has_internal_access boolean;
  v_has_customer_access boolean;
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

  return query
  select distinct p.category
  from public.products p
  where p.tenant_id = v_tenant_id
    and p.vendor_code = v_vendor_code
    and p.category is not null
    and length(trim(p.category)) > 0
  order by p.category asc;
end;
$$;

grant execute on function public.get_store_product_categories(bigint)
to authenticated;
