-- Vendors and cargo companies are parent-books scoped only (parent_tenant_id).

update public.vendors v
set parent_tenant_id = coalesce(
  v.parent_tenant_id,
  case
    when v.tenant_id is not null and public.is_child_tenant(v.tenant_id)
      then public.resolve_parent_tenant_id(v.tenant_id)
    else v.tenant_id
  end
)
where v.parent_tenant_id is null
  and v.tenant_id is not null;

update public.cargo_companies c
set parent_tenant_id = coalesce(c.parent_tenant_id, c.tenant_id)
where c.parent_tenant_id is null
  and c.tenant_id is not null;

-- Drop RLS that references tenant_id before dropping columns
drop policy if exists vendors_insert on public.vendors;
drop policy if exists vendors_update on public.vendors;
drop policy if exists vendors_delete on public.vendors;
drop policy if exists vendors_select on public.vendors;

drop policy if exists cargo_companies_delete_policy on public.cargo_companies;
drop policy if exists cargo_companies_insert_policy on public.cargo_companies;
drop policy if exists cargo_companies_select_policy on public.cargo_companies;
drop policy if exists cargo_companies_update_policy on public.cargo_companies;

drop index if exists public.vendors_tenant_id_idx;
drop index if exists public.vendors_tenant_code_unique_idx;
drop index if exists public.vendors_one_default_per_tenant_idx;

drop index if exists public.cargo_companies_tenant_id_idx;
drop index if exists public.cargo_companies_tenant_code_idx;
drop index if exists public.cargo_companies_one_default_per_tenant_idx;

drop index if exists public.vendors_global_code_unique_idx;

create unique index if not exists vendors_global_code_unique_idx
  on public.vendors (upper(trim(code)))
  where parent_tenant_id is null;

create unique index if not exists vendors_parent_code_unique_idx
  on public.vendors (parent_tenant_id, upper(trim(code)))
  where parent_tenant_id is not null;

create unique index if not exists vendors_one_default_per_parent_idx
  on public.vendors (parent_tenant_id)
  where is_default = true and parent_tenant_id is not null;

create unique index if not exists cargo_companies_parent_code_idx
  on public.cargo_companies (parent_tenant_id, upper(trim(code)))
  where parent_tenant_id is not null;

create unique index if not exists cargo_companies_one_default_per_parent_idx
  on public.cargo_companies (parent_tenant_id)
  where is_default = true and parent_tenant_id is not null;

drop trigger if exists trg_vendors_set_parent_tenant_id on public.vendors;

alter table public.vendors
  drop constraint if exists vendors_tenant_id_fkey;

alter table public.cargo_companies
  drop constraint if exists cargo_companies_tenant_id_fkey;

alter table public.vendors drop column if exists tenant_id;
alter table public.cargo_companies drop column if exists tenant_id;

comment on column public.vendors.is_default is
  'True for the tenant system default vendor (code DEFAULT). At most one per parent_tenant_id.';

comment on column public.cargo_companies.is_default is
  'True for the tenant system default cargo company (code DEFAULT). At most one per parent_tenant_id.';

-- RLS: vendors (recreated)
create policy vendors_insert on public.vendors
for insert to authenticated
with check (
  (public.is_superadmin() and parent_tenant_id is null)
  or (parent_tenant_id is not null and public.is_network_owner(parent_tenant_id))
  or exists (
    select 1 from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'::public.app_role
      and m.is_active = true
      and m.tenant_id is not null
      and vendors.parent_tenant_id = m.tenant_id
  )
);

create policy vendors_update on public.vendors
for update to authenticated
using (
  (public.is_superadmin() and parent_tenant_id is null)
  or (parent_tenant_id is not null and public.is_network_owner(parent_tenant_id))
  or exists (
    select 1 from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'::public.app_role
      and m.is_active = true
      and m.tenant_id is not null
      and vendors.parent_tenant_id = m.tenant_id
  )
)
with check (
  (public.is_superadmin() and parent_tenant_id is null)
  or (parent_tenant_id is not null and public.is_network_owner(parent_tenant_id))
  or exists (
    select 1 from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'::public.app_role
      and m.is_active = true
      and m.tenant_id is not null
      and vendors.parent_tenant_id = m.tenant_id
  )
);

create policy vendors_delete on public.vendors
for delete to authenticated
using (
  (public.is_superadmin() and parent_tenant_id is null)
  or (parent_tenant_id is not null and public.is_network_owner(parent_tenant_id))
  or exists (
    select 1 from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'::public.app_role
      and m.is_active = true
      and m.tenant_id is not null
      and vendors.parent_tenant_id = m.tenant_id
  )
);

