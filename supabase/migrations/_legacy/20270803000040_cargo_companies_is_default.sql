-- Cargo companies: is_default + ensure_default + create_with_wallet + tenant/shipment hooks
-- Mirrors vendors_is_default (20270803000030). Depends on cargo_companies + create_shipment_draft.

begin;

-- ---------------------------------------------------------------------------
-- 1. Schema: is_default + one-default-per-tenant
-- ---------------------------------------------------------------------------

alter table public.cargo_companies
  add column if not exists is_default boolean not null default false;

comment on column public.cargo_companies.is_default is
  'True for the tenant system default cargo company (code DEFAULT). At most one per tenant_id.';

create unique index if not exists cargo_companies_one_default_per_tenant_idx
  on public.cargo_companies (tenant_id)
  where is_default = true
    and tenant_id is not null;

-- ---------------------------------------------------------------------------
-- 2. ensure_default_cargo_company(p_tenant_id)
-- ---------------------------------------------------------------------------

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
  where tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_id is not null then
    return v_id;
  end if;

  select id into v_id
  from public.cargo_companies
  where tenant_id = p_tenant_id
    and upper(trim(code)) = 'DEFAULT'
  limit 1;

  if v_id is not null then
    update public.cargo_companies
    set is_default = true,
        name = coalesce(nullif(trim(name), ''), 'Default Cargo Company'),
        parent_tenant_id = coalesce(parent_tenant_id, p_tenant_id),
        is_active = true,
        updated_at = now()
    where id = v_id;
    return v_id;
  end if;

  insert into public.cargo_companies (
    tenant_id,
    parent_tenant_id,
    name,
    code,
    is_default,
    is_active
  )
  values (
    p_tenant_id,
    p_tenant_id,
    'Default Cargo Company',
    'DEFAULT',
    true,
    true
  )
  returning id into v_id;

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

revoke all on function public.ensure_default_cargo_company(bigint) from public;
grant execute on function public.ensure_default_cargo_company(bigint) to authenticated;
grant execute on function public.ensure_default_cargo_company(bigint) to service_role;

-- ---------------------------------------------------------------------------
-- 3. create_cargo_company_with_wallet
-- ---------------------------------------------------------------------------

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
    tenant_id,
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
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
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

revoke all on function public.create_cargo_company_with_wallet(
  bigint, text, text, text, text, text, text
) from public;
grant execute on function public.create_cargo_company_with_wallet(
  bigint, text, text, text, text, text, text
) to authenticated;
grant execute on function public.create_cargo_company_with_wallet(
  bigint, text, text, text, text, text, text
) to service_role;

-- ---------------------------------------------------------------------------
-- 4. Hook create_tenant_for_superadmin — default vendor + cargo company
-- ---------------------------------------------------------------------------

drop function if exists public.create_tenant_for_superadmin(text, text, boolean, text, bigint);

create function public.create_tenant_for_superadmin(
  p_name text,
  p_slug text,
  p_is_active boolean default true,
  p_public_domain text default null,
  p_parent_id bigint default null
)
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text,
  is_active boolean,
  parent_id bigint,
  preference jsonb,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_id bigint;
  v_name text;
  v_slug text;
  v_public_domain text;
  v_is_active boolean;
  v_parent_id bigint;
  v_preference jsonb;
  v_created_at timestamptz;
  v_updated_at timestamptz;
begin
  if not public.is_superadmin() then
    return;
  end if;

  insert into public.tenants (name, slug, public_domain, is_active, parent_id)
  values (
    trim(p_name),
    lower(trim(p_slug)),
    nullif(
      regexp_replace(
        lower(
          trim(
            split_part(
              regexp_replace(coalesce(p_public_domain, ''), '^https?://', '', 'i'),
              '/',
              1
            )
          )
        ),
        ':\d+$',
        ''
      ),
      ''
    ),
    coalesce(p_is_active, true),
    p_parent_id
  )
  returning
    tenants.id,
    tenants.name,
    tenants.slug,
    tenants.public_domain,
    tenants.is_active,
    tenants.parent_id,
    tenants.preference,
    tenants.created_at,
    tenants.updated_at
  into
    v_id,
    v_name,
    v_slug,
    v_public_domain,
    v_is_active,
    v_parent_id,
    v_preference,
    v_created_at,
    v_updated_at;

  if v_parent_id is null then
    perform public.ensure_default_vendor(v_id);
    perform public.ensure_default_cargo_company(v_id);
  end if;

  return query
  select
    v_id,
    v_name,
    v_slug,
    v_public_domain,
    v_is_active,
    v_parent_id,
    v_preference,
    v_created_at,
    v_updated_at;
end;
$$;

grant execute on function public.create_tenant_for_superadmin(text, text, boolean, text, bigint)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. create_shipment_draft — fallback to default cargo company
-- ---------------------------------------------------------------------------

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
        and coalesce(v.parent_tenant_id, v.tenant_id) = v_stock_parent
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
        and coalesce(c.parent_tenant_id, c.tenant_id) = v_stock_parent
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
    'Draft'
  )
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.create_shipment_draft(
  bigint, text, public.global_shipment_type, bigint, bigint
) from public;
grant execute on function public.create_shipment_draft(
  bigint, text, public.global_shipment_type, bigint, bigint
) to authenticated;
grant execute on function public.create_shipment_draft(
  bigint, text, public.global_shipment_type, bigint, bigint
) to service_role;

-- ---------------------------------------------------------------------------
-- 6. Module seed: cargo_company under procurement_stock
-- ---------------------------------------------------------------------------

insert into public.modules (key, name, description, is_active, parent_module_key)
values (
  'cargo_company',
  'Cargo Companies',
  'Inbound freight / cargo agents for procurement shipments.',
  true,
  'procurement_stock'
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('cargo_company', 'view', 'app', true, true),
  ('cargo_company', 'create', 'app', true, true),
  ('cargo_company', 'edit', 'app', true, true),
  ('cargo_company', 'delete', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

delete from public.tenant_modules where module_key = 'cargo_company';

-- ---------------------------------------------------------------------------
-- 7. Backfill: every existing parent tenant
-- ---------------------------------------------------------------------------

do $$
declare
  r record;
begin
  for r in
    select t.id
    from public.tenants t
    where t.parent_id is null
    order by t.id
  loop
    perform public.ensure_default_cargo_company(r.id);
  end loop;
end
$$;

commit;
