-- B1: parent_id one-layer constraint, shipment_type, tenant helpers, global module seeds
begin;

-- =========================================================
-- 1. One-layer tenant hierarchy enforcement
-- =========================================================

create or replace function public.enforce_tenant_one_layer_hierarchy()
returns trigger
language plpgsql
as $$
declare
  v_parent_parent_id bigint;
begin
  if new.parent_id is not null then
    if new.parent_id = new.id then
      raise exception 'tenant cannot be its own parent';
    end if;

    select parent_id into v_parent_parent_id
    from public.tenants
    where id = new.parent_id;

    if v_parent_parent_id is not null then
      raise exception 'parent tenant must be a top-level company (one layer only)';
    end if;

    if exists (
      select 1
      from public.tenants c
      where c.parent_id = new.id
    ) then
      raise exception 'tenant with child companies cannot be assigned a parent';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_tenants_enforce_one_layer_hierarchy on public.tenants;
create trigger trg_tenants_enforce_one_layer_hierarchy
before insert or update of parent_id on public.tenants
for each row
execute function public.enforce_tenant_one_layer_hierarchy();

-- =========================================================
-- 2. Tenant hierarchy helper functions
-- =========================================================

create or replace function public.resolve_parent_tenant_id(p_tenant_id bigint)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select t.parent_id from public.tenants t where t.id = p_tenant_id),
    p_tenant_id
  );
$$;

create or replace function public.is_parent_company(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select t.parent_id is null from public.tenants t where t.id = p_tenant_id),
    false
  );
$$;

create or replace function public.is_child_tenant(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select t.parent_id is not null from public.tenants t where t.id = p_tenant_id),
    false
  );
$$;

create or replace function public.list_child_tenant_ids(p_parent_tenant_id bigint)
returns setof bigint
language sql
stable
security definer
set search_path = public
as $$
  select t.id
  from public.tenants t
  where t.parent_id = p_parent_tenant_id
  order by t.id;
$$;

create or replace function public.user_can_manage_parent_tenant(p_parent_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_parent_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  );
$$;

grant execute on function public.resolve_parent_tenant_id(bigint) to authenticated;
grant execute on function public.is_parent_company(bigint) to authenticated;
grant execute on function public.is_child_tenant(bigint) to authenticated;
grant execute on function public.list_child_tenant_ids(bigint) to authenticated;
grant execute on function public.user_can_manage_parent_tenant(bigint) to authenticated;

-- =========================================================
-- 3. shipment_type (replaces is_gbp over time)
-- =========================================================

alter table public.shipments
  add column if not exists shipment_type text;

update public.shipments
set shipment_type = case
  when coalesce(is_gbp, true) then 'international'
  else 'local'
end
where shipment_type is null;

alter table public.shipments
  alter column shipment_type set default 'international';

alter table public.shipments
  alter column shipment_type set not null;

alter table public.shipments
  drop constraint if exists shipments_shipment_type_check;

alter table public.shipments
  add constraint shipments_shipment_type_check
  check (shipment_type in ('local', 'international'));

create or replace function public.sync_shipment_type_and_is_gbp()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.shipment_type is null then
      new.shipment_type := case when coalesce(new.is_gbp, true) then 'international' else 'local' end;
    end if;
    new.is_gbp := new.shipment_type = 'international';
    return new;
  end if;

  if new.shipment_type is distinct from old.shipment_type then
    new.is_gbp := new.shipment_type = 'international';
  elsif new.is_gbp is distinct from old.is_gbp then
    new.shipment_type := case when coalesce(new.is_gbp, true) then 'international' else 'local' end;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_shipments_sync_shipment_type on public.shipments;
create trigger trg_shipments_sync_shipment_type
before insert or update of shipment_type, is_gbp on public.shipments
for each row
execute function public.sync_shipment_type_and_is_gbp();

-- Extend create_shipment with shipment_type overload
drop function if exists public.create_shipment(text, bigint, text);

create or replace function public.create_shipment(
  p_name text,
  p_tenant_id bigint,
  p_shipment_type text default 'international'
)
returns public.shipments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.shipments;
  v_type text;
