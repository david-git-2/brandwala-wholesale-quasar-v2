-- Soft-delete customer groups (deleted_at). Keep billing profile, wallet, members.
-- Free the phone unique slot so a new customer can reuse the number.

begin;

alter table public.billing_profiles
  add column if not exists is_phone_unique boolean not null default true;

update public.billing_profiles bp
set is_phone_unique = false
from public.customer_groups cg
where bp.customer_group_id = cg.id
  and cg.deleted_at is not null
  and bp.is_phone_unique is distinct from false;

drop index if exists public.billing_profiles_parent_phone_uidx;

create unique index if not exists billing_profiles_parent_phone_uidx
  on public.billing_profiles using btree (parent_tenant_id, phone_country_code, phone)
  where phone is not null
    and btrim(phone) <> ''
    and is_phone_unique;

create or replace function public.trg_customer_groups_soft_delete_phone_unique()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    update public.billing_profiles
    set is_phone_unique = false
    where customer_group_id = new.id;
  elsif new.deleted_at is null and old.deleted_at is not null then
    update public.billing_profiles
    set is_phone_unique = true
    where customer_group_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_customer_groups_soft_delete_phone_unique on public.customer_groups;
create trigger trg_customer_groups_soft_delete_phone_unique
  after update of deleted_at on public.customer_groups
  for each row
  execute function public.trg_customer_groups_soft_delete_phone_unique();

create or replace function public.delete_customer_group(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
  v_deleted_at timestamptz;
begin
  select coalesce(cg.parent_tenant_id, cg.tenant_id), cg.deleted_at
  into v_books_id, v_deleted_at
  from public.customer_groups cg
  where cg.id = p_id;

  if v_books_id is null then
    raise exception 'Customer group not found';
  end if;

  if not public.can_administer_customer_group(v_books_id) then
    raise exception 'Only parent tenant admins can delete customer groups';
  end if;

  if v_deleted_at is not null then
    return;
  end if;

  update public.customer_groups
  set
    deleted_at = now(),
    is_active = false,
    updated_at = now()
  where id = p_id
    and deleted_at is null;
end;
$$;

revoke all on function public.delete_customer_group(bigint) from public;
grant execute on function public.delete_customer_group(bigint) to authenticated;

create or replace function public.create_customer_account(
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
    left join public.customer_groups cg on cg.id = bp.customer_group_id
    where bp.parent_tenant_id = v_books_id
      and bp.phone_country_code = v_clean_code
      and bp.phone = v_clean_phone
      and bp.is_phone_unique
      and (cg.id is null or cg.deleted_at is null)
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

commit;
