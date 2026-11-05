-- Phase 4d: drop parent_tenant_id on cashbook_accounts, cashbook_entries, invoice_write_offs.

CREATE OR REPLACE FUNCTION "public"."apply_global_invoice_settlement_discount"("p_invoice_id" bigint, "p_amount" numeric, "p_note" "text" DEFAULT NULL::"text") RETURNS "public"."bills"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_parent_id bigint;
  v_operating_tenant_id bigint;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'cannot settle a non-posted invoice';
  end if;
  if coalesce(p_amount, 0.00) < 0.00 then
    raise exception 'settlement amount must be 0 or greater';
  end if;
  if coalesce(p_amount, 0.00) > coalesce(v_invoice.due_amount, 0.00) then
    raise exception 'settlement amount exceeds outstanding due';
  end if;

  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.parent_tenant_id);
  v_operating_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);

  if coalesce(p_amount, 0.00) > 0.00 then
    insert into public.invoice_write_offs (
      tenant_id,
      invoice_id,
      payment_id,
      amount,
      reason,
      note,
      approved_by
    )
    values (
      v_parent_id,
      p_invoice_id,
      null,
      p_amount,
      'management_concession',
      p_note,
      auth.uid()
    );
  end if;

  if nullif(trim(p_note), '') is not null then
    update public.bills
    set
      note = coalesce(nullif(trim(p_note), ''), note),
      updated_at = now()
    where id = p_invoice_id;
  end if;

  perform public.recompute_global_invoice_payment_status(p_invoice_id);

  select * into v_invoice from public.bills where id = p_invoice_id;

  -- Record Tenant Revenue Write-Off for settlement discount
  if p_amount > 0 then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => coalesce(v_invoice.parent_tenant_id, v_invoice.parent_tenant_id),
      p_operating_tenant_id => coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id, v_invoice.parent_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => coalesce(v_invoice.parent_tenant_id, v_invoice.parent_tenant_id),
      p_type => 'debit',
      p_amount => p_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => p_invoice_id::text,
      p_metadata => jsonb_build_object(
        'section', 'settlement_discount',
        'purpose', 'settlement_discount_write_off',
        'transaction_type', 'settlement_discount',
        'label', 'Settlement Discount',
        'invoice_id', p_invoice_id,
        'invoice_no', v_invoice.invoice_no
      )
    );
  end if;

  return v_invoice;
end;
$$;


ALTER FUNCTION "public"."apply_global_invoice_settlement_discount"("p_invoice_id" bigint, "p_amount" numeric, "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_notes" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.cargo_companies;
  v_wallet public.cashbook_accounts;
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


CREATE OR REPLACE FUNCTION "public"."create_customer_account"("p_tenant_id" bigint, "p_group_name" "text", "p_admin_name" "text" DEFAULT NULL::"text", "p_admin_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_accent_color" "text" DEFAULT '#B45F34'::"text", "p_phone_country_code" "text" DEFAULT '+880'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    locked_balance,
    pending_balance
  ) values (
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
$$;


ALTER FUNCTION "public"."create_customer_account"("p_tenant_id" bigint, "p_group_name" "text", "p_admin_name" "text", "p_admin_email" "text", "p_phone" "text", "p_address" "text", "p_accent_color" "text", "p_phone_country_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_vendor_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_market_code" "text", "p_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_website" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."create_vendor_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_market_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_website" "text") OWNER TO "postgres";


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
  where parent_tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_id is not null then
    return v_id;
  end if;

  select id into v_id
  from public.cargo_companies
  where parent_tenant_id = p_tenant_id
    and upper(trim(code)) = 'DEFAULT'
  limit 1;

  if v_id is not null then
    update public.cargo_companies
    set is_default = true,
        name = coalesce(nullif(trim(name), ''), 'Default Cargo Company'),
        is_active = true,
        updated_at = now()
    where id = v_id;
    return v_id;
  end if;

  insert into public.cargo_companies (
    parent_tenant_id,
    name,
    code,
    is_default,
    is_active
  )
  values (
    p_tenant_id,
    'Default Cargo Company',
    'DEFAULT',
    true,
    true
  )
  returning id into v_id;

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
  where parent_tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_vendor_id is not null then
    return v_vendor_id;
  end if;

  select id into v_vendor_id
  from public.vendors
  where parent_tenant_id = p_tenant_id
    and upper(trim(code)) = 'DEFAULT'
  limit 1;

  if v_vendor_id is not null then
    update public.vendors
    set is_default = true,
        name = coalesce(nullif(trim(name), ''), 'Default Vendor'),
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
    parent_tenant_id,
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


CREATE OR REPLACE FUNCTION "public"."get_dropship_management_order"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_detail jsonb;
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_charge_lines jsonb;
  v_reseller_purchase_cost numeric(15,2);
  v_reseller_unit_purchase_cost numeric(15,2);
  v_order_item_quantity integer;
  v_company_procurement_cost numeric(15,2);
  v_calculated_cod numeric(15,2);
  v_collected_cod numeric(15,2);
  v_courier_name text;
  v_has_settlement boolean := false;
  v_invoice jsonb;
  v_is_returned boolean := false;
  v_gift_cost_merchant_total numeric(15,2) := 0;
  v_gift_cost_tenant_total numeric(15,2) := 0;
  v_parent_tenant_id bigint;
  v_courier_ap_bill_id bigint;
  v_courier_ap_due numeric(15,2) := 0;
  v_dropship_profit_credited numeric(15,2) := 0;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
    and tenant_id = p_tenant_id;

  if v_order.id is null then
    raise exception 'order not found';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  select coalesce(sum(ce.amount), 0)
  into v_dropship_profit_credited
  from public.cashbook_entries ce
  where ce.tenant_id = v_parent_tenant_id
    and ce.source_type = 'shop_order'
    and ce.source_id = p_order_id::text
    and ce.type = 'credit'
    and coalesce(ce.metadata->>'transaction_type', '') = 'dropship_profit';

  v_courier_ap_bill_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, v_parent_tenant_id);
  if v_courier_ap_bill_id is not null then
    v_courier_ap_due := greatest(
      coalesce((public.get_bill_net_balances(v_courier_ap_bill_id)->>'due_amount')::numeric, 0),
      0
    );
  end if;

  select
    coalesce(sum(soi.gift_cost_amount) filter (
      where coalesce(soi.is_gift, false)
        and soi.gift_source = 'stock'
        and soi.gift_cost_charged_to = 'reseller'
        and coalesce(soi.gift_cost_amount, 0) > 0
    ), 0),
    coalesce(sum(soi.gift_cost_amount) filter (
      where coalesce(soi.is_gift, false)
        and soi.gift_source = 'stock'
        and soi.gift_cost_charged_to = 'tenant'
        and coalesce(soi.gift_cost_amount, 0) > 0
    ), 0)
  into v_gift_cost_merchant_total, v_gift_cost_tenant_total
  from public.shop_order_items soi
  where soi.order_id = p_order_id;

  v_is_returned := v_order.status = 'returned'::public.shop_order_status;

  if v_order.status not in ('shipped', 'delivered', 'payment_received', 'reseller_paid', 'returned') then
    raise exception 'order status % is not eligible for dropship management desk', v_order.status;
  end if;

  v_detail := public.get_dropship_order_detail_v2(p_tenant_id, p_order_id);

  select coalesce(cs.name, v_order.courier_name)
  into v_courier_name
  from public.courier_services cs
  where cs.id::text = v_order.courier_service_id::text;

  select
    rp.reseller_unit_purchase_cost,
    rp.reseller_purchase_cost,
    rp.order_item_quantity
  into v_reseller_unit_purchase_cost, v_reseller_purchase_cost, v_order_item_quantity
  from public.compute_dropship_order_reseller_purchase(p_order_id) rp;

  select coalesce(
    sum(public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount) * soi.quantity),
    0
  )
  into v_company_procurement_cost
  from public.shop_order_items soi
  inner join public.shop_orders o on o.id = soi.order_id
  where soi.order_id = p_order_id
    and o.tenant_id = p_tenant_id;

  v_calculated_cod := coalesce(
    (v_detail->'computed'->>'recipient_grand_total')::numeric,
    (v_detail->'summary'->>'cod_collect_amount')::numeric,
    coalesce(v_order.cod_collect_amount, 0)
  );

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  v_has_settlement := found;

  v_charge_lines := public.build_dropship_management_charge_lines(
    v_order,
    case when v_has_settlement then v_settlement.id else null end
  );

  if v_has_settlement then
    v_collected_cod := v_settlement.collected_cod_amount;
  else
    v_collected_cod := coalesce(v_order.cod_collect_amount, v_calculated_cod);
  end if;

  if v_order.global_invoice_id is null then
    v_invoice := null;
  else
    select jsonb_build_object(
      'id', i.id,
      'invoice_no', i.invoice_no,
      'invoice_status', i.invoice_status,
      'payment_status', i.payment_status,
      'total_amount', i.total_amount,
      'due_amount', i.due_amount
    )
    into v_invoice
    from public.bills i
    where i.id = v_order.global_invoice_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'order', (v_detail->'order') || jsonb_build_object(
      'courier_name', v_courier_name,
      'payout_settlement_status', v_order.payout_settlement_status,
      'returned_at', v_order.returned_at,
      'return_charge_amount', coalesce(v_order.return_charge_amount, 0),
      'deduct_return_charge_from_middle_man', coalesce(v_order.deduct_return_charge_from_middle_man, false),
      'return_override_reason', v_order.return_override_reason,
      'courier_ap_bill_id', v_courier_ap_bill_id
    ),
    'items', coalesce(v_detail->'items', '[]'::jsonb),
    'fulfillment', v_detail->'fulfillment',
    'computed', (v_detail->'computed') || jsonb_build_object(
      'order_item_quantity', v_order_item_quantity
    ),
    'settlement', jsonb_build_object(
      'id', v_settlement.id,
      'status', coalesce(v_settlement.status::text, 'draft'),
      'calculated_cod_amount', coalesce(v_calculated_cod, v_settlement.calculated_cod_amount),
      'collected_cod_amount', coalesce(v_settlement.collected_cod_amount, v_collected_cod),
      'reseller_unit_purchase_cost', v_reseller_unit_purchase_cost,
      'reseller_purchase_cost', v_reseller_purchase_cost,
      'company_procurement_cost', v_company_procurement_cost,
      'discount_company_pay', coalesce(v_settlement.discount_company_pay, 0),
      'return_reason_note', coalesce(v_settlement.return_reason_note, ''),
      'charge_lines', v_charge_lines,
      'total_cost', v_settlement.total_cost,
      'reseller_profit', v_settlement.reseller_profit,
      'company_profit', v_settlement.company_profit,
      'courier_cod_booked_at', v_settlement.courier_cod_booked_at,
      'remittance_at', v_settlement.remittance_at,
      'merchant_payout_at', v_settlement.merchant_payout_at,
      'gift_cost_merchant_total', v_gift_cost_merchant_total,
      'gift_cost_tenant_total', v_gift_cost_tenant_total,
      'dropship_profit_credited', v_dropship_profit_credited,
      'courier_ap_due', v_courier_ap_due
    ),
    'invoice', v_invoice,
    'step_state', jsonb_build_object(
      'can_mark_returned',
        not v_is_returned
        and v_order.status = 'shipped'
        and (not v_has_settlement or v_settlement.courier_cod_booked_at is null),
      'can_mark_delivered',
        not v_is_returned
        and v_order.status = 'shipped'
        and (not v_has_settlement or v_settlement.courier_cod_booked_at is null),
      'can_issue_invoice',
        not v_is_returned
        and v_order.status in ('delivered', 'payment_received')
        and v_order.global_invoice_id is null,
      'can_record_bank_transfer',
        not v_is_returned
        and v_order.status in ('delivered', 'payment_received')
        and (not v_has_settlement or v_settlement.remittance_at is null),
      'can_transfer_to_reseller',
        not v_is_returned
        and v_order.status in ('delivered', 'payment_received')
        and (not v_has_settlement or v_settlement.status is distinct from 'confirmed')
        and (not v_has_settlement or v_settlement.merchant_payout_at is null)
    )
  );
