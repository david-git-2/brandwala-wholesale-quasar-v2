-- ====================================================================
-- Migration: Atomic Create Customer RPC & Customer List View / Function
-- Provisions: Customer Group, Admin Member, Billing Profile, Wallet Account
-- ====================================================================

begin;

-- 1. Atomic Create Customer Function
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
  -- Validate inputs
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

  -- 1. Insert Customer Group
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

  -- 2. Insert Admin Member if email provided
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
    )
    on conflict (customer_group_id, email) do update set
      name = excluded.name,
      role = excluded.role,
      is_active = true;
  end if;

  -- 3. Upsert Billing Profile linked to this Customer Group
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

  -- In case trigger or concurrent insert created it
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

  -- 4. Ensure Wallet Account exists for the billing profile
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

  -- Return combined result payload
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

-- 2. Customer List Query RPC
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
begin
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
    coalesce(cg.accent_color, bp.color, '#B45F34') as accent_color,
    cg.is_active,
    coalesce(mem.cnt, 0::bigint) as member_count,
    coalesce(wa.available_balance, 0.00) as wallet_available_balance,
    cg.created_at
  from public.customer_groups cg
  left join public.billing_profiles bp
    on bp.customer_group_id = cg.id and bp.tenant_id = p_tenant_id
  left join (
    select cgm.customer_group_id as c_group_id, count(*) as cnt
    from public.customer_group_members cgm
    group by cgm.customer_group_id
  ) mem on mem.c_group_id = cg.id
  left join public.wallet_accounts wa
    on wa.tenant_id = p_tenant_id
   and wa.entity_type = 'customer'
   and wa.entity_id = bp.id
   and wa.currency_code = 'BDT'
  where cg.tenant_id = p_tenant_id
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

grant all on function public.create_customer_account(bigint, text, text, text, text, text, text) to authenticated;
grant all on function public.list_customer_accounts(bigint, text) to authenticated;

commit;
