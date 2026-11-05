CREATE FUNCTION public.create_customer_account (
  p_tenant_id          bigint,
  p_group_name         text,
  p_admin_name         text   DEFAULT NULL::text,
  p_admin_email        text   DEFAULT NULL::text,
  p_phone              text   DEFAULT NULL::text,
  p_address            text   DEFAULT NULL::text,
  p_accent_color       text   DEFAULT '#B45F34'::text,
  p_phone_country_code text   DEFAULT '+880'::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_group public.customer_groups;
  v_profile public.profiles;
  v_profile_id bigint;
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
    from public.profiles pr
    left join public.customer_groups cg on cg.id = pr.customer_group_id
    where pr.profile_type = 'customer'::public.profile_party_type
      and pr.parent_tenant_id = v_books_id
      and pr.phone_country_code = v_clean_code
      and pr.phone = v_clean_phone
      and pr.is_phone_unique
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

  select * into v_profile
  from public.profiles
  where customer_group_id = v_group.id
    and profile_type = 'customer'::public.profile_party_type
  order by id asc
  limit 1;

  if v_profile.id is null then
    insert into public.profiles (
      parent_tenant_id,
      profile_type,
      subject_id,
      customer_group_id,
      operating_tenant_id,
      name,
      phone,
      phone_country_code,
      address,
      accent_color,
      is_active,
      created_at,
      updated_at
    ) values (
      v_books_id,
      'customer'::public.profile_party_type,
      v_group.id,
      v_group.id,
      v_books_id,
      v_clean_group_name,
      v_clean_phone,
      v_clean_code,
      nullif(trim(coalesce(p_address, '')), ''),
      v_clean_color,
      true,
      now(),
      now()
    )
    returning * into v_profile;

    update public.profiles
    set subject_id = v_profile.id
    where id = v_profile.id;
  else
    update public.profiles
    set
      name = v_clean_group_name,
      phone = v_clean_phone,
      phone_country_code = v_clean_code,
      parent_tenant_id = v_books_id,
      operating_tenant_id = v_books_id,
      address = coalesce(nullif(trim(coalesce(p_address, '')), ''), address),
      updated_at = now()
    where id = v_profile.id
    returning * into v_profile;
  end if;

  insert into public.cashbook_accounts (
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
    v_profile.id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

  return jsonb_build_object(
    'id', v_group.id,
    'customer_group_id', v_group.id,
    'profile_id', v_profile.id,
    'group_name', v_group.name,
    'admin_name', v_profile.name,
    'email', v_profile.email,
    'phone', concat_ws(' ', v_profile.phone_country_code, v_profile.phone),
    'address', v_profile.address,
    'accent_color', coalesce(v_group.accent_color, '#B45F34'),
    'is_active', v_group.is_active,
    'member_count', 0,
    'wallet_available_balance', 0,
    'created_at', v_group.created_at
  );
end;
$function$;

GRANT ALL ON FUNCTION public.create_customer_account(bigint, text, text, text, text, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.create_customer_account(bigint, text, text, text, text, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.create_customer_account(bigint, text, text, text, text, text, text, text) TO service_role;