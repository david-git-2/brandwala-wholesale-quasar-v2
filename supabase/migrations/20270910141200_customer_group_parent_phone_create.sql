-- Customer groups: parent_tenant_id + deleted_at.
-- Billing profiles: books parent_tenant_id, unique phone, at most one row per group.
-- Create customer: group name + phone → group + profile + wallet.
-- tenant_id is kept and synced to parent_tenant_id so existing RPCs / RLS still work.

begin;

-- ---------------------------------------------------------------------------
-- customer_groups
-- ---------------------------------------------------------------------------

alter table public.customer_groups
  add column if not exists parent_tenant_id bigint,
  add column if not exists deleted_at timestamptz;

update public.customer_groups cg
set parent_tenant_id = public.resolve_parent_tenant_id(cg.tenant_id)
where cg.parent_tenant_id is null;

update public.customer_groups
set tenant_id = parent_tenant_id
where tenant_id is distinct from parent_tenant_id;

alter table public.customer_groups
  alter column parent_tenant_id set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'customer_groups_parent_tenant_id_fkey'
  ) then
    alter table public.customer_groups
      add constraint customer_groups_parent_tenant_id_fkey
      foreign key (parent_tenant_id) references public.tenants(id) on delete cascade;
  end if;
end $$;

create index if not exists customer_groups_parent_tenant_id_idx
  on public.customer_groups using btree (parent_tenant_id);

create index if not exists customer_groups_parent_live_idx
  on public.customer_groups using btree (parent_tenant_id)
  where deleted_at is null;

create or replace function public.trg_customer_groups_sync_parent_tenant()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.parent_tenant_id := coalesce(
    new.parent_tenant_id,
    public.resolve_parent_tenant_id(new.tenant_id)
  );
  new.tenant_id := new.parent_tenant_id;
  return new;
end;
$$;

drop trigger if exists trg_customer_groups_sync_parent_tenant on public.customer_groups;
create trigger trg_customer_groups_sync_parent_tenant
  before insert or update of tenant_id, parent_tenant_id
  on public.customer_groups
  for each row
  execute function public.trg_customer_groups_sync_parent_tenant();

-- ---------------------------------------------------------------------------
-- billing_profiles: books id, drop color, unique group + phone
-- ---------------------------------------------------------------------------

update public.billing_profiles bp
set parent_tenant_id = public.resolve_parent_tenant_id(coalesce(bp.parent_tenant_id, bp.tenant_id))
where bp.parent_tenant_id is distinct from public.resolve_parent_tenant_id(coalesce(bp.parent_tenant_id, bp.tenant_id));

update public.billing_profiles
set parent_tenant_id = public.resolve_parent_tenant_id(tenant_id)
where parent_tenant_id is null;

drop index if exists public.billing_profiles_tenant_phone_uidx;

alter table public.billing_profiles
  disable trigger trg_billing_profiles_admin_email_unique_per_tenant;

update public.billing_profiles
set tenant_id = parent_tenant_id
where tenant_id is distinct from parent_tenant_id;

alter table public.billing_profiles
  enable trigger trg_billing_profiles_admin_email_unique_per_tenant;

alter table public.billing_profiles
  alter column parent_tenant_id set not null;

create or replace function public.trg_billing_profiles_sync_parent_tenant()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.parent_tenant_id := coalesce(
    new.parent_tenant_id,
    public.resolve_parent_tenant_id(new.tenant_id)
  );
  new.tenant_id := new.parent_tenant_id;
  return new;
end;
$$;

drop trigger if exists trg_billing_profiles_sync_parent_tenant on public.billing_profiles;
create trigger trg_billing_profiles_sync_parent_tenant
  before insert or update of tenant_id, parent_tenant_id
  on public.billing_profiles
  for each row
  execute function public.trg_billing_profiles_sync_parent_tenant();

-- Unique per group when data is already 1:1. Skip if historical duplicates remain.
do $$
begin
  if not exists (
    select 1
    from public.billing_profiles
    where customer_group_id is not null
    group by customer_group_id
    having count(*) > 1
  ) then
    create unique index if not exists billing_profiles_customer_group_id_uidx
      on public.billing_profiles using btree (customer_group_id)
      where customer_group_id is not null;
  else
    raise notice 'Skipped billing_profiles_customer_group_id_uidx: duplicate profiles per group exist';
  end if;
end $$;

-- Duplicate phones under the same books tenant: keep first, suffix the rest.
update public.billing_profiles bp
set phone = trim(bp.phone) || '-dup-' || bp.id::text
where bp.id in (
  select id
  from (
    select
      id,
      row_number() over (
        partition by parent_tenant_id, trim(phone)
        order by id
      ) as rn
    from public.billing_profiles
    where phone is not null
      and trim(phone) <> ''
  ) ranked
  where ranked.rn > 1
);

create unique index if not exists billing_profiles_parent_phone_uidx
  on public.billing_profiles using btree (parent_tenant_id, phone)
  where phone is not null and trim(phone) <> '';

-- color stays for one-off billing UI until that screen uses group accent.

-- ---------------------------------------------------------------------------
-- Auto profile on group insert (name only; create RPC fills phone)
-- ---------------------------------------------------------------------------

create or replace function public.trg_auto_create_billing_profile_for_customer_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
begin
  v_books_id := coalesce(new.parent_tenant_id, public.resolve_parent_tenant_id(new.tenant_id));

  if not exists (
    select 1
    from public.billing_profiles
    where customer_group_id = new.id
  ) then
    insert into public.billing_profiles (
      tenant_id,
      parent_tenant_id,
      customer_group_id,
      name,
      email,
      phone,
      address,
      created_at,
      updated_at
    )
    values (
      v_books_id,
      v_books_id,
      new.id,
      new.name,
      null,
      null,
      null,
      now(),
      now()
    );
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.can_manage_customer_group_member(p_customer_group_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.customer_groups cg
    where cg.id = p_customer_group_id
      and public.can_manage_customer_group(coalesce(cg.parent_tenant_id, cg.tenant_id))
  );
