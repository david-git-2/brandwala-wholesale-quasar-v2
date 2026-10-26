-- Vendor / product brand / product category parent_tenant_id + tenant-scoped list RPCs
-- Child tenant: fetch by tenant_id. Parent company: fetch by parent_tenant_id.
begin;

-- =========================================================
-- 1. parent_tenant_id columns
-- =========================================================

alter table public.vendors
  add column if not exists parent_tenant_id bigint null references public.tenants(id) on delete set null;

alter table public.product_brands
  add column if not exists parent_tenant_id bigint null references public.tenants(id) on delete set null;

alter table public.product_categories
  add column if not exists parent_tenant_id bigint null references public.tenants(id) on delete set null;

create index if not exists vendors_parent_tenant_id_idx on public.vendors (parent_tenant_id);
create index if not exists product_brands_parent_tenant_id_idx on public.product_brands (parent_tenant_id);
create index if not exists product_categories_parent_tenant_id_idx on public.product_categories (parent_tenant_id);

-- =========================================================
-- 2. Backfill
-- =========================================================

update public.vendors v
set parent_tenant_id = t.parent_id
from public.tenants t
where v.tenant_id = t.id
  and v.parent_tenant_id is null
  and t.parent_id is not null;

update public.vendors v
set parent_tenant_id = v.tenant_id
from public.tenants t
where v.tenant_id = t.id
  and v.parent_tenant_id is null
  and t.parent_id is null;

update public.product_brands pb
set parent_tenant_id = v.parent_tenant_id
from public.vendors v
where pb.vendor_id = v.id
  and pb.parent_tenant_id is null
  and v.parent_tenant_id is not null;

update public.product_brands pb
set parent_tenant_id = coalesce(t.parent_id, pb.tenant_id)
from public.tenants t
where pb.tenant_id = t.id
  and pb.parent_tenant_id is null;

update public.product_categories pc
set parent_tenant_id = v.parent_tenant_id
from public.vendors v
where pc.vendor_id = v.id
  and pc.parent_tenant_id is null
  and v.parent_tenant_id is not null;

update public.product_categories pc
set parent_tenant_id = coalesce(t.parent_id, pc.tenant_id)
from public.tenants t
where pc.tenant_id = t.id
  and pc.parent_tenant_id is null;

-- =========================================================
-- 3. Triggers to maintain parent_tenant_id
-- =========================================================

create or replace function public.set_parent_tenant_id_from_tenant()
returns trigger
language plpgsql
as $$
declare
  v_parent_id bigint;
begin
  if new.tenant_id is not null then
    select parent_id into v_parent_id
    from public.tenants
    where id = new.tenant_id;

    new.parent_tenant_id := coalesce(v_parent_id, new.tenant_id);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_vendors_set_parent_tenant_id on public.vendors;
create trigger trg_vendors_set_parent_tenant_id
before insert or update of tenant_id on public.vendors
for each row execute function public.set_parent_tenant_id_from_tenant();

drop trigger if exists trg_product_brands_set_parent_tenant_id on public.product_brands;
create trigger trg_product_brands_set_parent_tenant_id
before insert or update of tenant_id on public.product_brands
for each row execute function public.set_parent_tenant_id_from_tenant();

drop trigger if exists trg_product_categories_set_parent_tenant_id on public.product_categories;
create trigger trg_product_categories_set_parent_tenant_id
before insert or update of tenant_id on public.product_categories
for each row execute function public.set_parent_tenant_id_from_tenant();

create or replace function public.sync_lookup_tenant_id()
returns trigger
language plpgsql
as $$
declare
  v_tenant_id bigint;
  v_parent_tenant_id bigint;
begin
  if new.vendor_id is not null then
    select tenant_id, parent_tenant_id
    into v_tenant_id, v_parent_tenant_id
    from public.vendors
    where id = new.vendor_id;

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

-- =========================================================
-- 4. Fetch access helper
-- =========================================================

create or replace function public.user_can_access_tenant_fetch(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_superadmin()
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    );
$$;

grant execute on function public.user_can_access_tenant_fetch(bigint) to authenticated;

-- =========================================================
-- 5. List / get RPCs
-- =========================================================

create or replace function public.list_vendors_for_tenant(p_tenant_id bigint)
returns setof public.vendors
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;

    return query
    select v.*
    from public.vendors v
    where v.tenant_id is null
    order by v.id asc;

    return;
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.is_child_tenant(p_tenant_id) then
    return query
    select v.*
    from public.vendors v
    where v.tenant_id = p_tenant_id
    order by v.id asc;
  else
    return query
    select v.*
    from public.vendors v
    where v.parent_tenant_id = p_tenant_id
    order by v.id asc;
  end if;
end;
$$;

create or replace function public.get_vendor_for_tenant(
  p_id bigint,
  p_tenant_id bigint
)
returns public.vendors
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_row public.vendors;
begin
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;

    select * into v_row
    from public.vendors
    where id = p_id
      and tenant_id is null;

    return v_row;
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.is_child_tenant(p_tenant_id) then
    select * into v_row
    from public.vendors
    where id = p_id
      and tenant_id = p_tenant_id;
  else
    select * into v_row
    from public.vendors
    where id = p_id
      and parent_tenant_id = p_tenant_id;
  end if;

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
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_vendor_code := nullif(upper(trim(coalesce(p_vendor_code, ''))), '');

  if public.is_child_tenant(p_tenant_id) then
    return query
    select pb.*
    from public.product_brands pb
    where pb.tenant_id = p_tenant_id
      and (v_vendor_code is null or pb.vendor_code = v_vendor_code)
      and (p_vendor_id is null or pb.vendor_id = p_vendor_id)
    order by pb.name asc;
  else
    return query
    select pb.*
    from public.product_brands pb
    where pb.parent_tenant_id = p_tenant_id
      and (v_vendor_code is null or pb.vendor_code = v_vendor_code)
      and (p_vendor_id is null or pb.vendor_id = p_vendor_id)
    order by pb.name asc;
  end if;
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
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_vendor_code := nullif(upper(trim(coalesce(p_vendor_code, ''))), '');

  if public.is_child_tenant(p_tenant_id) then
    return query
    select pc.*
    from public.product_categories pc
    where pc.tenant_id = p_tenant_id
      and (v_vendor_code is null or pc.vendor_code = v_vendor_code)
      and (p_vendor_id is null or pc.vendor_id = p_vendor_id)
    order by pc.name asc;
  else
    return query
    select pc.*
    from public.product_categories pc
    where pc.parent_tenant_id = p_tenant_id
      and (v_vendor_code is null or pc.vendor_code = v_vendor_code)
      and (p_vendor_id is null or pc.vendor_id = p_vendor_id)
    order by pc.name asc;
  end if;
end;
$$;

grant execute on function public.list_vendors_for_tenant(bigint) to authenticated;
grant execute on function public.get_vendor_for_tenant(bigint, bigint) to authenticated;
grant execute on function public.list_product_brands_for_tenant(bigint, text, bigint) to authenticated;
grant execute on function public.list_product_categories_for_tenant(bigint, text, bigint) to authenticated;

-- =========================================================
-- 6. Parent admins can read vendors across the hierarchy
-- =========================================================

drop policy if exists "vendors_select" on public.vendors;

create policy "vendors_select"
on public.vendors
for select
to authenticated
using (
  (
    public.is_superadmin()
    and tenant_id is null
  )
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
      and m.is_active = true
      and m.tenant_id is not null
      and vendors.tenant_id = m.tenant_id
  )
  or (
    parent_tenant_id is not null
    and public.user_can_manage_parent_tenant(parent_tenant_id)
  )
);

commit;
