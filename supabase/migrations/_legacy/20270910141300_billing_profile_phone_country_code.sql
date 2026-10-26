-- billing_profiles.phone_country_code (E.164 prefix, e.g. +880).
-- Unique customer phone is books + country code + national number.

begin;

alter table public.billing_profiles
  add column if not exists phone_country_code text;

alter table public.billing_profiles
  disable trigger trg_billing_profiles_admin_email_unique_per_tenant;

update public.billing_profiles
set phone_country_code = '+880'
where phone_country_code is null or trim(phone_country_code) = '';

update public.billing_profiles bp
set phone = regexp_replace(trim(bp.phone), '[^0-9]', '', 'g')
where bp.phone is not null and trim(bp.phone) <> '';

update public.billing_profiles bp
set phone = bp.phone || '-dup-' || bp.id::text
where bp.id in (
  select id
  from (
    select
      id,
      row_number() over (
        partition by parent_tenant_id, phone_country_code, phone
        order by id
      ) as rn
    from public.billing_profiles
    where phone is not null
      and trim(phone) <> ''
  ) ranked
  where ranked.rn > 1
);

alter table public.billing_profiles
  enable trigger trg_billing_profiles_admin_email_unique_per_tenant;

alter table public.billing_profiles
  alter column phone_country_code set default '+880';

alter table public.billing_profiles
  alter column phone_country_code set not null;

drop index if exists public.billing_profiles_parent_phone_uidx;

create unique index if not exists billing_profiles_parent_phone_uidx
  on public.billing_profiles using btree (parent_tenant_id, phone_country_code, phone)
  where phone is not null and trim(phone) <> '';

create or replace function public.find_customer_create_conflict(
  p_tenant_id bigint,
  p_phone text default null,
  p_phone_country_code text default null,
  p_group_name text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
  v_phone text;
  v_code text;
  v_name text;
  v_phone_group text;
  v_name_group text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_phone := nullif(regexp_replace(trim(coalesce(p_phone, '')), '[^0-9]', '', 'g'), '');
  v_code := nullif(trim(coalesce(p_phone_country_code, '')), '');
  if v_code is not null and v_code not like '+%' then
    v_code := '+' || v_code;
  end if;
  v_name := nullif(trim(coalesce(p_group_name, '')), '');

  if v_phone is not null and v_code is not null then
    select cg.name
    into v_phone_group
    from public.billing_profiles bp
    left join public.customer_groups cg on cg.id = bp.customer_group_id
    where bp.parent_tenant_id = v_books_id
      and bp.phone_country_code = v_code
      and bp.phone = v_phone
      and (cg.id is null or cg.deleted_at is null)
    order by bp.id
    limit 1;
  end if;

  if v_name is not null then
    select cg.name
    into v_name_group
    from public.customer_groups cg
    where cg.parent_tenant_id = v_books_id
      and cg.deleted_at is null
      and lower(cg.name) = lower(v_name)
    order by cg.id
    limit 1;
  end if;

  return jsonb_build_object(
    'phone_group_name', v_phone_group,
    'name_group_name', v_name_group
  );
end;
$$;

drop function if exists public.create_customer_account(bigint, text, text, text, text, text, text);

create function public.create_customer_account(
  p_tenant_id bigint,
  p_group_name text,
  p_admin_name text default null,
  p_admin_email text default null,
  p_phone text default null,
  p_address text default null,
  p_accent_color text default '#B45F34',
  p_phone_country_code text default '+880'
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
  v_clean_code text;
  v_clean_group_name text;
  v_clean_color text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not public.can_administer_customer_group(v_books_id) then
    raise exception 'Only parent tenant admins can create customer groups';
  end if;

  v_clean_group_name := trim(coalesce(p_group_name, ''));
  v_clean_phone := nullif(regexp_replace(trim(coalesce(p_phone, '')), '[^0-9]', '', 'g'), '');
  v_clean_code := coalesce(nullif(trim(coalesce(p_phone_country_code, '')), ''), '+880');
  if v_clean_code not like '+%' then
    v_clean_code := '+' || v_clean_code;
  end if;
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
      and bp.phone_country_code = v_clean_code
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
      phone_country_code,
      created_at,
      updated_at
    ) values (
      v_books_id,
      v_books_id,
      v_group.id,
      v_clean_group_name,
      v_clean_phone,
      v_clean_code,
      now(),
      now()
    )
    returning * into v_billing_profile;
  else
    update public.billing_profiles
    set
      name = v_clean_group_name,
      phone = v_clean_phone,
      phone_country_code = v_clean_code,
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
    'phone', concat_ws(' ', v_billing_profile.phone_country_code, v_billing_profile.phone),
    'address', v_billing_profile.address,
    'accent_color', coalesce(v_group.accent_color, '#B45F34'),
    'is_active', v_group.is_active,
    'member_count', 0,
    'wallet_available_balance', 0,
    'created_at', v_group.created_at
  );
end;
$$;

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
    nullif(concat_ws(' ', bp.phone_country_code, bp.phone), '') as phone,
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
      or bp.phone_country_code ilike '%' || trim(p_search) || '%'
      or bp.address ilike '%' || trim(p_search) || '%'
    )
  order by cg.id desc;
end;
$$;

grant all on function public.find_customer_create_conflict(bigint, text, text, text) to authenticated;
grant all on function public.create_customer_account(bigint, text, text, text, text, text, text, text) to authenticated;
grant all on function public.list_customer_accounts(bigint, text) to authenticated;

commit;