end;
$$;


ALTER FUNCTION "public"."get_dropship_management_order"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_cashbook_ledger_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_operating_tenant_id" bigint DEFAULT NULL::bigint, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" "uuid", "parent_tenant_id" bigint, "operating_tenant_id" bigint, "entity_type" "text", "entity_id" bigint, "type" "text", "amount" numeric, "currency_code" "text", "exchange_rate" numeric, "base_amount" numeric, "balance_after" numeric, "source_type" "text", "source_id" "text", "metadata" "jsonb", "created_at" timestamp with time zone, "is_reversal" boolean, "reversed_entry_id" "uuid", "cashbook_point_id" bigint, "cashbook_point_name" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_entity_id bigint;
  v_search text;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN v_entity_id := v_books_id; END IF;

  IF NOT public.cashbook_staff_can_view(p_tenant_id) THEN RETURN; END IF;

  v_search := nullif(trim(p_search), '');

  RETURN QUERY
  SELECT
    l.id,
    l.tenant_id,
    l.operating_tenant_id,
    l.entity_type,
    l.entity_id,
    l.type,
    l.amount,
    l.currency_code,
    l.exchange_rate,
    l.base_amount,
    l.balance_after,
    l.source_type,
    l.source_id,
    l.metadata,
    l.created_at,
    (l.metadata ? 'reversal_of'),
    CASE WHEN l.metadata ? 'reversal_of' THEN (l.metadata->>'reversal_of')::uuid ELSE NULL END,
    l.cashbook_point_id,
    cp.name
  FROM public.cashbook_entries l
  LEFT JOIN public.cashbook_points cp ON cp.id = l.cashbook_point_id
  WHERE l.tenant_id = v_books_id
    AND l.entity_type = p_entity_type
    AND l.entity_id = v_entity_id
    AND (p_operating_tenant_id IS NULL OR l.operating_tenant_id = p_operating_tenant_id)
    AND (
      v_search IS NULL
      OR coalesce(l.source_id, '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'note', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'trx_id', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'section', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.source_type, '') ILIKE '%' || v_search || '%'
      OR coalesce(cp.name, '') ILIKE '%' || v_search || '%'
    )
  ORDER BY l.created_at DESC, l.id DESC
  LIMIT greatest(least(coalesce(p_limit, 50), 200), 1)
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;


ALTER FUNCTION "public"."list_cashbook_ledger_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_search" "text", "p_operating_tenant_id" bigint, "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."preview_tenant_data_purge"("p_parent_tenant_id" bigint, "p_scope" "text" DEFAULT 'all_hierarchy'::"text", "p_target_child_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_target_tenant_ids BIGINT[];
    v_shipment_count BIGINT := 0;
    v_stock_count BIGINT := 0;
    v_invoice_count BIGINT := 0;
    v_order_count BIGINT := 0;
    v_cart_count BIGINT := 0;
    v_ledger_count BIGINT := 0;
    v_wallets_count BIGINT := 0;
BEGIN
    IF NOT (public.is_superadmin() OR public.user_can_manage_parent_tenant(p_parent_tenant_id)) THEN
        RAISE EXCEPTION 'Unauthorized: Only parent tenant administrators can preview data purges.';
    END IF;

    IF p_scope = 'all_hierarchy' THEN
        SELECT array_agg(id) INTO v_target_tenant_ids
        FROM public.tenants
        WHERE id = p_parent_tenant_id OR parent_id = p_parent_tenant_id;

        SELECT count(*) INTO v_shipment_count FROM public.global_shipments WHERE parent_tenant_id = p_parent_tenant_id;
        SELECT count(*) INTO v_stock_count FROM public.global_stocks WHERE parent_tenant_id = p_parent_tenant_id;
        SELECT count(*) INTO v_invoice_count FROM public.bills WHERE parent_tenant_id = p_parent_tenant_id;
        SELECT count(*) INTO v_ledger_count FROM public.cashbook_entries WHERE tenant_id = p_parent_tenant_id;
        SELECT count(*) INTO v_wallets_count FROM public.cashbook_accounts WHERE tenant_id = p_parent_tenant_id;
    ELSE
        IF p_target_child_id IS NULL THEN
            RAISE EXCEPTION 'Target child tenant ID is required for child_only scope.';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.tenants WHERE id = p_target_child_id AND parent_id = p_parent_tenant_id) THEN
            RAISE EXCEPTION 'Invalid child tenant ID for this parent organization.';
        END IF;

        v_target_tenant_ids := ARRAY[p_target_child_id];

        SELECT count(*) INTO v_invoice_count FROM public.bills WHERE issued_by_tenant_id = p_target_child_id;
        SELECT count(*) INTO v_ledger_count FROM public.cashbook_entries WHERE operating_tenant_id = p_target_child_id;
        SELECT count(*) INTO v_wallets_count FROM public.cashbook_accounts WHERE tenant_id = p_target_child_id;
    END IF;

    SELECT count(*) INTO v_order_count FROM public.shop_orders WHERE tenant_id = ANY(v_target_tenant_ids);
    SELECT count(*) INTO v_cart_count FROM public.shop_carts WHERE tenant_id = ANY(v_target_tenant_ids);

    RETURN jsonb_build_object(
        'shipments', v_shipment_count,
        'stocks', v_stock_count,
        'invoices', v_invoice_count,
        'orders', v_order_count,
        'carts', v_cart_count,
        'ledgers', v_ledger_count,
        'wallets_to_reset', v_wallets_count
    );
