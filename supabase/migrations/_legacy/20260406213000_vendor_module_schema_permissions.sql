-- =========================================================
-- Vendor module
-- - vendor master with tenant/global ownership
-- - tenant-level global vendor access setting
-- - code availability helper
-- =========================================================

create table if not exists public.tenant_vendor_access_settings (
  tenant_id bigint primary key references public.tenants(id) on delete cascade,
  allow_global_vendor_access boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.vendors (
  id bigserial primary key,
  name text not null,
  code text not null unique,
  market_code text not null references public.markets(code),
  tenant_id bigint references public.tenants(id) on delete cascade,
  email text,
  phone text,
  address text,
  website text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint vendors_name_not_blank check (length(trim(name)) > 0),
  constraint vendors_code_not_blank check (length(trim(code)) > 0),
  constraint vendors_market_code_not_blank check (length(trim(market_code)) > 0)
);

create index if not exists vendors_tenant_id_idx on public.vendors(tenant_id);
create index if not exists vendors_market_code_idx on public.vendors(market_code);

create trigger trg_tenant_vendor_access_settings_updated_at
before update on public.tenant_vendor_access_settings
for each row execute function public.set_updated_at();

create trigger trg_vendors_updated_at
before update on public.vendors
for each row execute function public.set_updated_at();

create or replace function public.normalize_vendor_fields()
returns trigger
language plpgsql
as $$
begin
  new.name = trim(new.name);
  new.code = upper(trim(new.code));
  new.market_code = upper(trim(new.market_code));

  if new.email is not null then
    new.email = nullif(lower(trim(new.email)), '');
  end if;

  if new.phone is not null then
    new.phone = nullif(trim(new.phone), '');
  end if;

  if new.address is not null then
    new.address = nullif(trim(new.address), '');
  end if;

  if new.website is not null then
    new.website = nullif(trim(new.website), '');
  end if;

  return new;
end;
$$;

drop trigger if exists trg_vendors_normalize_fields on public.vendors;
create trigger trg_vendors_normalize_fields
before insert or update on public.vendors
for each row execute function public.normalize_vendor_fields();

create or replace function public.is_vendor_module_enabled(
  p_tenant_id bigint
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.tenant_modules tm
    inner join public.modules mo
      on mo.key = tm.module_key
    where tm.tenant_id = p_tenant_id
      and tm.module_key = 'vendor'
      and tm.is_active = true
      and mo.is_active = true
  );
$$;

create or replace function public.is_vendor_code_available(
  p_code text,
  p_exclude_id bigint default null
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select not exists (
    select 1
    from public.vendors v
    where upper(trim(v.code)) = upper(trim(p_code))
      and (p_exclude_id is null or v.id <> p_exclude_id)
  );
$$;

grant execute on function public.is_vendor_code_available(text, bigint)
to authenticated;

create or replace function public.list_vendor_markets()
returns table(
  code text,
  name text,
  region text
)
language sql
security definer
set search_path = public
stable
as $$
  select m.code, m.name, m.region
  from public.markets m
  where m.is_active = true
  order by m.name asc;
$$;

grant execute on function public.list_vendor_markets()
to authenticated;

create or replace function public.get_tenant_vendor_access_setting(
  p_tenant_id bigint
)
returns table(
  tenant_id bigint,
  allow_global_vendor_access boolean
)
language sql
security definer
set search_path = public
stable
as $$
  select
    p_tenant_id as tenant_id,
    coalesce(
      (
        select tvas.allow_global_vendor_access
        from public.tenant_vendor_access_settings tvas
        where tvas.tenant_id = p_tenant_id
      ),
      false
    ) as allow_global_vendor_access
  where public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id);
$$;

grant execute on function public.get_tenant_vendor_access_setting(bigint)
to authenticated;

create or replace function public.set_tenant_vendor_access_setting(
  p_tenant_id bigint,
  p_allow_global_vendor_access boolean
)
returns table(
  tenant_id bigint,
  allow_global_vendor_access boolean
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_superadmin() then
    raise exception 'Only superadmin can update vendor access settings.';
  end if;

  insert into public.tenant_vendor_access_settings (
    tenant_id,
    allow_global_vendor_access
  )
  values (
    p_tenant_id,
    p_allow_global_vendor_access
  )
  on conflict (tenant_id)
  do update set
    allow_global_vendor_access = excluded.allow_global_vendor_access,
    updated_at = now();

  return query
  select
    tvas.tenant_id,
    tvas.allow_global_vendor_access
  from public.tenant_vendor_access_settings tvas
  where tvas.tenant_id = p_tenant_id;
end;
$$;

grant execute on function public.set_tenant_vendor_access_setting(bigint, boolean)
to authenticated;

alter table public.tenant_vendor_access_settings enable row level security;
alter table public.vendors enable row level security;

create policy "superadmin_can_manage_tenant_vendor_access_settings"
on public.tenant_vendor_access_settings
for all
to authenticated
using (public.is_superadmin())
with check (public.is_superadmin());

create policy "tenant_admin_can_view_own_vendor_access_settings"
on public.tenant_vendor_access_settings
for select
to authenticated
using (public.is_tenant_admin(tenant_id));

create policy "vendors_select"
on public.vendors
for select
to authenticated
using (
  (public.is_superadmin() and tenant_id is null)
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
      and m.is_active = true
      and m.tenant_id is not null
      and public.is_vendor_module_enabled(m.tenant_id)
      and (
        vendors.tenant_id = m.tenant_id
        or (
          vendors.tenant_id is null
          and exists (
            select 1
            from public.tenant_vendor_access_settings tvas
            where tvas.tenant_id = m.tenant_id
              and tvas.allow_global_vendor_access = true
          )
        )
      )
  )
);

create policy "vendors_insert"
on public.vendors
for insert
to authenticated
with check (
  (public.is_superadmin() and tenant_id is null)
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
      and m.is_active = true
      and m.tenant_id is not null
      and public.is_vendor_module_enabled(m.tenant_id)
      and (
        vendors.tenant_id = m.tenant_id
        or (
          vendors.tenant_id is null
          and exists (
            select 1
            from public.tenant_vendor_access_settings tvas
            where tvas.tenant_id = m.tenant_id
              and tvas.allow_global_vendor_access = true
          )
        )
      )
  )
);