create policy vendors_select on public.vendors
for select to authenticated
using (
  (public.is_superadmin() and parent_tenant_id is null)
  or exists (
    select 1 from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'::public.app_role
      and m.is_active = true
      and m.tenant_id is not null
      and vendors.parent_tenant_id = m.tenant_id
  )
  or (parent_tenant_id is not null and public.user_can_manage_parent_tenant(parent_tenant_id))
);

-- RLS: cargo_companies (recreated)
create policy cargo_companies_delete_policy on public.cargo_companies
for delete using (parent_tenant_id = public.current_tenant_id());

create policy cargo_companies_insert_policy on public.cargo_companies
for insert with check (parent_tenant_id = public.current_tenant_id());

create policy cargo_companies_select_policy on public.cargo_companies
for select using (parent_tenant_id = public.current_tenant_id());

create policy cargo_companies_update_policy on public.cargo_companies
for update using (parent_tenant_id = public.current_tenant_id());

create or replace function public.list_vendors_for_tenant(p_tenant_id bigint)
returns setof public.vendors
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
begin
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;

    return query
    select v.*
    from public.vendors v
    where v.parent_tenant_id is null
    order by v.id asc;

    return;
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  select v.*
  from public.vendors v
  where v.parent_tenant_id = v_books_id
  order by v.id asc;
end;
$$;

create or replace function public.get_vendor_for_tenant(p_id bigint, p_tenant_id bigint)
returns public.vendors
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_row public.vendors;
  v_books_id bigint;
begin
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;

    select * into v_row
    from public.vendors
    where id = p_id
      and parent_tenant_id is null;

    return v_row;
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_row
  from public.vendors
  where id = p_id
    and parent_tenant_id = v_books_id;

  return v_row;
end;
$$;

