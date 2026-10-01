-- Sync public.profiles from party tables (vendor, cargo, courier, tenant).
-- Customers: billing_profiles trigger + customer_groups hub-field trigger.

create or replace function public.upsert_profile_for_party(
  p_parent_tenant_id bigint,
  p_profile_type public.profile_party_type,
  p_subject_id bigint,
  p_name text,
  p_email text default null,
  p_phone text default null,
  p_phone_country_code text default '+880',
  p_address text default null,
  p_is_phone_unique boolean default true,
  p_accent_color text default null,
  p_is_active boolean default true,
  p_deleted_at timestamptz default null
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id bigint;
  v_phone_unique boolean;
begin
  if p_parent_tenant_id is null or p_subject_id is null then
    return null;
  end if;

  if nullif(btrim(coalesce(p_name, '')), '') is null then
    raise exception 'profile name is required';
  end if;

  v_phone_unique := coalesce(p_is_phone_unique, true);
  if p_phone is null or btrim(p_phone) = '' then
    v_phone_unique := false;
  end if;

  insert into public.profiles (
    parent_tenant_id,
    profile_type,
    subject_id,
    name,
    email,
    phone,
    phone_country_code,
    address,
    is_phone_unique,
    accent_color,
    is_active,
    deleted_at
  )
  values (
    p_parent_tenant_id,
    p_profile_type,
    p_subject_id,
    btrim(p_name),
    nullif(btrim(coalesce(p_email, '')), ''),
    nullif(btrim(coalesce(p_phone, '')), ''),
    coalesce(nullif(btrim(coalesce(p_phone_country_code, '')), ''), '+880'),
    nullif(btrim(coalesce(p_address, '')), ''),
    v_phone_unique,
    nullif(btrim(coalesce(p_accent_color, '')), ''),
    coalesce(p_is_active, true),
    p_deleted_at
  )
  on conflict (parent_tenant_id, profile_type, subject_id) do update set
    name = excluded.name,
    email = excluded.email,
    phone = excluded.phone,
    phone_country_code = excluded.phone_country_code,
    address = excluded.address,
    is_phone_unique = excluded.is_phone_unique,
    accent_color = coalesce(excluded.accent_color, profiles.accent_color),
    is_active = excluded.is_active,
    deleted_at = excluded.deleted_at,
    updated_at = now()
  returning id into v_profile_id;

  return v_profile_id;
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
  v_books_id := coalesce(
    new.parent_tenant_id,
    case when new.tenant_id is not null then public.resolve_parent_tenant_id(new.tenant_id) end
  );

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
  v_books_id := coalesce(
    new.parent_tenant_id,
    case when new.tenant_id is not null then public.resolve_parent_tenant_id(new.tenant_id) end
  );

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
    coalesce(new.is_active, true),
    null
  );

  return new;
end;
$$;

create or replace function public.trg_sync_profile_from_courier_service()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
begin
  if new.tenant_id is null then
    return new;
  end if;

  v_books_id := public.resolve_parent_tenant_id(new.tenant_id);

  perform public.upsert_profile_for_party(
    v_books_id,
    'courier'::public.profile_party_type,
    new.wallet_entity_id,
    new.name,
    null,
    null,
    '+880',
    null,
    false,
    null,
    coalesce(new.is_active, true),
    null
  );

  return new;
end;
$$;

create or replace function public.trg_sync_profile_from_tenant()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
begin
  v_books_id := coalesce(new.parent_id, new.id);

  perform public.upsert_profile_for_party(
    v_books_id,
    'tenant'::public.profile_party_type,
    new.id,
    new.name,
    null,
    null,
    '+880',
    null,
    false,
    null,
    coalesce(new.is_active, true),
    null
  );

  return new;
end;
$$;

create or replace function public.trg_sync_profile_from_customer_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles p
  set
    accent_color = new.accent_color,
    is_active = new.is_active,
    deleted_at = new.deleted_at,
    updated_at = now()
  from public.billing_profiles bp
  where bp.customer_group_id = new.id
    and p.id = bp.id;

  return new;