$$;

-- ---------------------------------------------------------------------------
-- List / create
-- ---------------------------------------------------------------------------

create or replace function public.list_customer_accounts(
  p_tenant_id bigint,
  p_search text default null
)
returns table (
  id bigint,
  customer_group_id bigint,
  billing_profile_id bigint,
  group_name text,
  admin_name text,
  email text,
  phone text,
  address text,
  accent_color text,
  is_active boolean,
  member_count bigint,
  wallet_available_balance numeric,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  select
    cg.id,
    cg.id as customer_group_id,
    bp.id as billing_profile_id,
    cg.name as group_name,
    coalesce(bp.name, cg.name) as admin_name,
    bp.email,
    bp.phone,
    bp.address,
    coalesce(cg.accent_color, '#B45F34') as accent_color,
    cg.is_active,
    coalesce(mem.cnt, 0::bigint) as member_count,
    coalesce(wa.available_balance, 0.00) as wallet_available_balance,
    cg.created_at
  from public.customer_groups cg
  left join public.billing_profiles bp
    on bp.customer_group_id = cg.id
   and bp.parent_tenant_id = v_books_id
  left join (
    select cgm.customer_group_id as c_group_id, count(*) as cnt
    from public.customer_group_members cgm
    group by cgm.customer_group_id
  ) mem on mem.c_group_id = cg.id
  left join public.wallet_accounts wa
    on wa.parent_tenant_id = v_books_id
   and wa.entity_type = 'customer'
   and wa.entity_id = bp.id
   and wa.currency_code = 'BDT'
  where cg.parent_tenant_id = v_books_id
    and cg.deleted_at is null
    and (
      p_search is null
      or trim(p_search) = ''
      or cg.name ilike '%' || trim(p_search) || '%'
      or bp.name ilike '%' || trim(p_search) || '%'
      or bp.email ilike '%' || trim(p_search) || '%'
      or bp.phone ilike '%' || trim(p_search) || '%'
      or bp.address ilike '%' || trim(p_search) || '%'
    )
  order by cg.id desc;
end;
$$;

create or replace function public.create_customer_account(
  p_tenant_id bigint,
  p_group_name text,
  p_admin_name text,
  p_admin_email text default null,
  p_phone text default null,
  p_address text default null,
  p_accent_color text default '#B45F34'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group public.customer_groups;
  v_billing_profile public.billing_profiles;
  v_books_id bigint;
  v_clean_phone text;
  v_clean_group_name text;
  v_clean_color text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not public.can_administer_customer_group(v_books_id) then
    raise exception 'Only parent tenant admins can create customer groups';
  end if;

  v_clean_group_name := trim(coalesce(p_group_name, ''));
  v_clean_phone := nullif(trim(coalesce(p_phone, '')), '');
  v_clean_color := coalesce(nullif(trim(coalesce(p_accent_color, '')), ''), '#B45F34');

  if v_clean_group_name = '' then
    raise exception 'Group / Company name is required';
  end if;
  if v_clean_phone is null then
    raise exception 'Phone is required';
  end if;

  if exists (
    select 1
    from public.billing_profiles bp
    where bp.parent_tenant_id = v_books_id
      and bp.phone = v_clean_phone
  ) then
    raise exception 'This phone is already used by another customer';
  end if;

  insert into public.customer_groups (
    tenant_id,
    parent_tenant_id,
    name,
    accent_color,
    is_active
  ) values (
    v_books_id,
    v_books_id,
    v_clean_group_name,
    v_clean_color,
    true
  )
  returning * into v_group;

  select * into v_billing_profile
  from public.billing_profiles
  where customer_group_id = v_group.id
  order by id asc
  limit 1;

  if v_billing_profile.id is null then
    insert into public.billing_profiles (
      tenant_id,
      parent_tenant_id,
      customer_group_id,
      name,
      phone,
      created_at,
      updated_at
    ) values (
      v_books_id,
      v_books_id,
      v_group.id,
      v_clean_group_name,
      v_clean_phone,
      now(),
      now()
    )
    returning * into v_billing_profile;
  else
    update public.billing_profiles
    set
      name = v_clean_group_name,
      phone = v_clean_phone,
      parent_tenant_id = v_books_id,
      tenant_id = v_books_id,
      updated_at = now()
    where id = v_billing_profile.id
    returning * into v_billing_profile;
  end if;

  insert into public.wallet_accounts (
    tenant_id,
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    locked_balance,
    pending_balance
  ) values (
    v_books_id,
    v_books_id,
    'customer',
    v_billing_profile.id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

  return jsonb_build_object(
    'id', v_group.id,
    'customer_group_id', v_group.id,
    'billing_profile_id', v_billing_profile.id,
    'group_name', v_group.name,
    'admin_name', v_billing_profile.name,
    'email', v_billing_profile.email,
    'phone', v_billing_profile.phone,
    'address', v_billing_profile.address,
    'accent_color', coalesce(v_group.accent_color, '#B45F34'),
    'is_active', v_group.is_active,
    'member_count', 0,
    'wallet_available_balance', 0,
    'created_at', v_group.created_at
  );
end;
$$;

grant all on function public.list_customer_accounts(bigint, text) to authenticated;
grant all on function public.create_customer_account(bigint, text, text, text, text, text, text) to authenticated;

commit;