create policy "vendors_update"
on public.vendors
for update
to authenticated
using (
  (public.is_superadmin() and tenant_id is null)
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
      and m.is_active = true
      and m.tenant_id is not null
      and public.is_vendor_module_enabled(m.tenant_id)
      and (
        vendors.tenant_id = m.tenant_id
        or (
          vendors.tenant_id is null
          and exists (
            select 1
            from public.tenant_vendor_access_settings tvas
            where tvas.tenant_id = m.tenant_id
              and tvas.allow_global_vendor_access = true
          )
        )
      )
  )
)
with check (
  (public.is_superadmin() and tenant_id is null)
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
      and m.is_active = true
      and m.tenant_id is not null
      and public.is_vendor_module_enabled(m.tenant_id)
      and (
        vendors.tenant_id = m.tenant_id
        or (
          vendors.tenant_id is null
          and exists (
            select 1
            from public.tenant_vendor_access_settings tvas
            where tvas.tenant_id = m.tenant_id
              and tvas.allow_global_vendor_access = true
          )
        )
      )
  )
);

create policy "vendors_delete"
on public.vendors
for delete
to authenticated
using (
  (public.is_superadmin() and tenant_id is null)
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
      and m.is_active = true
      and m.tenant_id is not null
      and public.is_vendor_module_enabled(m.tenant_id)
      and (
        vendors.tenant_id = m.tenant_id
        or (
          vendors.tenant_id is null
          and exists (
            select 1
            from public.tenant_vendor_access_settings tvas
            where tvas.tenant_id = m.tenant_id
              and tvas.allow_global_vendor_access = true
          )
        )
      )
  )
);

grant select, insert, update, delete
on table public.vendors
to authenticated;

grant usage, select
on sequence public.vendors_id_seq
to authenticated;

grant select, insert, update, delete
on table public.tenant_vendor_access_settings
to authenticated;