end;
$$;

drop trigger if exists trg_vendors_sync_profile on public.vendors;
create trigger trg_vendors_sync_profile
  after insert or update on public.vendors
  for each row
  execute function public.trg_sync_profile_from_vendor();

drop trigger if exists trg_cargo_companies_sync_profile on public.cargo_companies;
create trigger trg_cargo_companies_sync_profile
  after insert or update on public.cargo_companies
  for each row
  execute function public.trg_sync_profile_from_cargo_company();

drop trigger if exists trg_courier_services_sync_profile on public.courier_services;
create trigger trg_courier_services_sync_profile
  after insert or update on public.courier_services
  for each row
  execute function public.trg_sync_profile_from_courier_service();

drop trigger if exists trg_tenants_sync_profile on public.tenants;
create trigger trg_tenants_sync_profile
  after insert or update of name, is_active on public.tenants
  for each row
  execute function public.trg_sync_profile_from_tenant();

drop trigger if exists trg_customer_groups_sync_profile on public.customer_groups;
create trigger trg_customer_groups_sync_profile
  after update of accent_color, is_active, deleted_at on public.customer_groups
  for each row
  execute function public.trg_sync_profile_from_customer_group();

-- Backfill existing rows (customers already from billing_profiles migration).
do $$
declare
  v_rec record;
  v_books_id bigint;
begin
  for v_rec in
    select t.*
    from public.tenants t
  loop
    perform public.upsert_profile_for_party(
      coalesce(v_rec.parent_id, v_rec.id),
      'tenant'::public.profile_party_type,
      v_rec.id,
      v_rec.name,
      null, null, '+880', null, false, null,
      coalesce(v_rec.is_active, true),
      null
    );
  end loop;

  for v_rec in
    select v.*
    from public.vendors v
  loop
    v_books_id := coalesce(
      v_rec.parent_tenant_id,
      case when v_rec.tenant_id is not null then public.resolve_parent_tenant_id(v_rec.tenant_id) end
    );
    if v_books_id is null then
      continue;
    end if;
    perform public.upsert_profile_for_party(
      v_books_id,
      'vendor'::public.profile_party_type,
      v_rec.id,
      v_rec.name,
      v_rec.email,
      v_rec.phone,
      '+880',
      v_rec.address,
      case when v_rec.phone is null or btrim(v_rec.phone) = '' then false else true end,
      null, true, null
    );
  end loop;

  for v_rec in
    select c.*
    from public.cargo_companies c
  loop
    v_books_id := coalesce(
      v_rec.parent_tenant_id,
      case when v_rec.tenant_id is not null then public.resolve_parent_tenant_id(v_rec.tenant_id) end
    );
    if v_books_id is null then
      continue;
    end if;
    perform public.upsert_profile_for_party(
      v_books_id,
      'cargo'::public.profile_party_type,
      v_rec.id,
      v_rec.name,
      v_rec.email,
      v_rec.phone,
      '+880',
      v_rec.address,
      case when v_rec.phone is null or btrim(v_rec.phone) = '' then false else true end,
      null,
      coalesce(v_rec.is_active, true),
      null
    );
  end loop;

  for v_rec in
    select cs.*
    from public.courier_services cs
    where cs.tenant_id is not null
  loop
    v_books_id := public.resolve_parent_tenant_id(v_rec.tenant_id);
    perform public.upsert_profile_for_party(
      v_books_id,
      'courier'::public.profile_party_type,
      v_rec.wallet_entity_id,
      v_rec.name,
      null, null, '+880', null, false, null,
      coalesce(v_rec.is_active, true),
      null
    );
  end loop;
end;
$$;

grant execute on function public.upsert_profile_for_party(
  bigint,
  public.profile_party_type,
  bigint,
  text,
  text,
  text,
  text,
  text,
  boolean,
  text,
  boolean,
  timestamptz
) to authenticated;