create or replace function public.ensure_default_vendor(p_tenant_id bigint)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant public.tenants%rowtype;
  v_vendor_id bigint;
  v_market_code text;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  if v_tenant.parent_id is not null then
    raise exception 'ensure_default_vendor requires a parent tenant (got child %)', p_tenant_id;
  end if;

  if auth.uid() is not null then
    if not (
      public.is_superadmin()
      or public.user_can_manage_parent_tenant(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        where m.tenant_id = p_tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.role in ('admin', 'staff')
          and m.is_active = true
      )
    ) then
      raise exception 'not allowed';
    end if;
  end if;

  select id into v_vendor_id
  from public.vendors
  where parent_tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_vendor_id is not null then
    return v_vendor_id;
  end if;

  select id into v_vendor_id
  from public.vendors
  where parent_tenant_id = p_tenant_id
    and upper(trim(code)) = 'DEFAULT'
  limit 1;

  if v_vendor_id is not null then
    update public.vendors
    set is_default = true,
        name = coalesce(nullif(trim(name), ''), 'Default Vendor'),
        updated_at = now()
    where id = v_vendor_id;
    return v_vendor_id;
  end if;

  select upper(trim(code)) into v_market_code
  from public.global_markets
  where is_active = true
  order by id asc
  limit 1;

  if v_market_code is null or v_market_code = '' then
    v_market_code := 'BD';
  end if;

  insert into public.vendors (
    parent_tenant_id,
    name,
    code,
    market_code,
    is_default
  )
  values (
    p_tenant_id,
    'Default Vendor',
    'DEFAULT',
    v_market_code,
    true
  )
  returning id into v_vendor_id;

  insert into public.wallet_accounts (
    tenant_id,
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    p_tenant_id,
    'vendor',
    v_vendor_id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now();

  return v_vendor_id;
end;
$$;

create or replace function public.ensure_default_cargo_company(p_tenant_id bigint)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant public.tenants%rowtype;
  v_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  if v_tenant.parent_id is not null then
    raise exception 'ensure_default_cargo_company requires a parent tenant (got child %)', p_tenant_id;
  end if;

  if auth.uid() is not null then
    if not (
      public.is_superadmin()
      or public.user_can_manage_parent_tenant(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        where m.tenant_id = p_tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.role in ('admin', 'staff')
          and m.is_active = true
      )
    ) then
      raise exception 'not allowed';
    end if;
  end if;

  select id into v_id
  from public.cargo_companies
  where parent_tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_id is not null then
    return v_id;
  end if;

  select id into v_id
  from public.cargo_companies
  where parent_tenant_id = p_tenant_id
    and upper(trim(code)) = 'DEFAULT'
  limit 1;

  if v_id is not null then
    update public.cargo_companies
    set is_default = true,
        name = coalesce(nullif(trim(name), ''), 'Default Cargo Company'),
        is_active = true,
        updated_at = now()
    where id = v_id;
    return v_id;
  end if;

  insert into public.cargo_companies (
    parent_tenant_id,
    name,
    code,
    is_default,
    is_active
  )
  values (
    p_tenant_id,
    'Default Cargo Company',
    'DEFAULT',
    true,
    true
  )
  returning id into v_id;

  insert into public.wallet_accounts (
    tenant_id,
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    p_tenant_id,
    'cargo_company',
    v_id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now();

  return v_id;
end;
$$;

create or replace function public.create_shipment_draft(
  p_parent_tenant_id bigint,
  p_name text,
  p_type public.global_shipment_type,
  p_vendor_id bigint default null,
  p_cargo_company_id bigint default null
)
returns public.global_shipments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stock_parent bigint;
  v_vendor_id bigint;
  v_cargo_id bigint;
  v_row public.global_shipments%rowtype;
begin
  if p_parent_tenant_id is null then
    raise exception 'p_parent_tenant_id is required';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  if p_type is null then
    raise exception 'type is required';
  end if;

  v_stock_parent := public.resolve_parent_tenant_id(p_parent_tenant_id);

  if not public.user_can_manage_parent_tenant(v_stock_parent) then
    raise exception 'not allowed';
  end if;

  v_vendor_id := p_vendor_id;
  if v_vendor_id is null then
    v_vendor_id := public.ensure_default_vendor(v_stock_parent);
  else
    if not exists (
      select 1
      from public.vendors v
      where v.id = v_vendor_id
        and v.parent_tenant_id = v_stock_parent
    ) then
      raise exception 'vendor % does not belong to parent tenant %', v_vendor_id, v_stock_parent;
    end if;
  end if;

  v_cargo_id := p_cargo_company_id;
  if v_cargo_id is null then
    v_cargo_id := public.ensure_default_cargo_company(v_stock_parent);
  else
    if not exists (
      select 1
      from public.cargo_companies c
      where c.id = v_cargo_id
        and c.parent_tenant_id = v_stock_parent
    ) then
      raise exception 'cargo company % does not belong to parent tenant %', v_cargo_id, v_stock_parent;
    end if;
  end if;

  insert into public.global_shipments (
    parent_tenant_id,
    name,
    type,
    vendor_id,
    cargo_company_id,
    status
  )
  values (
    v_stock_parent,
    trim(p_name),
    p_type,
    v_vendor_id,
    v_cargo_id,
    'draft'
  )
  returning * into v_row;

  insert into public.global_shipment_sections (
    parent_tenant_id,
    shipment_id,
    vendor_id,
    title,
    sort_order,
    metadata
  )
  values (
    v_stock_parent,
    v_row.id,
    v_vendor_id,
    'Section 1',
    0,
    '{}'::jsonb
  );

  return v_row;
end;
$$;

create or replace function public.sync_product_tenant_from_vendor()
returns trigger
language plpgsql
as $$
declare
  v_parent_tenant_id bigint;
begin
  if new.vendor_id is not null then
    select v.parent_tenant_id
    into v_parent_tenant_id
    from public.vendors v
    where v.id = new.vendor_id;

    if v_parent_tenant_id is not null then
      new.parent_tenant_id := public.resolve_parent_tenant_id(v_parent_tenant_id);
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.trg_sync_profile_from_vendor()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
begin
  v_books_id := new.parent_tenant_id;

  if v_books_id is null then
    return new;
  end if;

  perform public.upsert_profile_for_party(
    v_books_id,
    'vendor'::public.profile_party_type,
    new.id,
    new.name,
    new.email,
    new.phone,
    '+880',
    new.address,
    case when new.phone is null or btrim(new.phone) = '' then false else true end,
    null,
    true,
    null
  );

  return new;
end;
$$;

create or replace function public.trg_sync_profile_from_cargo_company()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
begin
  v_books_id := new.parent_tenant_id;

  if v_books_id is null then
    return new;
  end if;

  perform public.upsert_profile_for_party(
    v_books_id,
    'cargo'::public.profile_party_type,
    new.id,
    new.name,
    new.email,
    new.phone,
    '+880',
    new.address,
    case when new.phone is null or btrim(new.phone) = '' then false else true end,
    null,
    true,
    null
  );

  return new;
end;
$$;

-- create_vendor_with_wallet (global-capable overload)
create or replace function public.create_vendor_with_wallet(
  p_tenant_id bigint,
  p_name text,
  p_code text,
  p_market_code text,
  p_email text default null,
  p_phone text default null,
  p_address text default null,
  p_website text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vendor public.vendors;
  v_wallet public.wallet_accounts;
  v_currency_code text := 'BDT';
  v_books_id bigint;
begin
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;
    v_books_id := null;
  else
    if not (
      public.is_superadmin()
      or public.user_can_manage_parent_tenant(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        where m.tenant_id = p_tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.role in ('admin', 'staff')
          and m.is_active = true
      )
    ) then
      raise exception 'not allowed';
    end if;
    v_books_id := p_tenant_id;
  end if;

  insert into public.vendors (
    parent_tenant_id,
    name,
    code,
    market_code,
    email,
    phone,
    address,
    website
  )
  values (
    v_books_id,
    trim(p_name),
    upper(trim(p_code)),
    upper(trim(p_market_code)),
    nullif(lower(trim(p_email)), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_website), '')
  )
  returning * into v_vendor;

  if v_books_id is not null then
    insert into public.wallet_accounts (
      tenant_id,
      entity_type,
      entity_id,
      currency_code,
      available_balance,
      pending_balance,
      locked_balance
    )
    values (
      v_books_id,
      'vendor',
      v_vendor.id,
      v_currency_code,
      0.0000,
      0.0000,
      0.0000
    )
    on conflict (tenant_id, entity_type, entity_id, currency_code)
    do update set updated_at = now()
    returning * into v_wallet;
  end if;

  return jsonb_build_object(
    'vendor', to_jsonb(v_vendor),
    'wallet', to_jsonb(v_wallet)
  );
end;
$$;

-- create_vendor_with_wallet (parent-tenant only overload)
create or replace function public.create_vendor_with_wallet(
  p_tenant_id bigint,
  p_name text,
  p_code text,
  p_market_code text,
  p_email text default null,
  p_phone text default null,
  p_address text default null,
  p_website text default null,
  p_currency_code text default 'BDT'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vendor public.vendors%rowtype;
  v_wallet public.wallet_accounts%rowtype;
  v_currency_code text := coalesce(nullif(trim(p_currency_code), ''), 'BDT');
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if not (
    public.is_superadmin()
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.role in ('admin', 'staff')
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  if exists (
    select 1 from public.tenants t where t.id = p_tenant_id and t.parent_id is not null
  ) then
    raise exception 'vendors belong on parent tenants only';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  if nullif(trim(p_code), '') is null then
    raise exception 'code is required';
  end if;

  if upper(trim(p_code)) = 'DEFAULT' then
    raise exception 'code DEFAULT is reserved for the system default vendor';
  end if;

  if nullif(trim(p_market_code), '') is null then
    raise exception 'market_code is required';
  end if;

  if exists (
    select 1
    from public.vendors v
    where v.parent_tenant_id = p_tenant_id
      and upper(trim(v.code)) = upper(trim(p_code))
  ) then
    raise exception 'vendor code % already exists for this tenant', upper(trim(p_code));
  end if;

  if p_email is not null and trim(p_email) <> '' then
    if exists (
      select 1
      from public.vendors v
      where v.parent_tenant_id = p_tenant_id
        and lower(trim(v.email)) = lower(trim(p_email))
    ) then
      raise exception 'vendor email % already exists for this tenant', lower(trim(p_email));
    end if;
  end if;

  insert into public.vendors (
    parent_tenant_id,
    name,
    code,
    market_code,
    email,
    phone,
    address,
    website
  )
  values (
    p_tenant_id,
    trim(p_name),
    upper(trim(p_code)),
    upper(trim(p_market_code)),
    nullif(lower(trim(p_email)), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_website), '')
  )
  returning * into v_vendor;

  insert into public.wallet_accounts (
    tenant_id,
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    coalesce(v_vendor.parent_tenant_id, p_tenant_id),
    'vendor',
    v_vendor.id,
    v_currency_code,
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now()
  returning * into v_wallet;

  return jsonb_build_object(
    'vendor', to_jsonb(v_vendor),
    'wallet', to_jsonb(v_wallet)
  );
end;
$$;

create or replace function public.create_cargo_company_with_wallet(
  p_tenant_id bigint,
  p_name text,
  p_code text,
  p_email text default null,
  p_phone text default null,
  p_address text default null,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.cargo_companies;
  v_wallet public.wallet_accounts;
  v_code text;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if not (
    public.is_superadmin()
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.role in ('admin', 'staff')
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  if exists (
    select 1 from public.tenants t where t.id = p_tenant_id and t.parent_id is not null
  ) then
    raise exception 'cargo companies belong on parent tenants only';
  end if;

  v_code := upper(trim(p_code));
  if v_code is null or v_code = '' then
    raise exception 'code is required';
  end if;

  if v_code = 'DEFAULT' then
    raise exception 'code DEFAULT is reserved for the system default cargo company';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  insert into public.cargo_companies (
    parent_tenant_id,
    name,
    code,
    email,
    phone,
    address,
    notes,
    is_default,
    is_active
  )
  values (
    p_tenant_id,
    trim(p_name),
    v_code,
    nullif(lower(trim(p_email)), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_notes), ''),
    false,
    true
  )
  returning * into v_row;

  insert into public.wallet_accounts (
    tenant_id,
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    p_tenant_id,
    'cargo_company',
    v_row.id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now()
  returning * into v_wallet;

  return jsonb_build_object(
    'cargo_company', to_jsonb(v_row),
    'wallet', to_jsonb(v_wallet)
  );
end;
$$;
