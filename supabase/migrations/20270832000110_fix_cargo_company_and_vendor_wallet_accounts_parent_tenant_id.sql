-- Fix null value in parent_tenant_id of relation wallet_accounts on create_cargo_company_with_wallet,
-- ensure_default_cargo_company, create_vendor_with_wallet, and ensure_default_vendor.

CREATE OR REPLACE FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_notes" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.cargo_companies;
  v_wallet public.wallet_accounts;
  v_code text;
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
    raise exception 'cargo companies belong on parent tenants only';
  end if;

  v_code := upper(trim(p_code));
  if v_code is null or v_code = '' then
    raise exception 'code is required';
  end if;

  if v_code = 'DEFAULT' then
    raise exception 'code DEFAULT is reserved for the system default cargo company';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  insert into public.cargo_companies (
    tenant_id,
    parent_tenant_id,
    name,
    code,
    email,
    phone,
    address,
    notes,
    is_default,
    is_active
  )
  values (
    p_tenant_id,
    p_tenant_id,
    trim(p_name),
    v_code,
    nullif(lower(trim(p_email)), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_notes), ''),
    false,
    true
  )
  returning * into v_row;

  insert into public.wallet_accounts (
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
    p_tenant_id,
    'cargo_company',
    v_row.id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now()
  returning * into v_wallet;

  return jsonb_build_object(
    'cargo_company', to_jsonb(v_row),
    'wallet', to_jsonb(v_wallet)
  );
end;
$$;

ALTER FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_notes" "text") OWNER TO "postgres";
REVOKE ALL ON FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_notes" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_notes" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_notes" "text") TO "service_role";


CREATE OR REPLACE FUNCTION "public"."ensure_default_cargo_company"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant public.tenants%rowtype;
  v_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  if v_tenant.parent_id is not null then
    raise exception 'ensure_default_cargo_company requires a parent tenant (got child %)', p_tenant_id;
  end if;

  if auth.uid() is not null then
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
  end if;

  select id into v_id
  from public.cargo_companies
  where tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_id is not null then
    return v_id;
  end if;

  select id into v_id
  from public.cargo_companies
  where tenant_id = p_tenant_id
    and upper(trim(code)) = 'DEFAULT'
  limit 1;

  if v_id is not null then
    update public.cargo_companies
    set is_default = true,
        name = coalesce(nullif(trim(name), ''), 'Default Cargo Company'),
        parent_tenant_id = coalesce(parent_tenant_id, p_tenant_id),
        is_active = true,
        updated_at = now()
    where id = v_id;
    return v_id;
  end if;

  insert into public.cargo_companies (
    tenant_id,
    parent_tenant_id,
    name,
    code,
    is_default,
    is_active
  )
  values (
    p_tenant_id,
    p_tenant_id,
    'Default Cargo Company',
    'DEFAULT',
    true,
    true
  )
  returning id into v_id;

  insert into public.wallet_accounts (
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
    p_tenant_id,
    'cargo_company',
    v_id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now();

  return v_id;
end;
$$;

ALTER FUNCTION "public"."ensure_default_cargo_company"("p_tenant_id" bigint) OWNER TO "postgres";
REVOKE ALL ON FUNCTION "public"."ensure_default_cargo_company"("p_tenant_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ensure_default_cargo_company"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_default_cargo_company"("p_tenant_id" bigint) TO "service_role";


CREATE OR REPLACE FUNCTION "public"."create_vendor_with_wallet"(
  "p_tenant_id" bigint,
  "p_name" "text",
  "p_code" "text",
  "p_market_code" "text",
  "p_email" "text" DEFAULT NULL::"text",
  "p_phone" "text" DEFAULT NULL::"text",
  "p_address" "text" DEFAULT NULL::"text",
  "p_website" "text" DEFAULT NULL::"text",
  "p_currency_code" "text" DEFAULT 'BDT'::"text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_vendor public.vendors%rowtype;
  v_wallet public.wallet_accounts%rowtype;
  v_currency_code text := coalesce(nullif(trim(p_currency_code), ''), 'BDT');
begin
  -- 1. Validation and Authorization
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
    where v.tenant_id = p_tenant_id
      and upper(trim(v.code)) = upper(trim(p_code))
  ) then
    raise exception 'vendor code % already exists for this tenant', upper(trim(p_code));
  end if;

  if p_email is not null and trim(p_email) <> '' then
    if exists (
      select 1
      from public.vendors v
      where v.tenant_id = p_tenant_id
        and lower(trim(v.email)) = lower(trim(p_email))
    ) then
      raise exception 'vendor email % already exists for this tenant', lower(trim(p_email));
    end if;
  end if;

  -- 2. Insert vendor record
  insert into public.vendors (
    tenant_id,
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

  -- 3. Create or fetch wallet_accounts anchor for vendor (Default BDT)
  insert into public.wallet_accounts (
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

  -- 4. Return JSON payload matching documentation specification
  return jsonb_build_object(
    'vendor', to_jsonb(v_vendor),
    'wallet', to_jsonb(v_wallet)
  );
end;
$$;

ALTER FUNCTION "public"."create_vendor_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_market_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_website" "text", "p_currency_code" "text") OWNER TO "postgres";
REVOKE ALL ON FUNCTION "public"."create_vendor_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_market_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_website" "text", "p_currency_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_vendor_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_market_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_website" "text", "p_currency_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_vendor_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_market_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_website" "text", "p_currency_code" "text") TO "service_role";


CREATE OR REPLACE FUNCTION "public"."ensure_default_vendor"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant public.tenants%rowtype;
  v_vendor_id bigint;
  v_market_code text;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  if v_tenant.parent_id is not null then
    raise exception 'ensure_default_vendor requires a parent tenant (got child %)', p_tenant_id;
  end if;

  if auth.uid() is not null then
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
  end if;

  select id into v_vendor_id
  from public.vendors
  where tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_vendor_id is not null then
    return v_vendor_id;
  end if;

  select id into v_vendor_id
  from public.vendors
  where tenant_id = p_tenant_id
    and upper(trim(code)) = 'DEFAULT'
  limit 1;

  if v_vendor_id is not null then
    update public.vendors
    set is_default = true,
        name = coalesce(nullif(trim(name), ''), 'Default Vendor'),
        is_active = true,
        updated_at = now()
    where id = v_vendor_id;
    return v_vendor_id;
  end if;

  select upper(trim(code)) into v_market_code
  from public.global_markets
  where is_active = true
  order by id asc
  limit 1;

  if v_market_code is null or v_market_code = '' then
    v_market_code := 'BD';
  end if;

  insert into public.vendors (
    tenant_id,
    name,
    code,
    market_code,
    is_default
  )
  values (
    p_tenant_id,
    'Default Vendor',
    'DEFAULT',
    v_market_code,
    true
  )
  returning id into v_vendor_id;

  -- Mirror create_vendor_with_wallet: zero BDT wallet anchor
  insert into public.wallet_accounts (
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
    p_tenant_id,
    'vendor',
    v_vendor_id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now();

  return v_vendor_id;
end;
$$;

ALTER FUNCTION "public"."ensure_default_vendor"("p_tenant_id" bigint) OWNER TO "postgres";
REVOKE ALL ON FUNCTION "public"."ensure_default_vendor"("p_tenant_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ensure_default_vendor"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_default_vendor"("p_tenant_id" bigint) TO "service_role";
