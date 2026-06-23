begin;

-- =========================================================
-- Global Reference Data: module hierarchy, catalogs, RPCs
-- =========================================================

-- ---------------------------------------------------------
-- 1. Module parent/child catalog
-- ---------------------------------------------------------

alter table public.modules
  add column if not exists parent_module_key text null;

alter table public.modules
  drop constraint if exists modules_parent_module_key_fkey;

alter table public.modules
  add constraint modules_parent_module_key_fkey
  foreign key (parent_module_key) references public.modules(key) on delete set null;

create index if not exists modules_parent_module_key_idx
  on public.modules(parent_module_key);

-- ---------------------------------------------------------
-- 2. Tenant submodule overrides
-- ---------------------------------------------------------

create table if not exists public.tenant_module_submodules (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  parent_module_key text not null references public.modules(key) on delete cascade,
  submodule_key text not null references public.modules(key) on delete cascade,
  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, submodule_key)
);

create index if not exists tenant_module_submodules_tenant_parent_idx
  on public.tenant_module_submodules(tenant_id, parent_module_key);

create trigger trg_tenant_module_submodules_updated_at
before update on public.tenant_module_submodules
for each row execute function public.set_updated_at();

alter table public.tenant_module_submodules enable row level security;

create policy tenant_module_submodules_superadmin_all
on public.tenant_module_submodules
for all
to authenticated
using (public.is_superadmin())
with check (public.is_superadmin());

grant select, insert, update, delete
on table public.tenant_module_submodules
to authenticated;

grant usage, select
on sequence public.tenant_module_submodules_id_seq
to authenticated;

-- ---------------------------------------------------------
-- 3. Seed global_reference module family
-- ---------------------------------------------------------

insert into public.modules (key, name, description, is_active, parent_module_key)
values
  (
    'global_reference',
    'Global Reference Data',
    'Platform-wide reference catalogs: currencies, markets, payment methods, and units of measure.',
    true,
    null
  )
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

insert into public.modules (key, name, description, is_active, parent_module_key)
values
  (
    'global_reference_currency',
    'Currencies',
    'Global currency catalog for shipments, pricing, and money display.',
    true,
    'global_reference'
  ),
  (
    'global_reference_market',
    'Markets',
    'ISO-style market/country catalog for products, vendors, and shipments.',
    true,
    'global_reference'
  ),
  (
    'global_reference_payment_method',
    'Payment Methods',
    'Bangladesh and international payment method reference catalog.',
    true,
    'global_reference'
  ),
  (
    'global_reference_unit_of_measure',
    'Units of Measure',
    'Weight, count, length, volume, and packaging unit reference catalog.',
    true,
    'global_reference'
  )
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

-- Migrate thrift_currency tenant assignments → global_reference parent
insert into public.tenant_modules (tenant_id, module_key, is_active)
select distinct tm.tenant_id, 'global_reference', true
from public.tenant_modules tm
where tm.module_key = 'thrift_currency'
  and tm.is_active = true
  and not exists (
    select 1
    from public.tenant_modules existing
    where existing.tenant_id = tm.tenant_id
      and existing.module_key = 'global_reference'
  );

delete from public.tenant_modules
where module_key = 'thrift_currency';

update public.modules
set is_active = false
where key = 'thrift_currency';

-- ---------------------------------------------------------
-- 4. payment_methods catalog
-- ---------------------------------------------------------

create table if not exists public.payment_methods (
  id bigserial primary key,
  code text not null unique,
  name text not null,
  category text not null,
  scope text not null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payment_methods_code_uppercase_check check (code = upper(code)),
  constraint payment_methods_category_check check (
    category in ('bd_mobile_wallet', 'bd_bank', 'bd_cash', 'card', 'international')
  ),
  constraint payment_methods_scope_check check (
    scope in ('bd', 'international', 'both')
  )
);

create index if not exists payment_methods_category_idx on public.payment_methods(category);
create index if not exists payment_methods_scope_idx on public.payment_methods(scope);

create trigger trg_payment_methods_updated_at
before update on public.payment_methods
for each row execute function public.set_updated_at();

create or replace function public.prevent_system_payment_method_mutation()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System payment methods cannot be deleted.';
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' and old.is_system and (
    row(new.code, new.name, new.category, new.scope, new.sort_order, new.is_active, new.is_system)
    is distinct from
    row(old.code, old.name, old.category, old.scope, old.sort_order, old.is_active, old.is_system)
  ) then
    raise exception 'System payment methods cannot be edited.';
  end if;

  return new;
