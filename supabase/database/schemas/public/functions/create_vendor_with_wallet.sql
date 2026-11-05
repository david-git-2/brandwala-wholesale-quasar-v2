CREATE FUNCTION public.create_vendor_with_wallet (
  p_tenant_id     bigint,
  p_name          text,
  p_code          text,
  p_market_code   text,
  p_email         text   DEFAULT NULL::text,
  p_phone         text   DEFAULT NULL::text,
  p_address       text   DEFAULT NULL::text,
  p_website       text   DEFAULT NULL::text,
  p_currency_code text   DEFAULT 'BDT'::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_vendor public.vendors%rowtype;
  v_wallet public.cashbook_accounts%rowtype;
  v_currency_code text := coalesce(nullif(trim(p_currency_code), ''), 'BDT');
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

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

  if exists (
    select 1 from public.tenants t where t.id = p_tenant_id and t.parent_id is not null
  ) then
    raise exception 'vendors belong on parent tenants only';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  if nullif(trim(p_code), '') is null then
    raise exception 'code is required';
  end if;

  if upper(trim(p_code)) = 'DEFAULT' then
    raise exception 'code DEFAULT is reserved for the system default vendor';
  end if;

  if nullif(trim(p_market_code), '') is null then
    raise exception 'market_code is required';
  end if;

  if exists (
    select 1
    from public.vendors v
    where v.parent_tenant_id = p_tenant_id
      and upper(trim(v.code)) = upper(trim(p_code))
  ) then
    raise exception 'vendor code % already exists for this tenant', upper(trim(p_code));
  end if;

  if p_email is not null and trim(p_email) <> '' then
    if exists (
      select 1
      from public.vendors v
      where v.parent_tenant_id = p_tenant_id
        and lower(trim(v.email)) = lower(trim(p_email))
    ) then
      raise exception 'vendor email % already exists for this tenant', lower(trim(p_email));
    end if;
  end if;

  insert into public.vendors (
    parent_tenant_id,
    name,
    code,
    market_code,
    email,
    phone,
    address,
    website
  )
  values (
    p_tenant_id,
    trim(p_name),
    upper(trim(p_code)),
    upper(trim(p_market_code)),
    nullif(lower(trim(p_email)), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_website), '')
  )
  returning * into v_vendor;

  insert into public.cashbook_accounts (
    tenant_id,
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    coalesce(v_vendor.parent_tenant_id, p_tenant_id),
    'vendor',
    v_vendor.id,
    v_currency_code,
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now()
  returning * into v_wallet;

  return jsonb_build_object(
    'vendor', to_jsonb(v_vendor),
    'wallet', to_jsonb(v_wallet)
  );
end;
$function$;

CREATE FUNCTION public.create_vendor_with_wallet (
  p_tenant_id   bigint,
  p_name        text,
  p_code        text,
  p_market_code text,
  p_email       text   DEFAULT NULL::text,
  p_phone       text   DEFAULT NULL::text,
  p_address     text   DEFAULT NULL::text,
  p_website     text   DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_vendor public.vendors;
  v_wallet public.cashbook_accounts;
  v_currency_code text := 'BDT';
  v_books_id bigint;
begin
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;
    v_books_id := null;
  else
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
    v_books_id := p_tenant_id;
  end if;

  insert into public.vendors (
    parent_tenant_id,
    name,
    code,
    market_code,
    email,
    phone,
    address,
    website
  )
  values (
    v_books_id,
    trim(p_name),
    upper(trim(p_code)),
    upper(trim(p_market_code)),
    nullif(lower(trim(p_email)), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_website), '')
  )
  returning * into v_vendor;

  if v_books_id is not null then
    insert into public.cashbook_accounts (
      tenant_id,
      entity_type,
      entity_id,
      currency_code,
      available_balance,
      pending_balance,
      locked_balance
    )
    values (
      v_books_id,
      'vendor',
      v_vendor.id,
      v_currency_code,
      0.0000,
      0.0000,
      0.0000
    )
    on conflict (tenant_id, entity_type, entity_id, currency_code)
    do update set updated_at = now()
    returning * into v_wallet;
  end if;

  return jsonb_build_object(
    'vendor', to_jsonb(v_vendor),
    'wallet', to_jsonb(v_wallet)
  );
end;
$function$;

GRANT ALL ON FUNCTION public.create_vendor_with_wallet(bigint, text, text, text, text, text, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.create_vendor_with_wallet(bigint, text, text, text, text, text, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.create_vendor_with_wallet(bigint, text, text, text, text, text, text, text, text) TO service_role;

GRANT ALL ON FUNCTION public.create_vendor_with_wallet(bigint, text, text, text, text, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.create_vendor_with_wallet(bigint, text, text, text, text, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.create_vendor_with_wallet(bigint, text, text, text, text, text, text, text) TO service_role;