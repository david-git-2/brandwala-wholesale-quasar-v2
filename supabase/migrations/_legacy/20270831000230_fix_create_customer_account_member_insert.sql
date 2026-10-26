-- Fix 42P10: ON CONFLICT (customer_group_id, email) does not match
-- unique index customer_group_members_group_email_unique
-- (customer_group_id, lower(trim(email))). Create is a new group, so insert only.

begin;

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
  v_clean_email text;
  v_clean_phone text;
  v_clean_address text;
  v_clean_color text;
  v_clean_group_name text;
  v_clean_admin_name text;
begin
  v_clean_group_name := trim(coalesce(p_group_name, ''));
  v_clean_admin_name := trim(coalesce(p_admin_name, ''));
  if v_clean_group_name = '' then
    raise exception 'Group / Company name is required';
  end if;
  if v_clean_admin_name = '' then
    raise exception 'Primary contact / Admin name is required';
  end if;

  v_clean_email := nullif(lower(trim(coalesce(p_admin_email, ''))), '');
  v_clean_phone := nullif(trim(coalesce(p_phone, '')), '');
  v_clean_address := nullif(trim(coalesce(p_address, '')), '');
  v_clean_color := coalesce(nullif(trim(coalesce(p_accent_color, '')), ''), '#B45F34');

  insert into public.customer_groups (
    tenant_id,
    name,
    accent_color,
    is_active
  ) values (
    p_tenant_id,
    v_clean_group_name,
    v_clean_color,
    true
  )
  returning * into v_group;

  if v_clean_email is not null then
    insert into public.customer_group_members (
      customer_group_id,
      name,
      email,
      role,
      is_active
    ) values (
      v_group.id,
      v_clean_admin_name,
      v_clean_email,
      'admin',
      true
    );
  end if;

  insert into public.billing_profiles (
    tenant_id,
    customer_group_id,
    name,
    email,
    phone,
    address,
    color,
    created_at,
    updated_at
  ) values (
    p_tenant_id,
    v_group.id,
    v_clean_admin_name,
    v_clean_email,
    v_clean_phone,
    v_clean_address,
    v_clean_color,
    now(),
    now()
  )
  on conflict (id) do nothing
  returning * into v_billing_profile;

  if v_billing_profile.id is null then
    select * into v_billing_profile
    from public.billing_profiles
    where tenant_id = p_tenant_id and customer_group_id = v_group.id
    order by id asc limit 1;

    update public.billing_profiles
    set
      name = v_clean_admin_name,
      email = v_clean_email,
      phone = v_clean_phone,
      address = v_clean_address,
      color = v_clean_color,
      updated_at = now()
    where id = v_billing_profile.id
    returning * into v_billing_profile;
  end if;

  insert into public.wallet_accounts (
    tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    locked_balance,
    pending_balance
  ) values (
    p_tenant_id,
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
    'accent_color', v_group.accent_color,
    'is_active', v_group.is_active,
    'created_at', v_group.created_at
  );
end;
$$;

grant all on function public.create_customer_account(bigint, text, text, text, text, text, text) to authenticated;

commit;
