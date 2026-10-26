-- Customer groups + billing profiles live on parent / books tenant.
-- list_customer_accounts and admin-email conflict checks use books scope only.

begin;

create or replace function public.find_customer_admin_email_conflict(
  p_tenant_id bigint,
  p_email text,
  p_exclude_billing_profile_id bigint default null,
  p_exclude_member_id bigint default null,
  p_exclude_customer_group_id bigint default null
)
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  v_books_id bigint;
  v_normalized_email text;
  v_group_name text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  v_normalized_email := nullif(lower(trim(coalesce(p_email, ''))), '');
  if v_normalized_email is null then
    return null;
  end if;

  select cg.name
  into v_group_name
  from public.billing_profiles bp
  join public.customer_groups cg on cg.id = bp.customer_group_id
  where bp.tenant_id = v_books_id
    and cg.tenant_id = v_books_id
    and lower(trim(bp.email)) = v_normalized_email
    and bp.id <> coalesce(p_exclude_billing_profile_id, -1)
    and cg.id <> coalesce(p_exclude_customer_group_id, -1)
  order by cg.id asc
  limit 1;

  if v_group_name is not null then
    return v_group_name;
  end if;

  select cg.name
  into v_group_name
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where cg.tenant_id = v_books_id
    and cgm.role = 'admin'::public.customer_group_role
    and lower(trim(cgm.email)) = v_normalized_email
    and cgm.id <> coalesce(p_exclude_member_id, -1)
    and cg.id <> coalesce(p_exclude_customer_group_id, -1)
  order by cg.id asc
  limit 1;

  return v_group_name;
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
    bp.phone,
    bp.address,
    coalesce(cg.accent_color, bp.color, '#B45F34') as accent_color,
    cg.is_active,
    coalesce(mem.cnt, 0::bigint) as member_count,
    coalesce(wa.available_balance, 0.00) as wallet_available_balance,
    cg.created_at
  from public.customer_groups cg
  left join public.billing_profiles bp
    on bp.customer_group_id = cg.id
   and bp.tenant_id = v_books_id
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
  where cg.tenant_id = v_books_id
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
  v_clean_email text;
  v_clean_phone text;
  v_clean_address text;
  v_clean_color text;
  v_clean_group_name text;
  v_clean_admin_name text;
  v_conflict_group_name text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

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

  if v_clean_email is not null then
    v_conflict_group_name := public.find_customer_admin_email_conflict(
      v_books_id,
      v_clean_email
    );
    if v_conflict_group_name is not null then
      raise exception 'This email is already admin of group "%".', v_conflict_group_name;
    end if;
  end if;

  insert into public.customer_groups (
    tenant_id,
    name,
    accent_color,
    is_active
  ) values (
    v_books_id,
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
    parent_tenant_id,
    customer_group_id,
    name,
    email,
    phone,
    address,
    color,
    created_at,
    updated_at
  ) values (
    v_books_id,
    v_books_id,
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
    where tenant_id = v_books_id
      and customer_group_id = v_group.id
    order by id asc
    limit 1;

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
    'accent_color', v_group.accent_color,
    'is_active', v_group.is_active,
    'created_at', v_group.created_at
  );
end;
$$;

grant all on function public.list_customer_accounts(bigint, text) to authenticated;
grant all on function public.create_customer_account(bigint, text, text, text, text, text, text) to authenticated;

commit;