end;
$$;

create trigger trg_payment_methods_protect_system_rows
before update or delete on public.payment_methods
for each row execute function public.prevent_system_payment_method_mutation();

alter table public.payment_methods enable row level security;

create policy superadmin_can_manage_payment_methods
on public.payment_methods
for all
to authenticated
using (public.is_superadmin())
with check (public.is_superadmin());

grant select, insert, update, delete on table public.payment_methods to authenticated;
grant usage, select on sequence public.payment_methods_id_seq to authenticated;

insert into public.payment_methods (code, name, category, scope, sort_order, is_active, is_system)
values
  ('BKASH', 'bKash', 'bd_mobile_wallet', 'bd', 10, true, true),
  ('NAGAD', 'Nagad', 'bd_mobile_wallet', 'bd', 20, true, true),
  ('ROCKET', 'Rocket (DBBL)', 'bd_mobile_wallet', 'bd', 30, true, true),
  ('UPAY', 'Upay', 'bd_mobile_wallet', 'bd', 40, true, true),
  ('TAP', 'Tap', 'bd_mobile_wallet', 'bd', 50, true, true),
  ('BANK_TRANSFER', 'Bank Transfer', 'bd_bank', 'bd', 60, true, true),
  ('CASH', 'Cash', 'bd_cash', 'both', 70, true, true),
  ('CHEQUE', 'Cheque', 'bd_bank', 'bd', 80, true, true),
  ('CARD_POS', 'Card / POS', 'card', 'both', 90, true, true),
  ('WIRE_TRANSFER', 'Wire Transfer / SWIFT', 'international', 'international', 100, true, true),
  ('PAYPAL', 'PayPal', 'international', 'international', 110, true, true),
  ('STRIPE', 'Stripe', 'international', 'international', 120, true, true),
  ('LETTER_OF_CREDIT', 'Letter of Credit', 'international', 'international', 130, true, true),
  ('COD', 'Cash on Delivery', 'international', 'international', 140, true, true)
on conflict (code) do update
set
  name = excluded.name,
  category = excluded.category,
  scope = excluded.scope,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  is_system = excluded.is_system;

create or replace function public.list_payment_methods()
returns table(
  code text,
  name text,
  category text,
  scope text,
  sort_order int
)
language sql
security definer
set search_path = public
stable
as $$
  select pm.code, pm.name, pm.category, pm.scope, pm.sort_order
  from public.payment_methods pm
  where pm.is_active = true
  order by pm.sort_order asc, pm.name asc;
$$;

grant execute on function public.list_payment_methods() to authenticated;

-- ---------------------------------------------------------
-- 5. units_of_measure catalog
-- ---------------------------------------------------------

create table if not exists public.units_of_measure (
  id bigserial primary key,
  code text not null unique,
  name text not null,
  unit_type text not null,
  symbol text null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint units_of_measure_code_uppercase_check check (code = upper(code)),
  constraint units_of_measure_unit_type_check check (
    unit_type in ('weight', 'count', 'length', 'volume', 'packaging')
  )
);

create index if not exists units_of_measure_unit_type_idx on public.units_of_measure(unit_type);

create trigger trg_units_of_measure_updated_at
before update on public.units_of_measure
for each row execute function public.set_updated_at();

create or replace function public.prevent_system_unit_of_measure_mutation()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System units of measure cannot be deleted.';
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' and old.is_system and (
    row(new.code, new.name, new.unit_type, new.symbol, new.sort_order, new.is_active, new.is_system)
    is distinct from
    row(old.code, old.name, old.unit_type, old.symbol, old.sort_order, old.is_active, old.is_system)
  ) then
    raise exception 'System units of measure cannot be edited.';
  end if;

  return new;
end;
$$;

create trigger trg_units_of_measure_protect_system_rows
before update or delete on public.units_of_measure
for each row execute function public.prevent_system_unit_of_measure_mutation();

alter table public.units_of_measure enable row level security;

create policy superadmin_can_manage_units_of_measure
on public.units_of_measure
for all
to authenticated
using (public.is_superadmin())
with check (public.is_superadmin());

grant select, insert, update, delete on table public.units_of_measure to authenticated;
grant usage, select on sequence public.units_of_measure_id_seq to authenticated;