END;
$$;


ALTER FUNCTION "public"."preview_tenant_data_purge"("p_parent_tenant_id" bigint, "p_scope" "text", "p_target_child_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_wholesale_invoice_return"("p_invoice_id" bigint, "p_items" "jsonb", "p_return_charge_amount" numeric DEFAULT 0, "p_refund_method" "text" DEFAULT NULL::"text", "p_payout_account_id" bigint DEFAULT NULL::bigint, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_item_elem jsonb;
  v_item_id bigint;
  v_return_qty numeric;
  v_to_availability public.stock_availability;
  v_to_grade_tag_id bigint;
  v_item_note text;
  v_db_item public.bill_lines%rowtype;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_total_return_value numeric(12,2) := 0.00;
  v_line_unit_price numeric(12,2);
  v_line_return_val numeric(12,2);
  v_new_subtotal numeric(12,2) := 0.00;
  v_charges numeric(12,2) := 0.00;
  v_discount numeric(12,2) := 0.00;
  v_paid numeric(12,2) := 0.00;
  v_new_total numeric(12,2) := 0.00;
  v_new_due numeric(12,2) := 0.00;
  v_excess_paid numeric(12,2) := 0.00;
  v_refund_amount numeric(12,2) := 0.00;
  v_return_count integer := 0;
  v_payout_id text;
  v_charge numeric(12,2) := 0.00;
begin
  if p_invoice_id is null then
    raise exception 'Invoice ID is required';
  end if;

  select * into v_invoice
  from public.bills
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Returns can only be processed on issued/posted invoices';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'At least one return item must be provided';
  end if;

  v_charge := greatest(coalesce(p_return_charge_amount, 0.00), 0.00);
  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);
  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

  -- 1. Loop and process each return item
  for v_item_elem in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_item_elem->>'invoice_item_id')::bigint;
    v_return_qty := (v_item_elem->>'quantity')::numeric;
    v_to_availability := coalesce(
      (v_item_elem->>'to_availability')::public.stock_availability,
      'held'::public.stock_availability
    );
    v_to_grade_tag_id := (v_item_elem->>'to_grade_tag_id')::bigint;
    v_item_note := nullif(trim(v_item_elem->>'note'), '');

    if v_item_id is null then
      raise exception 'invoice_item_id is required for all items';
    end if;

    if v_return_qty is null or v_return_qty <= 0 then
      continue; -- Skip 0 or empty quantity items
    end if;

    select * into v_db_item
    from public.bill_lines
    where id = v_item_id and invoice_id = p_invoice_id
    for update;

    if v_db_item.id is null then
      raise exception 'Invoice item % not found on this invoice', v_item_id;
    end if;

    if (v_db_item.return_quantity + v_return_qty) > v_db_item.quantity then
      raise exception 'Return quantity % exceeds available returnable quantity % for %',
        v_return_qty,
        (v_db_item.quantity - v_db_item.return_quantity),
        v_db_item.name_snapshot;
    end if;

    -- Calculate line return value
    v_line_unit_price := v_db_item.sell_price_amount;
    v_line_return_val := round(v_return_qty * v_line_unit_price, 2);
    v_total_return_value := v_total_return_value + v_line_return_val;

    -- Insert record into sales_return_items
    insert into public.sales_return_items (
      parent_tenant_id,
      invoice_id,
      invoice_item_id,
      global_stock_id,
      quantity,
      return_charge_amount,
      note
    ) values (
      v_parent_id,
      p_invoice_id,
      v_item_id,
      v_db_item.global_stock_id,
      v_return_qty,
      0.00,
      v_item_note
    );

    -- Update bill_lines cumulative return_quantity; sold quantity stays.
    -- line_total_amount is the net after return credit (kept qty × price − line discount).
    update public.bill_lines
    set
      return_quantity = return_quantity + v_return_qty,
      line_total_amount = greatest(
        (v_db_item.quantity - (v_db_item.return_quantity + v_return_qty)) * v_db_item.sell_price_amount
        - coalesce(v_db_item.line_discount_amount, 0),
        0
      ),
      updated_at = now()
    where id = v_item_id;

    -- Post return_inbound stock movement
    if v_db_item.global_stock_id is not null then
      perform public.create_and_post_stock_movement(
        p_tenant_id => v_parent_id,
        p_stock_id => v_db_item.global_stock_id,
        p_quantity => ceil(v_return_qty)::integer,
        p_to_location_id => public.default_returns_stock_location_id(v_parent_id),
        p_to_availability => v_to_availability,
        p_to_grade_tag_id => coalesce(v_to_grade_tag_id, public.default_stock_grade_tag_id()),
        p_movement_type => 'return_inbound'::public.stock_movement_type,
        p_notes => coalesce(v_item_note, 'Wholesale invoice return #' || coalesce(v_invoice.invoice_no, p_invoice_id::text)),
        p_reference_type => 'sales_invoice',
        p_reference_id => p_invoice_id::text
      );
    end if;

    v_return_count := v_return_count + 1;
  end loop;

  if v_return_count = 0 then
    raise exception 'No items with quantity > 0 were selected for return';
  end if;

  -- 2. Recalculate invoice totals based on retained quantities
  select coalesce(sum((quantity - return_quantity) * sell_price_amount - line_discount_amount), 0.00)
  into v_new_subtotal
  from public.bill_lines
  where invoice_id = p_invoice_id;

  v_charges := coalesce(v_invoice.shipping_charge, 0.00)
             + coalesce(v_invoice.wrapping_charge, 0.00)
             + coalesce(v_invoice.print_charge, 0.00)
             + v_charge; -- add return handling charge if any

  v_discount := coalesce(v_invoice.discount_amount, 0.00);
  v_paid := coalesce(v_invoice.paid_amount, 0.00);

  v_new_total := greatest(v_new_subtotal + v_charges - v_discount, 0.00);
  v_new_due := greatest(v_new_total - v_paid, 0.00);
  v_excess_paid := greatest(v_paid - v_new_total, 0.00);

  -- 3. Handle excess overpayment refund if applicable
  if v_excess_paid > 0.00 then
    if p_refund_method = 'wallet_credit' and v_invoice.profile_id is not null then
      -- Ensure wallet account exists
      insert into public.cashbook_accounts (
        tenant_id, entity_type, entity_id, currency_code,
        available_balance, locked_balance, pending_balance
      ) values (
        v_eff_tenant_id, 'customer', v_invoice.profile_id, 'BDT',
        0.0000, 0.0000, 0.0000
      ) on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

      -- Credit Customer Wallet via universal ledger
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.profile_id,
        p_type => 'credit',
        p_amount => v_excess_paid,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice_return',
        p_source_id => p_invoice_id::text,
        p_metadata => jsonb_build_object(
          'section', 'returns',
          'purpose', 'wholesale_return_wallet_credit',
          'transaction_type', 'return_credit',
          'label', 'Return Credit (Wallet)',
          'invoice_id', p_invoice_id,
          'invoice_no', v_invoice.invoice_no,
          'notes', p_note
        )
      );

      v_refund_amount := v_excess_paid;

    elsif p_refund_method = 'payout' and v_invoice.profile_id is not null then
      v_payout_id := 'RET-PO-' || gen_random_uuid()::text;

      -- Payout: Debit Tenant Cash (cash outflow from business to customer)
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_eff_tenant_id,
        p_type => 'debit',
        p_amount => v_excess_paid,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'payout',
        p_source_id => v_payout_id,
        p_metadata => jsonb_build_object(
          'section', 'payout_earned',
          'purpose', 'wholesale_return_payout',
          'transaction_type', 'return_cash_payout',
          'label', 'Return Cash Payout',
          'invoice_id', p_invoice_id,
          'invoice_no', v_invoice.invoice_no,
          'profile_id', v_invoice.profile_id,
          'notes', p_note
        )
      );

      v_refund_amount := v_excess_paid;
    end if;
  end if;

  -- 4. Update bills header
  update public.bills
  set
    subtotal_amount = v_new_subtotal,
    total_amount = v_new_total,
    due_amount = v_new_due,
    payment_status = case
      when v_new_due <= 0.00 then 'paid'
      when v_paid > 0.00 and v_new_due > 0.00 then 'partially_paid'
      else 'due'
    end,
    updated_at = now()
  where id = p_invoice_id
  returning * into v_invoice;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'new_subtotal', v_new_subtotal,
    'new_total', v_new_total,
    'new_due', v_new_due,
    'paid_amount', v_paid,
    'excess_paid', v_excess_paid,
    'refund_amount', v_refund_amount,
    'refund_method', p_refund_method,
    'payment_status', v_invoice.payment_status,
    'returned_items_count', v_return_count
  );