begin
  if not public.can_manage_shipment(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_type := lower(trim(coalesce(p_shipment_type, 'international')));
  if v_type not in ('local', 'international') then
    raise exception 'invalid shipment_type: %', p_shipment_type;
  end if;

  insert into public.shipments (name, tenant_id, shipment_type, is_gbp)
  values (
    trim(p_name),
    p_tenant_id,
    v_type,
    v_type = 'international'
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.create_shipment(text, bigint, text) to authenticated;

-- Keep boolean overload for backward compatibility
create or replace function public.create_shipment(
  p_name text,
  p_tenant_id bigint,
  p_is_gbp boolean default true
)
returns public.shipments
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.create_shipment(
    p_name,
    p_tenant_id,
    case when coalesce(p_is_gbp, true) then 'international' else 'local' end
  );
end;
$$;

grant execute on function public.create_shipment(text, bigint, boolean) to authenticated;

-- update_shipment: accept shipment_type field
create or replace function public.update_shipment(
  p_id bigint,
  p_field text,
  p_value text
)
returns public.shipments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.shipments;
  v_field text;
  v_value text;
  v_type text;
begin
  select *
  into v_row
  from public.shipments
  where id = p_id;

  if v_row.id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_row.tenant_id) then
    raise exception 'not allowed';
  end if;

  v_field := lower(trim(coalesce(p_field, '')));
  v_value := trim(coalesce(p_value, ''));

  if v_field = 'name' then
    update public.shipments
    set name = v_value
    where id = p_id
    returning * into v_row;
  elsif v_field = 'is_gbp' then
    update public.shipments
    set is_gbp = coalesce(nullif(v_value, '')::boolean, true)
    where id = p_id
    returning * into v_row;
  elsif v_field = 'shipment_type' then
    v_type := lower(v_value);
    if v_type not in ('local', 'international') then
      raise exception 'invalid shipment_type: %', v_value;
    end if;
    update public.shipments
    set shipment_type = v_type
    where id = p_id
    returning * into v_row;
  elsif v_field = 'status' then
    update public.shipments
    set status = v_value
    where id = p_id
    returning * into v_row;
  elsif v_field = 'inventory_added' then
    update public.shipments
    set inventory_added = coalesce(nullif(v_value, '')::boolean, false)
    where id = p_id
    returning * into v_row;
  elsif v_field = 'product_conversion_rate' then
    update public.shipments
    set product_conversion_rate = nullif(v_value, '')::numeric
    where id = p_id
    returning * into v_row;
  elsif v_field = 'cargo_conversion_rate' then
    update public.shipments
    set cargo_conversion_rate = nullif(v_value, '')::numeric
    where id = p_id
    returning * into v_row;
  elsif v_field = 'cargo_rate' then
    update public.shipments
    set cargo_rate = nullif(v_value, '')::numeric
    where id = p_id
    returning * into v_row;
  elsif v_field = 'weight' then
    update public.shipments
    set weight = nullif(v_value, '')::numeric
    where id = p_id
    returning * into v_row;
  elsif v_field = 'received_weight' then
    update public.shipments
    set received_weight = nullif(v_value, '')::numeric
    where id = p_id
    returning * into v_row;
  elsif v_field = 'transaction_rate' then
    update public.shipments
    set transaction_rate = nullif(v_value, '')::numeric
    where id = p_id
    returning * into v_row;
  else
    raise exception 'unsupported shipment field: %', p_field;
  end if;

  return v_row;
end;
$$;

-- =========================================================
-- 4. Global module catalog seeds
-- =========================================================

insert into public.modules (key, name, description, is_active)
values
  (
    'global_stock',
    'Global Stock',
    'Parent-owned stock with child allocation bridge across sister concerns.',
    true
  ),
  (
    'global_invoice',
    'Global Invoice',
    'Unified invoice model for retail and wholesale; parent or child issuer.',
    true
  ),
  (
    'global_accounting_ledger',
    'Global Accounting Ledger',
    'Parent consolidated ledger across all sister concerns.',
    true
  ),
  (
    'global_shipment_accounting',
    'Global Shipment Accounting',
    'Shipment buy/sell cost and profit summary for parent company.',
    true
  ),
  (
    'global_invoice_accounting',
    'Global Invoice Accounting',
    'Invoice rollup including COD, packing, print and other charges.',
    true
  ),
  (
    'global_investor',
    'Global Investor',
    'Parent-managed investor profiles and balances.',
    true
  ),
  (
    'global_investor_shipment',
    'Global Investor Shipment',
    'Investor cost-share and profit allocation per shipment.',
    true
  ),
  (
    'investor_portal',
    'Investor Portal',
    'External investor login and portfolio summary.',
    true
  )
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

commit;