insert into public.units_of_measure (code, name, unit_type, symbol, sort_order, is_active, is_system)
values
  ('G', 'Gram', 'weight', 'g', 10, true, true),
  ('KG', 'Kilogram', 'weight', 'kg', 20, true, true),
  ('LB', 'Pound', 'weight', 'lb', 30, true, true),
  ('OZ', 'Ounce', 'weight', 'oz', 40, true, true),
  ('PCS', 'Piece', 'count', 'pcs', 50, true, true),
  ('PAIR', 'Pair', 'count', 'pair', 60, true, true),
  ('SET', 'Set', 'count', 'set', 70, true, true),
  ('DOZEN', 'Dozen', 'count', 'dozen', 80, true, true),
  ('M', 'Meter', 'length', 'm', 90, true, true),
  ('CM', 'Centimeter', 'length', 'cm', 100, true, true),
  ('L', 'Litre', 'volume', 'l', 110, true, true),
  ('ML', 'Millilitre', 'volume', 'ml', 120, true, true),
  ('BOX', 'Box', 'packaging', 'box', 130, true, true),
  ('CARTON', 'Carton', 'packaging', 'carton', 140, true, true),
  ('BUNDLE', 'Bundle', 'packaging', 'bundle', 150, true, true)
on conflict (code) do update
set
  name = excluded.name,
  unit_type = excluded.unit_type,
  symbol = excluded.symbol,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  is_system = excluded.is_system;

create or replace function public.list_units_of_measure()
returns table(
  code text,
  name text,
  unit_type text,
  symbol text,
  sort_order int
)
language sql
security definer
set search_path = public
stable
as $$
  select u.code, u.name, u.unit_type, u.symbol, u.sort_order
  from public.units_of_measure u
  where u.is_active = true
  order by u.sort_order asc, u.name asc;
$$;

grant execute on function public.list_units_of_measure() to authenticated;

-- ---------------------------------------------------------
-- 6. global_currencies: platform write + is_system
-- ---------------------------------------------------------

alter table public.global_currencies
  add column if not exists is_system boolean not null default false;

update public.global_currencies
set is_system = true
where code in ('GBP', 'BDT');

create or replace function public.prevent_system_global_currency_mutation()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System currencies cannot be deleted.';
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' and old.is_system and (
    row(new.name, new.country, new.code, new.symbol, new.is_active, new.is_system)
    is distinct from
    row(old.name, old.country, old.code, old.symbol, old.is_active, old.is_system)
  ) then
    raise exception 'System currencies cannot be edited.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_global_currencies_protect_system_rows on public.global_currencies;

create trigger trg_global_currencies_protect_system_rows
before update or delete on public.global_currencies
for each row execute function public.prevent_system_global_currency_mutation();

drop policy if exists manage_global_currencies on public.global_currencies;

create policy manage_global_currencies
on public.global_currencies
for all
to authenticated
using (public.is_superadmin())
with check (public.is_superadmin());

grant insert, update, delete on table public.global_currencies to authenticated;

create or replace function public.list_global_currencies()
returns table(
  id bigint,
  name text,
  country text,
  code text,
  symbol text
)
language sql
security definer
set search_path = public
stable
as $$
  select gc.id, gc.name, gc.country, gc.code, gc.symbol
  from public.global_currencies gc
  where gc.is_active = true
  order by gc.code asc;
$$;

grant execute on function public.list_global_currencies() to authenticated;

-- ---------------------------------------------------------
-- 7. Active module keys with parent/child expansion
-- ---------------------------------------------------------

create or replace function public.get_active_module_keys_for_tenant(
  p_tenant_id bigint
)
returns text[]
language sql
security definer
set search_path = public
stable
as $$
  with active_assignments as (
    select tm.module_key
    from public.tenant_modules tm
    inner join public.modules mo on mo.key = tm.module_key
    inner join public.tenants t on t.id = tm.tenant_id
    where p_tenant_id is not null
      and tm.tenant_id = p_tenant_id
      and t.is_active = true
      and tm.is_active = true
      and mo.is_active = true
  ),
  standalone_keys as (
    select a.module_key
    from active_assignments a
    where not exists (
      select 1
      from public.modules child
      where child.parent_module_key = a.module_key
    )
  ),
  expanded_child_keys as (
    select child.key as module_key
    from active_assignments a
    inner join public.modules child
      on child.parent_module_key = a.module_key
    where child.is_active = true
      and not exists (
        select 1
        from public.tenant_module_submodules tms
        where tms.tenant_id = p_tenant_id
          and tms.submodule_key = child.key
          and tms.is_enabled = false
      )
  ),
  combined as (
    select module_key from standalone_keys
    union
    select module_key from expanded_child_keys
  )
  select coalesce(
    array_agg(c.module_key order by c.module_key)
      filter (where c.module_key is not null),
    '{}'::text[]
  )
  from combined c;