end;
$$;


ALTER FUNCTION "public"."process_wholesale_invoice_return"("p_invoice_id" bigint, "p_items" "jsonb", "p_return_charge_amount" numeric, "p_refund_method" "text", "p_payout_account_id" bigint, "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_tenant_operational_data"("p_parent_tenant_id" bigint, "p_scope" "text" DEFAULT 'all_hierarchy'::"text", "p_confirmation_slug" "text" DEFAULT ''::"text", "p_target_child_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_parent_slug TEXT;
    v_target_slug TEXT;
    v_target_id BIGINT;
    v_target_tenant_ids BIGINT[];
    v_counts JSONB;
    v_user_id UUID := auth.uid();
    v_user_email TEXT := COALESCE(public.current_user_email(), 'unknown');
BEGIN
    IF NOT (public.is_superadmin() OR public.user_can_manage_parent_tenant(p_parent_tenant_id)) THEN
        RAISE EXCEPTION 'Unauthorized: Administrative privileges on the parent tenant required.';
    END IF;

    SELECT slug INTO v_parent_slug FROM public.tenants WHERE id = p_parent_tenant_id AND parent_id IS NULL;
    IF v_parent_slug IS NULL THEN
        RAISE EXCEPTION 'Parent tenant not found or is not a root workspace.';
    END IF;

    IF p_scope = 'all_hierarchy' THEN
        v_target_id := p_parent_tenant_id;
        v_target_slug := v_parent_slug;

        SELECT array_agg(id) INTO v_target_tenant_ids
        FROM public.tenants
        WHERE id = p_parent_tenant_id OR parent_id = p_parent_tenant_id;
    ELSIF p_scope = 'child_only' THEN
        IF p_target_child_id IS NULL THEN
            RAISE EXCEPTION 'Target child tenant ID is required for child_only scope.';
        END IF;

        SELECT slug INTO v_target_slug
        FROM public.tenants
        WHERE id = p_target_child_id AND parent_id = p_parent_tenant_id;

        IF v_target_slug IS NULL THEN
            RAISE EXCEPTION 'Selected child tenant not found under this parent organization.';
        END IF;

        v_target_id := p_target_child_id;
        v_target_tenant_ids := ARRAY[p_target_child_id];
    ELSE
        RAISE EXCEPTION 'Invalid scope: %. Must be all_hierarchy or child_only.', p_scope;
    END IF;

    IF UPPER(TRIM(p_confirmation_slug)) <> UPPER(TRIM(v_target_slug)) THEN
        RAISE EXCEPTION 'Confirmation slug mismatch. Expected %, received %.', UPPER(TRIM(v_target_slug)), UPPER(TRIM(p_confirmation_slug));
    END IF;

    v_counts := public.preview_tenant_data_purge(p_parent_tenant_id, p_scope, p_target_child_id);

    -- PBC master data must never be purged:
    -- product_based_costing_files, product_based_costing_items, product_based_costing_backlog_items

    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.sales_return_items WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.bill_lines WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.bills WHERE parent_tenant_id = p_parent_tenant_id;
    ELSE
        DELETE FROM public.sales_return_items
        WHERE invoice_id IN (
            SELECT id FROM public.bills
            WHERE parent_tenant_id = p_parent_tenant_id
              AND issued_by_tenant_id = p_target_child_id
        );
        DELETE FROM public.bill_lines
        WHERE invoice_id IN (
            SELECT id FROM public.bills
            WHERE parent_tenant_id = p_parent_tenant_id
              AND issued_by_tenant_id = p_target_child_id
        );
        DELETE FROM public.bills
        WHERE parent_tenant_id = p_parent_tenant_id
          AND issued_by_tenant_id = p_target_child_id;
    END IF;

    DELETE FROM public.dropship_order_settlements WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.shop_orders WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.shop_carts WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.customer_demand_bucket_items WHERE tenant_id = ANY(v_target_tenant_ids);

    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.cashbook_entries WHERE tenant_id = p_parent_tenant_id;
        UPDATE public.cashbook_accounts
        SET available_balance = 0.0000,
            pending_balance = 0.0000,
            locked_balance = 0.0000,
            updated_at = now()
        WHERE tenant_id = p_parent_tenant_id;
    ELSE
        DELETE FROM public.cashbook_entries WHERE operating_tenant_id = p_target_child_id;
        UPDATE public.cashbook_accounts
        SET available_balance = 0.0000,
            pending_balance = 0.0000,
            locked_balance = 0.0000,
            updated_at = now()
        WHERE tenant_id = p_target_child_id;
    END IF;

    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.stock_movements WHERE tenant_id = ANY(v_target_tenant_ids);
        DELETE FROM public.global_stocks WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.global_shipments WHERE parent_tenant_id = p_parent_tenant_id;
    END IF;

    UPDATE public.sales_invoice_counters
    SET last_value = 0
    WHERE tenant_id = ANY(v_target_tenant_ids);

    INSERT INTO public.tenant_data_purge_logs (
        parent_tenant_id,
        target_tenant_id,
        scope,
        executed_by,
        executor_email,
        confirmation_phrase,
        deleted_counts
    ) VALUES (
        p_parent_tenant_id,
        v_target_id,
        p_scope,
        v_user_id,
        v_user_email,
        p_confirmation_slug,
        v_counts
    );

    RETURN jsonb_build_object(
        'success', true,
        'purged_counts', v_counts,
        'purged_at', now()
    );
END;
$$;


ALTER FUNCTION "public"."purge_tenant_operational_data"("p_parent_tenant_id" bigint, "p_scope" "text", "p_confirmation_slug" "text", "p_target_child_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_ledger_transaction"("p_parent_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_type" "text", "p_amount" numeric, "p_currency_code" "text" DEFAULT 'BDT'::"text", "p_exchange_rate" numeric DEFAULT 1.000000, "p_source_type" "text" DEFAULT 'adjustment'::"text", "p_source_id" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb", "p_target_bucket" "text" DEFAULT 'available'::"text", "p_allow_overdraft" boolean DEFAULT false, "p_cashbook_point_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_account_id bigint;
  v_avail numeric(18,4);
  v_pend numeric(18,4);
  v_lock numeric(18,4);
  v_base_amount numeric(18,4);
  v_new_balance numeric(18,4);
  v_ledger_entry jsonb;
  v_ledger_id uuid;
  v_entity_id bigint;
  v_point_ok boolean;
  v_pot_id bigint;
  v_pot_amt numeric(12, 2);
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transaction amount must be greater than zero.';
  END IF;

  IF p_type NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Transaction type must be credit or debit.';
  END IF;

  IF p_target_bucket NOT IN ('available', 'pending', 'locked') THEN
    RAISE EXCEPTION 'Target bucket must be available, pending, or locked.';
  END IF;

  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' AND v_entity_id IS DISTINCT FROM p_parent_tenant_id THEN
    v_entity_id := p_parent_tenant_id;
  END IF;

  INSERT INTO public.cashbook_accounts (
    tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance
  )
  VALUES (
    p_parent_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000
  )
  ON CONFLICT (tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  IF p_cashbook_point_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.cashbook_points cp
      WHERE cp.id = p_cashbook_point_id
        AND cp.parent_tenant_id = p_parent_tenant_id
        AND cp.cashbook_account_id = v_account_id
        AND cp.is_active = true
    ) INTO v_point_ok;
    IF NOT coalesce(v_point_ok, false) THEN
      RAISE EXCEPTION 'Invalid cashbook point for this account.';
    END IF;

    v_pot_id := public._kernel_ensure_cashbook_point_pot(
      p_parent_tenant_id,
      p_cashbook_point_id,
      coalesce(p_currency_code, 'BDT')
    );
    PERFORM 1
    FROM public.cashbook_point_pots cpp
    WHERE cpp.id = v_pot_id
    FOR UPDATE;

    IF p_type = 'debit' THEN
      SELECT cpp.amount
      INTO v_pot_amt
      FROM public.cashbook_point_pots cpp
      WHERE cpp.id = v_pot_id;

      IF coalesce(v_pot_amt, 0) < p_amount THEN
        IF NOT coalesce(p_allow_overdraft, false) THEN
          RAISE EXCEPTION 'Insufficient cash in till (available: %, requested: %).',
            coalesce(v_pot_amt, 0), p_amount;
        END IF;
        v_pot_id := NULL;
      END IF;
    END IF;
  END IF;

  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM public.cashbook_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  IF p_target_bucket = 'available' THEN
    IF p_type = 'credit' THEN
      v_avail := v_avail + p_amount;
    ELSE
      IF v_avail < p_amount AND NOT coalesce(p_allow_overdraft, false) THEN
        RAISE EXCEPTION 'Insufficient available balance (available: %, requested debit: %).',
          v_avail, p_amount;
      END IF;
      v_avail := v_avail - p_amount;
    END IF;
    v_new_balance := v_avail;
  ELSIF p_target_bucket = 'pending' THEN
    IF p_type = 'credit' THEN
      v_pend := v_pend + p_amount;
    ELSE
      v_pend := v_pend - p_amount;
    END IF;
    v_new_balance := v_pend;
  ELSIF p_target_bucket = 'locked' THEN
    IF p_type = 'credit' THEN
      v_lock := v_lock + p_amount;
    ELSE
      v_lock := v_lock - p_amount;
    END IF;
    v_new_balance := v_lock;
  END IF;

  UPDATE public.cashbook_accounts
  SET
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    tenant_id = p_parent_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  v_base_amount := p_amount * coalesce(p_exchange_rate, 1.000000);

  INSERT INTO public.cashbook_entries (
    tenant_id,
    operating_tenant_id,
    entity_type,
    entity_id,
    type,
    amount,
    currency_code,
    exchange_rate,
    base_amount,
    balance_after,
    source_type,
    source_id,
    metadata,
    cashbook_point_id,
    cashbook_point_pot_id
  )
  VALUES (
    p_parent_tenant_id,
    p_operating_tenant_id,
    p_entity_type,
    v_entity_id,
    p_type,
    p_amount,
    coalesce(p_currency_code, 'BDT'),
    coalesce(p_exchange_rate, 1.000000),
    v_base_amount,
    v_new_balance,
    coalesce(p_source_type, 'adjustment'),
    p_source_id,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object('target_bucket', p_target_bucket),
    p_cashbook_point_id,
    v_pot_id
  )
  RETURNING id INTO v_ledger_id;

  SELECT jsonb_build_object(
    'id', id,
    'parent_tenant_id', parent_tenant_id,
    'operating_tenant_id', operating_tenant_id,
    'tenant_id', parent_tenant_id,
    'entity_type', entity_type,
    'entity_id', entity_id,
    'type', type,
    'amount', amount,
    'currency_code', currency_code,
    'exchange_rate', exchange_rate,
    'base_amount', base_amount,
    'balance_after', balance_after,
    'source_type', source_type,
    'source_id', source_id,
    'metadata', metadata,
    'cashbook_point_id', cashbook_point_id,
    'created_at', created_at
  ) INTO v_ledger_entry
  FROM public.cashbook_entries
  WHERE id = v_ledger_id;

  RETURN v_ledger_entry;
END;
$$;


ALTER FUNCTION "public"."record_ledger_transaction"("p_parent_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_type" "text", "p_amount" numeric, "p_currency_code" "text", "p_exchange_rate" numeric, "p_source_type" "text", "p_source_id" "text", "p_metadata" "jsonb", "p_target_bucket" "text", "p_allow_overdraft" boolean, "p_cashbook_point_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."settle_dropship_courier_ap_via_cod_retention"("p_ap_bill_id" bigint, "p_amount" numeric, "p_order_id" bigint, "p_remittance_ref" "text", "p_receipt_payment_id" bigint DEFAULT NULL::bigint) RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ap public.bills;
  v_bal jsonb;
  v_family_due numeric(12, 2);
  v_remaining numeric(12, 2);
  v_chunk numeric(12, 2);
  v_total_settled numeric(12, 2) := 0;
  v_bill record;
  v_operating_tenant_id bigint;
  v_note text;
begin
  if p_ap_bill_id is null then
    return 0;
  end if;

  select * into v_ap from public.bills where id = p_ap_bill_id for update;
  if v_ap.id is null then
    raise exception 'courier AP bill not found';
  end if;

  if v_ap.invoice_type <> 'ap'::public.global_invoice_type then
    raise exception 'bill is not an AP bill';
  end if;

  if v_ap.invoice_status <> 'issued'::public.global_invoice_status then
    return 0;
  end if;

  v_bal := public.get_bill_net_balances(p_ap_bill_id);
  v_family_due := greatest(coalesce((v_bal->>'due_amount')::numeric, 0), 0);
  v_remaining := least(
    round(greatest(coalesce(p_amount, 0), 0), 2),
    v_family_due
  );

  if v_remaining <= 0 then
    return 0;
  end if;

  v_note := format(
    'Courier COD retention — order #%s — remittance %s',
    p_order_id,
    coalesce(nullif(trim(p_remittance_ref), ''), '—')
  );

  for v_bill in
    select
      b.id,
      b.due_amount,
      b.issued_by_tenant_id,
      b.parent_tenant_id
    from public.bills b
    where (
        b.id = p_ap_bill_id
        or b.parent_bill_id = p_ap_bill_id
      )
      and b.invoice_status = 'issued'::public.global_invoice_status
      and greatest(coalesce(b.due_amount, 0), 0) > 0
    order by
      case when b.id = p_ap_bill_id then 0 else 1 end,
      b.id
    for update
  loop
    v_chunk := least(v_remaining, greatest(coalesce(v_bill.due_amount, 0), 0));
    if v_chunk <= 0 then
      continue;
    end if;

    v_operating_tenant_id := coalesce(v_bill.issued_by_tenant_id, v_bill.parent_tenant_id);

    insert into public.invoice_write_offs (
      tenant_id,
      invoice_id,
      payment_id,
      amount,
      reason,
      note,
      approved_by
    )
    values (
      v_bill.parent_tenant_id,
      v_bill.id,
      p_receipt_payment_id,
      v_chunk,
      'dispute_settlement',
      v_note,
      auth.uid()
    );

    perform public.recompute_global_invoice_payment_status(v_bill.id);

    v_total_settled := v_total_settled + v_chunk;
    v_remaining := v_remaining - v_chunk;

    if v_remaining <= 0 then
      exit;
    end if;
  end loop;

  perform public.recompute_global_invoice_payment_status(p_ap_bill_id);

  return round(v_total_settled, 2);
end;
$$;


ALTER FUNCTION "public"."settle_dropship_courier_ap_via_cod_retention"("p_ap_bill_id" bigint, "p_amount" numeric, "p_order_id" bigint, "p_remittance_ref" "text", "p_receipt_payment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."transfer_wallet_balance"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_from_bucket" "text", "p_to_bucket" "text", "p_amount" numeric, "p_currency_code" "text" DEFAULT 'BDT'::"text", "p_notes" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_parent_tenant_id bigint;
  v_operating_tenant_id bigint;
  v_account_id bigint;
  v_avail numeric(18,4);
  v_pend numeric(18,4);
  v_lock numeric(18,4);
  v_result jsonb;
  v_entity_id bigint;
BEGIN
  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_operating_tenant_id := p_tenant_id;
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transfer amount must be greater than zero.';
  END IF;

  IF p_from_bucket = p_to_bucket THEN
    RAISE EXCEPTION 'Source and target buckets cannot be identical.';
  END IF;

  IF p_from_bucket NOT IN ('available', 'pending', 'locked')
     OR p_to_bucket NOT IN ('available', 'pending', 'locked') THEN
    RAISE EXCEPTION 'Invalid bucket specifiers. Must be available, pending, or locked.';
  END IF;

  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_parent_tenant_id;
  END IF;

  INSERT INTO public.cashbook_accounts (
    tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance
  )
  VALUES (
    v_parent_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000
  )
  ON CONFLICT (tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM public.cashbook_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  IF p_from_bucket = 'pending' THEN
    IF v_pend < p_amount THEN
      RAISE EXCEPTION 'Insufficient pending balance (Pending: %, Requested: %).', v_pend, p_amount;
    END IF;
    v_pend := v_pend - p_amount;
  ELSIF p_from_bucket = 'available' THEN
    v_avail := v_avail - p_amount;
  ELSIF p_from_bucket = 'locked' THEN
    IF v_lock < p_amount THEN
      RAISE EXCEPTION 'Insufficient locked balance (Locked: %, Requested: %).', v_lock, p_amount;
    END IF;
    v_lock := v_lock - p_amount;
  END IF;

  IF p_to_bucket = 'pending' THEN
    v_pend := v_pend + p_amount;
  ELSIF p_to_bucket = 'available' THEN
    v_avail := v_avail + p_amount;
  ELSIF p_to_bucket = 'locked' THEN
    v_lock := v_lock + p_amount;
  END IF;

  UPDATE public.cashbook_accounts
  SET
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    tenant_id = v_parent_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  INSERT INTO public.cashbook_entries (
    tenant_id, operating_tenant_id,
    entity_type, entity_id, type, amount, currency_code,
    exchange_rate, base_amount, balance_after, source_type, source_id, metadata
  )
  VALUES (
    v_parent_tenant_id, v_operating_tenant_id,
    p_entity_type, v_entity_id, 'credit', p_amount, coalesce(p_currency_code, 'BDT'),
    1.000000, p_amount, v_avail, 'bucket_transfer', NULL,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'from_bucket', p_from_bucket,
      'to_bucket', p_to_bucket,
      'notes', p_notes
    )
  );

  SELECT jsonb_build_object(
    'account_id', v_account_id,
    'parent_tenant_id', v_parent_tenant_id,
    'tenant_id', v_parent_tenant_id,
    'entity_type', p_entity_type,
    'entity_id', v_entity_id,
    'currency_code', coalesce(p_currency_code, 'BDT'),
    'available_balance', v_avail,
    'pending_balance', v_pend,
    'locked_balance', v_lock
  ) INTO v_result;

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."transfer_wallet_balance"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_from_bucket" "text", "p_to_bucket" "text", "p_amount" numeric, "p_currency_code" "text", "p_notes" "text", "p_metadata" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_payee_settlement_summary"("p_tenant_id" bigint, "p_shipment_id" bigint, "p_entity_type" "text", "p_entity_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_avail NUMERIC(18,4) := 0;
  v_paid NUMERIC(18,4) := 0;
  v_credited NUMERIC(18,4) := 0;
  v_used NUMERIC(18,4) := 0;
  v_events JSONB := '[]'::jsonb;
BEGIN
  IF p_entity_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT COALESCE(available_balance, 0) INTO v_avail
  FROM public.cashbook_accounts
  WHERE tenant_id = p_tenant_id
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND currency_code = 'BDT';

  SELECT COALESCE(SUM(base_amount), 0) INTO v_paid
  FROM public.cashbook_entries
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND metadata->>'action' = 'pay'
    AND metadata->>'payee_type' = p_entity_type
    AND (metadata->>'payee_id')::bigint = p_entity_id;

  SELECT COALESCE(SUM(base_amount), 0) INTO v_credited
  FROM public.cashbook_entries
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND metadata->>'action' = 'record_credit'
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id;

  SELECT COALESCE(SUM(base_amount), 0) INTO v_used
  FROM public.cashbook_entries
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND metadata->>'action' = 'use_credit'
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'created_at', created_at,
      'type', type,
      'action', metadata->>'action',
      'amount_input', COALESCE((metadata->>'amount_input')::numeric, amount),
      'exchange_rate', COALESCE((metadata->>'exchange_rate')::numeric, exchange_rate),
      'base_amount', base_amount
    ) ORDER BY created_at DESC
  ), '[]'::jsonb) INTO v_events
  FROM public.cashbook_entries
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND (
      (entity_type = p_entity_type AND entity_id = p_entity_id)
      OR
      (metadata->>'payee_type' = p_entity_type AND (metadata->>'payee_id')::bigint = p_entity_id)
    );

  RETURN jsonb_build_object(
    'entity_type', p_entity_type,
    'entity_id', p_entity_id,
    'available_bdt', v_avail,
    'paid_bdt', v_paid,
    'credited_bdt', v_credited,
    'used_bdt', v_used,
    'recent_events', v_events
  );
END;
$$;


ALTER FUNCTION "public"."get_payee_settlement_summary"("p_tenant_id" bigint, "p_shipment_id" bigint, "p_entity_type" "text", "p_entity_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tenant_courier_cod_report"("p_tenant_id" bigint, "p_start_date" "date" DEFAULT NULL::"date", "p_end_date" "date" DEFAULT NULL::"date", "p_courier_service_id" "uuid" DEFAULT NULL::"uuid", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 50, "p_skip_count" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
  v_orders jsonb := NULL;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_start_ts timestamptz := CASE WHEN p_start_date IS NULL THEN NULL ELSE p_start_date::timestamptz END;
  v_end_ts timestamptz := CASE WHEN p_end_date IS NULL THEN NULL ELSE (p_end_date + interval '1 day' - interval '1 microsecond') END;
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'Tenant ID is required'; END IF;
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  WITH delivered_orders AS (
    SELECT
      so.id AS order_id,
      so.order_no,
      coalesce(so.courier_awb_number, so.courier_tracking_number) AS awb,
      coalesce(so.cod_collect_amount, 0)::numeric(12,2) AS cod_collect_amount,
      so.courier_remittance_ref AS remittance_ref,
      so.delivered_at,
      so.courier_service_id,
      coalesce(cs.name, so.courier_name, 'Unassigned') AS courier_name,
      round(coalesce((
        SELECT l.amount
        FROM public.cashbook_entries l
        WHERE l.tenant_id = v_books_id
          AND l.entity_type = 'tenant'
          AND l.source_type = 'shop_order'
          AND l.source_id = so.id::text
          AND coalesce(l.metadata->>'purpose', '') = 'tenant_remittance_received'
        LIMIT 1
      ), 0), 2) AS remitted_amount
    FROM public.shop_orders so
    LEFT JOIN public.courier_services cs ON cs.id = so.courier_service_id
    WHERE public.resolve_parent_tenant_id(so.tenant_id) = v_books_id
      AND so.status IN ('delivered'::public.shop_order_status, 'payment_received'::public.shop_order_status)
      AND so.shop_type_snapshot = 'dropship'::public.shop_type_enum
      AND coalesce(so.cod_collect_amount, 0) > 0
      AND (v_start_ts IS NULL OR so.delivered_at >= v_start_ts)
      AND (v_end_ts IS NULL OR so.delivered_at <= v_end_ts)
      AND (p_courier_service_id IS NULL OR so.courier_service_id = p_courier_service_id)
  ),
  order_amounts AS (
    SELECT *,
      remitted_amount AS remitted,
      round(greatest(cod_collect_amount - remitted_amount, 0), 2) AS unremitted,
      round(remitted_amount - cod_collect_amount, 2) AS short_over
    FROM delivered_orders
  ),
  courier_rows AS (
    SELECT
      courier_service_id,
      courier_name,
      round(coalesce(sum(cod_collect_amount), 0), 2) AS delivered_cod,
      round(coalesce(sum(remitted), 0), 2) AS remitted,
      round(coalesce(sum(unremitted), 0), 2) AS unremitted,
      round(coalesce(sum(short_over), 0), 2) AS short_over,
      count(*)::bigint AS order_count
    FROM order_amounts
    GROUP BY courier_service_id, courier_name
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(delivered_cod), 0), 2) AS delivered_cod,
      round(coalesce(sum(remitted), 0), 2) AS remitted,
      round(coalesce(sum(unremitted), 0), 2) AS unremitted,
      round(coalesce(sum(short_over), 0), 2) AS short_over,
      coalesce(sum(order_count), 0)::bigint AS order_count
    FROM courier_rows
  ),
  paged AS (
    SELECT * FROM courier_rows ORDER BY delivered_cod DESC, courier_name ASC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM courier_rows),
    (SELECT jsonb_build_object('delivered_cod', delivered_cod, 'remitted', remitted, 'unremitted', unremitted,
      'short_over', short_over, 'order_count', order_count) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'courier_service_id', courier_service_id, 'courier_name', courier_name,
      'delivered_cod', delivered_cod, 'remitted', remitted, 'unremitted', unremitted,
      'short_over', short_over, 'order_count', order_count
    ) ORDER BY delivered_cod DESC, courier_name ASC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  IF p_courier_service_id IS NOT NULL THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'order_id', order_id, 'order_no', order_no, 'awb', awb,
      'cod_collect_amount', cod_collect_amount, 'remittance_ref', remittance_ref, 'delivered_at', delivered_at,
      'remitted', remitted
    ) ORDER BY delivered_at DESC NULLS LAST, order_id DESC), '[]'::jsonb)
    INTO v_orders
    FROM order_amounts;
  END IF;

  RETURN jsonb_build_object('totals', coalesce(v_totals, '{}'::jsonb), 'rows', coalesce(v_rows, '[]'::jsonb),
    'orders', v_orders, 'page', v_page, 'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END);
END;
$$;


ALTER FUNCTION "public"."get_tenant_courier_cod_report"("p_tenant_id" bigint, "p_start_date" "date", "p_end_date" "date", "p_courier_service_id" "uuid", "p_page" integer, "p_page_size" integer, "p_skip_count" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tenant_month_snapshot_report"("p_tenant_id" bigint, "p_month" "date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_start date;
  v_end date;
  v_start_ts timestamptz;
  v_end_ts timestamptz;
  v_net_sales numeric(18,4) := 0;
  v_cogs numeric(18,4) := 0;
  v_gross_profit numeric(18,4) := 0;
  v_cash_collected numeric(18,4) := 0;
  v_ar_outstanding numeric(18,4) := 0;
  v_merchant_payable numeric(18,4) := 0;
  v_tenant_cash numeric(18,4) := 0;
  v_ledger_cash numeric(18,4);
  v_courier_holding numeric(18,4) := 0;
  v_cod_unremitted numeric(18,4) := 0;
  v_ap_payable numeric(18,4) := 0;
  v_customer_store_credit numeric(18,4) := 0;
  v_merchant_leftover numeric(18,4) := 0;
  v_net_buffer numeric(18,4) := 0;
  v_sales_by_invoice_type jsonb := '{}'::jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_month IS NULL THEN
    RAISE EXCEPTION 'Tenant ID and month are required';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_start := date_trunc('month', p_month)::date;
  v_end := (date_trunc('month', p_month) + interval '1 month' - interval '1 day')::date;
  v_start_ts := v_start::timestamptz;
  v_end_ts := (v_end + interval '1 day' - interval '1 microsecond');

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  WITH invoice_returned AS (
    SELECT sii.invoice_id, coalesce(sum(sii.return_quantity * sii.sell_price_amount), 0)::numeric(12,2) AS returned
    FROM public.bill_lines sii GROUP BY sii.invoice_id
  ),
  month_invoices AS (
    SELECT si.id, si.invoice_type::text AS invoice_type, si.total_amount, coalesce(ir.returned, 0) AS returned
    FROM public.bills si
    LEFT JOIN invoice_returned ir ON ir.invoice_id = si.id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.invoice_date BETWEEN v_start AND v_end
  ),
  line_metrics AS (
    SELECT
      round(coalesce(sum(
        greatest(sii.quantity - sii.return_quantity, 0) * sii.sell_price_amount
        - coalesce(sii.line_discount_amount, 0) * (greatest(sii.quantity - sii.return_quantity, 0) / nullif(sii.quantity, 0))
      ), 0), 2) AS net_revenue,
      0::numeric AS cogs
    FROM public.bill_lines sii
    JOIN public.bills si ON si.id = sii.invoice_id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.invoice_date BETWEEN v_start AND v_end
  ),
  sales_by_type AS (
    SELECT invoice_type, round(coalesce(sum(total_amount), 0), 2) AS sales
    FROM month_invoices
    GROUP BY invoice_type
  )
  SELECT
    round(coalesce((SELECT sum(total_amount) FROM month_invoices), 0), 2),
    round(coalesce((SELECT cogs FROM line_metrics), 0), 2),
    coalesce((SELECT jsonb_object_agg(invoice_type, sales) FROM sales_by_type), '{}'::jsonb)
  INTO v_net_sales, v_cogs, v_sales_by_invoice_type;

  v_gross_profit := round(v_net_sales - v_cogs, 2);

  SELECT round(coalesce(sum(gp.amount), 0), 2)
  INTO v_cash_collected
  FROM public.pays gp
  WHERE gp.tenant_id = v_books_id
    AND gp.voided_at IS NULL
    AND coalesce(gp.method::text, '') <> 'wallet_credit'
    AND coalesce(gp.payment_date::timestamptz, gp.created_at) BETWEEN v_start_ts AND v_end_ts;

  SELECT round(coalesce(sum(si.due_amount), 0), 2)
  INTO v_ar_outstanding
  FROM public.bills si
  WHERE si.parent_tenant_id = v_books_id
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.invoice_type <> 'ap'::public.global_invoice_type
    AND si.profile_id IS NOT NULL
    AND si.due_amount > 0;

  SELECT round(
    coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN pending_balance ELSE 0 END), 0)
    + coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN available_balance ELSE 0 END), 0),
    2
  )
  INTO v_merchant_payable
  FROM public.cashbook_accounts
  WHERE parent_tenant_id = v_books_id;

  SELECT coalesce(w.available_balance, 0.0000)
  INTO v_tenant_cash
  FROM public.cashbook_accounts w
  WHERE w.parent_tenant_id = v_books_id
    AND w.entity_type = 'tenant'
    AND w.entity_id = v_books_id
    AND w.currency_code = 'BDT'
  LIMIT 1;

  SELECT l.balance_after
  INTO v_ledger_cash
  FROM public.cashbook_entries l
  WHERE l.tenant_id = v_books_id
    AND l.entity_type = 'tenant'
    AND l.entity_id = v_books_id
    AND coalesce(l.currency_code, 'BDT') = 'BDT'
  ORDER BY l.id DESC
  LIMIT 1;

  IF coalesce(v_tenant_cash, 0) = 0 AND coalesce(v_ledger_cash, 0) <> 0 THEN
    v_tenant_cash := v_ledger_cash;
  END IF;

  SELECT round(coalesce(sum(pending_balance + available_balance), 0), 2)
  INTO v_courier_holding
  FROM public.cashbook_accounts
  WHERE parent_tenant_id = v_books_id
    AND entity_type = 'courier';

  WITH delivered_orders AS (
    SELECT
      coalesce(so.cod_collect_amount, 0)::numeric(12,2) AS cod_collect_amount,
      round(coalesce((
        SELECT l.amount
        FROM public.cashbook_entries l
        WHERE l.tenant_id = v_books_id
          AND l.entity_type = 'tenant'
          AND l.source_type = 'shop_order'
          AND l.source_id = so.id::text
          AND coalesce(l.metadata->>'purpose', '') = 'tenant_remittance_received'
        LIMIT 1
      ), 0), 2) AS remitted_amount
    FROM public.shop_orders so
    WHERE public.resolve_parent_tenant_id(so.tenant_id) = v_books_id
      AND so.status IN ('delivered'::public.shop_order_status, 'payment_received'::public.shop_order_status)
      AND so.shop_type_snapshot = 'dropship'::public.shop_type_enum
      AND coalesce(so.cod_collect_amount, 0) > 0
  )
  SELECT round(coalesce(sum(greatest(cod_collect_amount - remitted_amount, 0)), 0), 2)
  INTO v_cod_unremitted
  FROM delivered_orders;

  SELECT round(coalesce(sum(si.due_amount), 0), 2)
  INTO v_ap_payable
  FROM public.bills si
  WHERE si.parent_tenant_id = v_books_id
    AND si.invoice_type = 'ap'::public.global_invoice_type
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.due_amount > 0;

  SELECT
    round(coalesce(sum(CASE WHEN entity_type = 'customer' THEN available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type = 'middleman' THEN pending_balance + available_balance ELSE 0 END), 0), 2)
  INTO v_customer_store_credit, v_merchant_leftover
  FROM public.cashbook_accounts
  WHERE parent_tenant_id = v_books_id;

  v_net_buffer := round(
    coalesce(v_tenant_cash, 0)
    + coalesce(v_courier_holding, 0)
    + coalesce(v_ar_outstanding, 0)
    + coalesce(v_cod_unremitted, 0)
    - coalesce(v_ap_payable, 0)
    - coalesce(v_merchant_leftover, 0)
    - coalesce(v_customer_store_credit, 0),
    2
  );

  RETURN jsonb_build_object(
    'tenant_id', v_books_id,
    'month', v_start,
    'start_date', v_start,
    'end_date', v_end,
    'sales_by_invoice_type', v_sales_by_invoice_type,
    'kpis', jsonb_build_object(
      'net_sales', v_net_sales,
      'cogs', v_cogs,
      'gross_profit', v_gross_profit,
      'cash_collected', v_cash_collected,
      'ar_outstanding', v_ar_outstanding,
      'merchant_payable', v_merchant_payable
    ),
    'position', jsonb_build_object(
      'tenant_cash', round(coalesce(v_tenant_cash, 0), 2),
      'courier_holding', coalesce(v_courier_holding, 0),
      'ar_outstanding', v_ar_outstanding,
      'cod_unremitted', coalesce(v_cod_unremitted, 0),
      'ap_payable', coalesce(v_ap_payable, 0),
      'merchant_payable', coalesce(v_merchant_leftover, 0),
      'customer_store_credit', coalesce(v_customer_store_credit, 0),
      'net_buffer', v_net_buffer
    )
  );
