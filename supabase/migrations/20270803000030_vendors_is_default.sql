-- Phase 1: per-tenant default vendor (is_default + ensure_default_vendor + create_tenant hook + backfill)
-- No shipment column changes.

begin;

-- ---------------------------------------------------------------------------
-- 1. Schema: is_default + one-default-per-tenant
-- ---------------------------------------------------------------------------

alter table public.vendors
  add column if not exists is_default boolean not null default false;

comment on column public.vendors.is_default is
  'True for the tenant system default vendor (code DEFAULT). At most one per tenant_id.';

create unique index if not exists vendors_one_default_per_tenant_idx
  on public.vendors (tenant_id)
  where is_default = true
    and tenant_id is not null;

-- ---------------------------------------------------------------------------
-- 2. ensure_default_vendor(p_tenant_id) — idempotent, security definer
-- ---------------------------------------------------------------------------

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

  -- Vendors / default vendor live on parent (stock-owning) tenants only
  if v_tenant.parent_id is not null then
    raise exception 'ensure_default_vendor requires a parent tenant (got child %)', p_tenant_id;
  end if;

  -- Auth: skip when no JWT (migration / service); otherwise same bar as create_vendor
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

  -- Already has a default
  select id into v_vendor_id
  from public.vendors
  where tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_vendor_id is not null then
    return v_vendor_id;
  end if;

  -- Promote reserved code DEFAULT if present
  select id into v_vendor_id
  from public.vendors
  where tenant_id = p_tenant_id
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

  -- Resolve market_code from existing tenant vendors, then stable prod FKs
  select v.market_code into v_market_code
  from public.vendors v
  where v.tenant_id = p_tenant_id
  order by v.id
  limit 1;

  if v_market_code is null then
    select m.code into v_market_code
    from public.markets m
    where m.is_active = true
      and m.code in ('GB', 'BD', 'US')
    order by case m.code when 'GB' then 1 when 'BD' then 2 else 3 end
    limit 1;
  end if;

  if v_market_code is null then
    select m.code into v_market_code
    from public.markets m
    where m.is_active = true
    order by m.id
    limit 1;
  end if;

  if v_market_code is null then
    raise exception 'no active market available for default vendor';
  end if;

  insert into public.vendors (
    tenant_id,
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

  -- Mirror create_vendor_with_wallet: zero BDT wallet anchor
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

revoke all on function public.ensure_default_vendor(bigint) from public;
grant execute on function public.ensure_default_vendor(bigint) to authenticated;
grant execute on function public.ensure_default_vendor(bigint) to service_role;

-- ---------------------------------------------------------------------------
-- 3. Hook create_tenant_for_superadmin — default vendor for parent tenants
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

  -- Parent (stock-owning) tenants get a DEFAULT vendor
  if v_parent_id is null then
    perform public.ensure_default_vendor(v_id);
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
-- 4. Backfill: every existing parent tenant
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
    perform public.ensure_default_vendor(r.id);
  end loop;
end
$$;

commit;