$$;

grant execute on function public.get_active_module_keys_for_tenant(bigint) to authenticated;

-- ---------------------------------------------------------
-- 8. Submodule management RPCs (superadmin)
-- ---------------------------------------------------------

create or replace function public.list_tenant_module_submodules_for_superadmin(
  p_tenant_id bigint,
  p_parent_module_key text
)
returns table(
  id bigint,
  tenant_id bigint,
  parent_module_key text,
  submodule_key text,
  is_enabled boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    tms.id,
    tms.tenant_id,
    tms.parent_module_key,
    tms.submodule_key,
    tms.is_enabled,
    tms.created_at,
    tms.updated_at
  from public.tenant_module_submodules tms
  where public.is_superadmin()
    and p_tenant_id is not null
    and tms.tenant_id = p_tenant_id
    and tms.parent_module_key = lower(trim(p_parent_module_key))
  order by tms.submodule_key asc;
$$;

grant execute on function public.list_tenant_module_submodules_for_superadmin(bigint, text)
to authenticated;

create or replace function public.set_tenant_module_submodule_for_superadmin(
  p_tenant_id bigint,
  p_parent_module_key text,
  p_submodule_key text,
  p_is_enabled boolean
)
returns table(
  id bigint,
  tenant_id bigint,
  parent_module_key text,
  submodule_key text,
  is_enabled boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  upserted as (
    insert into public.tenant_module_submodules (
      tenant_id,
      parent_module_key,
      submodule_key,
      is_enabled
    )
    select
      p_tenant_id,
      lower(trim(p_parent_module_key)),
      lower(trim(p_submodule_key)),
      coalesce(p_is_enabled, true)
    from permission
    where allowed
      and p_tenant_id is not null
      and exists (
        select 1
        from public.tenant_modules tm
        where tm.tenant_id = p_tenant_id
          and tm.module_key = lower(trim(p_parent_module_key))
          and tm.is_active = true
      )
    on conflict (tenant_id, submodule_key) do update
    set
      parent_module_key = excluded.parent_module_key,
      is_enabled = excluded.is_enabled
    returning
      id,
      tenant_id,
      parent_module_key,
      submodule_key,
      is_enabled,
      created_at,
      updated_at
  )
  select
    id,
    tenant_id,
    parent_module_key,
    submodule_key,
    is_enabled,
    created_at,
    updated_at
  from upserted;
$$;

grant execute on function public.set_tenant_module_submodule_for_superadmin(bigint, text, text, boolean)
to authenticated;

-- Prevent assigning submodule keys directly; cascade overrides on parent delete
create or replace function public.create_tenant_module_for_superadmin(
  p_tenant_id bigint,
  p_module_key text,
  p_is_active boolean default true
)
returns table(
  id bigint,
  tenant_id bigint,
  module_key text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := lower(trim(p_module_key));
  v_parent text;
begin
  if not public.is_superadmin() then
    return;
  end if;

  select mo.parent_module_key into v_parent
  from public.modules mo
  where mo.key = v_key;

  if v_parent is not null then
    raise exception 'Submodule keys cannot be assigned directly. Assign parent module % instead.', v_parent;
  end if;

  return query
  insert into public.tenant_modules as tm (tenant_id, module_key, is_active)
  values (p_tenant_id, v_key, coalesce(p_is_active, true))
  returning
    tm.id,
    tm.tenant_id,
    tm.module_key,
    tm.is_active,
    tm.created_at,
    tm.updated_at;
end;
$$;

grant execute on function public.create_tenant_module_for_superadmin(bigint, text, boolean)
to authenticated;

create or replace function public.delete_tenant_module_for_superadmin(
  p_id bigint
)
returns table(
  id bigint,
  tenant_id bigint,
  module_key text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted public.tenant_modules%rowtype;
begin
  if not public.is_superadmin() then
    return;
  end if;

  delete from public.tenant_modules tm
  where tm.id = p_id
  returning * into v_deleted;

  if v_deleted.id is not null then
    delete from public.tenant_module_submodules tms
    where tms.tenant_id = v_deleted.tenant_id
      and tms.parent_module_key = v_deleted.module_key;
  end if;

  return query
  select
    v_deleted.id,
    v_deleted.tenant_id,
    v_deleted.module_key,
    v_deleted.is_active,
    v_deleted.created_at,
    v_deleted.updated_at;
end;
$$;

grant execute on function public.delete_tenant_module_for_superadmin(bigint)
to authenticated;

commit;