END;
$$;


ALTER FUNCTION "public"."get_tenant_month_snapshot_report"("p_tenant_id" bigint, "p_month" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tenant_wallet_liability_report"("p_tenant_id" bigint, "p_start_date" "date" DEFAULT NULL::"date", "p_end_date" "date" DEFAULT NULL::"date", "p_search" "text" DEFAULT NULL::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 50, "p_skip_count" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_start_ts timestamptz := CASE WHEN p_start_date IS NULL THEN NULL ELSE p_start_date::timestamptz END;
  v_end_ts timestamptz := CASE WHEN p_end_date IS NULL THEN NULL ELSE (p_end_date + interval '1 day' - interval '1 microsecond') END;
  v_customer_store_credit numeric(18,4) := 0;
  v_merchant_payable numeric(18,4) := 0;
  v_courier numeric(18,4) := 0;
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'Tenant ID is required'; END IF;
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT
    round(coalesce(sum(CASE WHEN entity_type = 'customer' THEN available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN pending_balance + available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type = 'courier' THEN pending_balance + available_balance ELSE 0 END), 0), 2)
  INTO v_customer_store_credit, v_merchant_payable, v_courier
  FROM public.cashbook_accounts
  WHERE parent_tenant_id = v_books_id;

  WITH ledger_agg AS (
    SELECT
      l.entity_id AS profile_id,
      round(
        coalesce(sum(CASE
          WHEN l.type = 'credit'
            AND coalesce(l.metadata->>'reversed_by', '') = ''
            AND coalesce(l.metadata->>'purpose', '') IN ('customer_ar_reduction', 'store_credit')
          THEN l.amount
          ELSE 0
        END), 0)
        - coalesce(sum(CASE
          WHEN l.type = 'debit'
            AND coalesce(l.metadata->>'purpose', '') IN ('reverse_customer_ar_reduction', 'void_store_credit')
          THEN l.amount
          ELSE 0
        END), 0),
        4
      ) AS credit_issued,
      round(coalesce(sum(CASE
        WHEN l.type = 'debit' AND coalesce(l.metadata->>'purpose', '') = 'apply_store_credit' THEN l.amount
        ELSE 0 END), 0), 4) AS credit_applied
    FROM public.cashbook_entries l
    WHERE l.tenant_id = v_books_id
      AND l.entity_type = 'customer'
      AND (v_start_ts IS NULL OR l.created_at >= v_start_ts)
      AND (v_end_ts IS NULL OR l.created_at <= v_end_ts)
    GROUP BY l.entity_id
  ),
  base AS (
    SELECT
      wa.entity_id AS profile_id,
      bp.name,
      bp.phone,
      round(coalesce(la.credit_issued, 0), 2) AS credit_issued,
      round(coalesce(la.credit_applied, 0), 2) AS credit_applied,
      round(coalesce(wa.available_balance, 0), 2) AS outstanding
    FROM public.cashbook_accounts wa
    JOIN public.profiles bp ON bp.id = wa.entity_id
    LEFT JOIN ledger_agg la ON la.profile_id = wa.entity_id
    WHERE wa.parent_tenant_id = v_books_id
      AND wa.entity_type = 'customer'
      AND (
        coalesce(wa.available_balance, 0) > 0
        OR coalesce(la.credit_issued, 0) > 0
        OR coalesce(la.credit_applied, 0) > 0
      )
      AND (
        p_search IS NULL OR btrim(p_search) = ''
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR bp.phone ILIKE ('%' || btrim(p_search) || '%')
      )
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(credit_issued), 0), 2) AS credit_issued,
      round(coalesce(sum(credit_applied), 0), 2) AS credit_applied,
      round(coalesce(sum(outstanding), 0), 2) AS outstanding,
      count(*)::bigint AS customer_count
    FROM base
  ),
  paged AS (
    SELECT * FROM base ORDER BY outstanding DESC, name ASC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM base),
    (SELECT jsonb_build_object(
      'credit_issued', credit_issued, 'credit_applied', credit_applied,
      'outstanding', outstanding, 'customer_count', customer_count,
      'customer_store_credit', v_customer_store_credit,
      'merchant_payable', v_merchant_payable,
      'courier', v_courier
    ) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'profile_id', profile_id, 'name', name, 'phone', phone,
      'credit_issued', credit_issued, 'credit_applied', credit_applied, 'outstanding', outstanding
    ) ORDER BY outstanding DESC, name ASC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  RETURN jsonb_build_object('totals', coalesce(v_totals, '{}'::jsonb), 'rows', coalesce(v_rows, '[]'::jsonb),
    'page', v_page, 'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END);
END;
$$;


ALTER FUNCTION "public"."get_tenant_wallet_liability_report"("p_tenant_id" bigint, "p_start_date" "date", "p_end_date" "date", "p_search" "text", "p_page" integer, "p_page_size" integer, "p_skip_count" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_cashbook_dashboard_summary"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
  v_tenant_cash numeric(18,4) := 0.0000;
  v_courier_cod_holding numeric(18,4) := 0.0000;
  v_merchant_pending numeric(18,4) := 0.0000;
  v_merchant_available numeric(18,4) := 0.0000;
  v_vendor_payables numeric(18,4) := 0.0000;
  v_customer_deposits numeric(18,4) := 0.0000;
  v_ledger_cash numeric(18,4);
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    public.cashbook_staff_can_view(p_tenant_id)
    or public.membership_has_module_action(v_books_id, 'payments', 'view')
    or public.membership_has_module_action(p_tenant_id, 'payments', 'view')
    or public.is_tenant_staff(p_tenant_id)
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'access denied',
      'tenant_id', v_books_id,
      'parent_tenant_id', v_books_id,
      'tenant_cash_total', 0,
      'courier_cod_holding_total', 0,
      'merchant_pending_total', 0,
      'merchant_available_total', 0,
      'vendor_payables_total', 0,
      'customer_deposits_total', 0
    );
  end if;

  select coalesce(w.available_balance, 0.0000)
  into v_tenant_cash
  from public.cashbook_accounts w
  where w.parent_tenant_id = v_books_id
    and w.entity_type = 'tenant'
    and w.entity_id = v_books_id
    and w.currency_code = 'BDT'
  limit 1;

  select l.balance_after
  into v_ledger_cash
  from public.cashbook_entries l
  where l.tenant_id = v_books_id
    and l.entity_type = 'tenant'
    and l.entity_id = v_books_id
    and coalesce(l.currency_code, 'BDT') = 'BDT'
  order by l.id desc
  limit 1;

  if coalesce(v_tenant_cash, 0) = 0 and coalesce(v_ledger_cash, 0) <> 0 then
    v_tenant_cash := v_ledger_cash;
  end if;

  select
    coalesce(sum(case when entity_type = 'courier' then pending_balance + available_balance else 0 end), 0),
    coalesce(sum(case when entity_type in ('customer', 'middleman') then pending_balance else 0 end), 0),
    coalesce(sum(case when entity_type in ('customer', 'middleman') then available_balance else 0 end), 0),
    coalesce(sum(case when entity_type = 'vendor' then available_balance else 0 end), 0),
    coalesce(sum(case when entity_type = 'customer' then available_balance else 0 end), 0)
  into
    v_courier_cod_holding,
    v_merchant_pending,
    v_merchant_available,
    v_vendor_payables,
    v_customer_deposits
  from public.cashbook_accounts
  where parent_tenant_id = v_books_id;

  return jsonb_build_object(
    'success', true,
    'tenant_id', v_books_id,
    'parent_tenant_id', v_books_id,
    'tenant_cash_total', coalesce(v_tenant_cash, 0),
    'courier_cod_holding_total', v_courier_cod_holding,
    'merchant_pending_total', v_merchant_pending,
    'merchant_available_total', v_merchant_available,
    'vendor_payables_total', v_vendor_payables,
    'customer_deposits_total', v_customer_deposits
  );
end;
$$;


ALTER FUNCTION "public"."get_cashbook_dashboard_summary"("p_tenant_id" bigint) OWNER TO "postgres";

DROP INDEX IF EXISTS public.idx_uwl_parent_book_lookup;
DROP INDEX IF EXISTS public.idx_uwl_parent_operating_created;
DROP INDEX IF EXISTS public.uq_wallet_accounts_parent_book;
DROP INDEX IF EXISTS public.idx_invoice_write_offs_parent_tenant_id;

ALTER TABLE public.cashbook_entries DROP CONSTRAINT IF EXISTS universal_wallet_ledger_parent_tenant_id_fkey;
ALTER TABLE public.cashbook_accounts DROP CONSTRAINT IF EXISTS wallet_accounts_parent_tenant_id_fkey;
ALTER TABLE public.invoice_write_offs DROP CONSTRAINT IF EXISTS invoice_write_offs_parent_tenant_id_fkey;

DROP POLICY IF EXISTS invoice_write_offs_select ON public.invoice_write_offs;
CREATE POLICY "invoice_write_offs_select" ON "public"."invoice_write_offs" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_write_offs"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_write_offs"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

DROP POLICY IF EXISTS invoice_write_offs_write ON public.invoice_write_offs;
CREATE POLICY "invoice_write_offs_write" ON "public"."invoice_write_offs" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'global_invoice'::"text", 'edit'::"text")) WITH CHECK ("public"."membership_has_module_action"("tenant_id", 'global_invoice'::"text", 'edit'::"text"));

ALTER TABLE public.cashbook_entries DROP COLUMN IF EXISTS parent_tenant_id;
ALTER TABLE public.cashbook_accounts DROP COLUMN IF EXISTS parent_tenant_id;
ALTER TABLE public.invoice_write_offs DROP COLUMN IF EXISTS parent_tenant_id;
