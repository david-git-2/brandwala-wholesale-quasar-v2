-- Migration: Phone-unique recipient_profiles + shop_orders.recipient_profile_id
-- addresses jsonb element shape:
-- { "id": "uuid", "line": "text", "district": "text", "thana": "text", "is_default": true, "updated_at": "timestamptz" }

begin;

-- =========================================================
-- 1a. Schema
-- =========================================================
alter table public.recipient_profiles
  add column if not exists secondary_phone text,
  add column if not exists district text,
  add column if not exists thana text,
  add column if not exists addresses jsonb not null default '[]'::jsonb;

-- Seed addresses from legacy single address for rows with empty array
update public.recipient_profiles
set addresses = jsonb_build_array(
  jsonb_build_object(
    'id', gen_random_uuid()::text,
    'line', address,
    'district', district,
    'thana', thana,
    'is_default', true,
    'updated_at', now()
  )
)
where coalesce(jsonb_array_length(addresses), 0) = 0
  and nullif(trim(address), '') is not null;

-- Dedupe phones: keep min(id); re-point invoice FKs; merge addresses; delete losers
do $$
declare
  r record;
  v_survivor_addresses jsonb;
  v_loser_entry jsonb;
begin
  for r in
    select tenant_id, phone, min(id) as keep_id, array_agg(id order by id) as all_ids
    from public.recipient_profiles
    group by tenant_id, phone
    having count(*) > 1
  loop
    select addresses into v_survivor_addresses
    from public.recipient_profiles where id = r.keep_id;

    for i in 1..array_length(r.all_ids, 1) loop
      if r.all_ids[i] = r.keep_id then
        continue;
      end if;

      update public.global_invoices
      set recipient_profile_id = r.keep_id
      where recipient_profile_id = r.all_ids[i];

      select jsonb_build_object(
        'id', gen_random_uuid()::text,
        'line', address,
        'district', district,
        'thana', thana,
        'is_default', false,
        'updated_at', now()
      )
      into v_loser_entry
      from public.recipient_profiles
      where id = r.all_ids[i];

      if v_loser_entry->>'line' is not null
         and not exists (
           select 1
           from jsonb_array_elements(coalesce(v_survivor_addresses, '[]'::jsonb)) e
           where e->>'line' = v_loser_entry->>'line'
         )
      then
        v_survivor_addresses := coalesce(v_survivor_addresses, '[]'::jsonb) || jsonb_build_array(v_loser_entry);
      end if;

      delete from public.recipient_profiles where id = r.all_ids[i];
    end loop;

    update public.recipient_profiles
    set addresses = coalesce(v_survivor_addresses, '[]'::jsonb)
    where id = r.keep_id;
  end loop;
end;
$$;

create unique index if not exists recipient_profiles_tenant_phone_uidx
  on public.recipient_profiles (tenant_id, phone);

alter table public.shop_orders
  add column if not exists recipient_profile_id bigint
    references public.recipient_profiles(id) on delete restrict;

create index if not exists shop_orders_recipient_profile_id_idx
  on public.shop_orders (recipient_profile_id);

-- =========================================================
-- 1b. normalize_bd_mobile
-- =========================================================
create or replace function public.normalize_bd_mobile(p_phone text)
returns text
language plpgsql
immutable
as $$
declare
  v text;
begin
  v := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  if left(v, 4) = '8801' then
    v := substring(v from 3);
  elsif left(v, 3) = '880' and length(v) = 13 then
    v := substring(v from 3);
  end if;
  if v !~ '^01[0-9]{9}$' then
    raise exception 'Invalid BD mobile phone: %', p_phone;
  end if;
  return v;
end;
$$;

-- =========================================================
-- 1c. upsert_recipient_profile_by_phone
-- =========================================================
create or replace function public.upsert_recipient_profile_by_phone(
  p_tenant_id bigint,
  p_name text,
  p_phone text,
  p_secondary_phone text default null,
  p_address text default null,
  p_district text default null,
  p_thana text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone text;
  v_secondary text;
  v_name text;
  v_address text;
  v_district text;
  v_thana text;
  v_entry jsonb;
  v_addresses jsonb;
  v_next jsonb := '[]'::jsonb;
  v_elem jsonb;
  v_matched boolean := false;
  v_row public.recipient_profiles%rowtype;
  v_can_access boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  v_can_access := public.is_tenant_staff(p_tenant_id)
    or exists (
      select 1
      from public.customer_group_members cgm
      join public.customer_groups cg on cg.id = cgm.customer_group_id
      where cg.tenant_id = p_tenant_id
        and lower(trim(cgm.email)) = public.current_user_email()
        and cgm.is_active = true
        and cg.is_active = true
    );

  if not v_can_access then
    raise exception 'access denied';
  end if;

  v_phone := public.normalize_bd_mobile(p_phone);
  v_name := nullif(trim(coalesce(p_name, '')), '');
  if v_name is null then
    raise exception 'Recipient name is required';
  end if;

  v_address := nullif(trim(coalesce(p_address, '')), '');
  if v_address is null then
    raise exception 'Recipient address is required';
  end if;

  v_district := nullif(trim(coalesce(p_district, '')), '');
  v_thana := nullif(trim(coalesce(p_thana, '')), '');

  if nullif(trim(coalesce(p_secondary_phone, '')), '') is not null then
    begin
      v_secondary := public.normalize_bd_mobile(p_secondary_phone);
    exception when others then
      v_secondary := nullif(trim(p_secondary_phone), '');
    end;
  else
    v_secondary := null;
  end if;

  v_entry := jsonb_build_object(
    'id', gen_random_uuid()::text,
    'line', v_address,
    'district', v_district,
    'thana', v_thana,
    'is_default', true,
    'updated_at', now()
  );

  select * into v_row
  from public.recipient_profiles
  where tenant_id = p_tenant_id and phone = v_phone
  for update;

  if v_row.id is null then
    insert into public.recipient_profiles (
      tenant_id, name, phone, secondary_phone, address, district, thana, addresses
    )
    values (
      p_tenant_id, v_name, v_phone, v_secondary, v_address, v_district, v_thana,
      jsonb_build_array(v_entry)
    )
    returning * into v_row;
  else
    v_addresses := coalesce(v_row.addresses, '[]'::jsonb);
    v_next := '[]'::jsonb;
    v_matched := false;

    for v_elem in select * from jsonb_array_elements(v_addresses)
    loop
      if v_elem->>'line' = v_address then
        v_matched := true;
        v_next := v_next || jsonb_build_array(
          jsonb_build_object(
            'id', coalesce(v_elem->>'id', gen_random_uuid()::text),
            'line', v_address,
            'district', v_district,
            'thana', v_thana,
            'is_default', true,
            'updated_at', now()
          )
        );
      else
        v_next := v_next || jsonb_build_array(
          jsonb_set(v_elem, '{is_default}', 'false'::jsonb)
        );
      end if;
    end loop;

    if not v_matched then
      v_next := v_next || jsonb_build_array(v_entry);
    end if;

    update public.recipient_profiles
    set
      name = v_name,
      secondary_phone = coalesce(v_secondary, secondary_phone),
      address = v_address,
      district = v_district,
      thana = v_thana,
      addresses = v_next,
      updated_at = now()
    where id = v_row.id
    returning * into v_row;
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'name', v_row.name,
    'phone', v_row.phone,
    'secondary_phone', v_row.secondary_phone,
    'address', v_row.address,
    'district', v_row.district,
    'thana', v_row.thana,
    'addresses', v_row.addresses,
    'tenant_id', v_row.tenant_id,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at
  );
end;
$$;

grant execute on function public.upsert_recipient_profile_by_phone(bigint, text, text, text, text, text, text) to authenticated;

-- =========================================================
-- 1d. get_recipient_profile_by_phone
-- =========================================================
create or replace function public.get_recipient_profile_by_phone(
  p_tenant_id bigint,
  p_phone text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone text;
  v_row public.recipient_profiles%rowtype;
  v_can_access boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  v_can_access := public.is_tenant_staff(p_tenant_id)
    or exists (
      select 1
      from public.customer_group_members cgm
      join public.customer_groups cg on cg.id = cgm.customer_group_id
      where cg.tenant_id = p_tenant_id
        and lower(trim(cgm.email)) = public.current_user_email()
        and cgm.is_active = true
        and cg.is_active = true
    );

  if not v_can_access then
    raise exception 'access denied';
  end if;

  begin
    v_phone := public.normalize_bd_mobile(p_phone);
  exception when others then
    return null;
  end;

  select * into v_row
  from public.recipient_profiles
  where tenant_id = p_tenant_id and phone = v_phone;

  if v_row.id is null then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'name', v_row.name,
    'phone', v_row.phone,
    'secondary_phone', v_row.secondary_phone,
    'address', v_row.address,
    'district', v_row.district,
    'thana', v_row.thana,
    'addresses', v_row.addresses,
    'tenant_id', v_row.tenant_id,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at
  );
end;
$$;

grant execute on function public.get_recipient_profile_by_phone(bigint, text) to authenticated;

-- =========================================================
-- 1e. submit_shop_order_from_cart (with recipient upsert + extra A fields)
-- =========================================================
drop function if exists public.submit_shop_order_from_cart(bigint, text, text, text, bigint, boolean, text, numeric, numeric, numeric, numeric, numeric);

create or replace function public.submit_shop_order_from_cart(
  p_cart_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_recipient_phone_secondary text default null,
  p_shipping_district text default null,
  p_shipping_thana text default null,
  p_billing_profile_id bigint default null,
  p_is_prepaid boolean default false,
  p_delivery_instructions text default null,
  p_cod_charge_amount numeric default 0,
  p_delivery_charge_amount numeric default 0,
  p_print_charge_amount numeric default 0,
  p_packing_charge_amount numeric default 0,
  p_discount_amount numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart public.shop_carts%rowtype;
  v_shop public.shops%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_item_count integer;
  v_result jsonb;
  v_billing_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
begin
  select * into v_cart from public.shop_carts where id = p_cart_id and status = 'active';
  if v_cart.id is null then
    raise exception 'active cart not found';
  end if;

  if not public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_shop from public.shops where id = v_cart.shop_id;
  if v_shop.id is null or not v_shop.is_active then
    raise exception 'shop not found or inactive';
  end if;

  select can_place_order, can_negotiate
  into v_can_place_order, v_can_negotiate
  from public.get_shop_permissions_for_customer(v_shop.id);

  if coalesce(v_can_place_order, false) is not true then
    raise exception 'checkout not allowed for this customer group';
  end if;

  select count(*) into v_item_count from public.shop_cart_items where cart_id = p_cart_id;
  if v_item_count = 0 then
    raise exception 'cart is empty';
  end if;

  if v_shop.shop_type = 'dropship' then
    if exists (
      select 1 from public.shop_cart_items ci
      where ci.cart_id = p_cart_id
        and ci.customer_sell_price_currency_id = ci.unit_minimum_sell_price_currency_id
        and ci.customer_sell_price_amount < ci.unit_minimum_sell_price_amount
    ) then
      raise exception 'price floor violation: some items are priced below the minimum sell price';
    end if;
  end if;

  v_billing_profile_id := p_billing_profile_id;
  if v_billing_profile_id is null then
    v_billing_profile_id := public.resolve_billing_profile_for_customer_group(v_cart.tenant_id, v_cart.customer_group_id);
  end if;

  if v_shop.shop_type = 'vendor_catalog' then
    if v_shop.order_mode <> 'procurement_intent' then
      raise exception 'invalid order mode for vendor catalog shop';
    end if;
    if v_shop.is_negotiable and coalesce(v_can_negotiate, false) then
      v_order_status := 'negotiating';
    else
      v_order_status := 'submitted';
    end if;
  else
    if v_shop.order_mode = 'checkout_fixed' then
      v_order_status := 'confirmed';
    else
      v_order_status := 'submitted';
    end if;
  end if;

  v_profile := public.upsert_recipient_profile_by_phone(
    v_cart.tenant_id,
    p_recipient_name,
    p_recipient_phone,
    p_recipient_phone_secondary,
    p_shipping_address,
    p_shipping_district,
    p_shipping_thana
  );
  v_recipient_profile_id := (v_profile->>'id')::bigint;
  v_phone := v_profile->>'phone';

  v_order_no := 'ORD-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 100000)::text, 5, '0');

  insert into public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id,
    order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot,
    status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, billing_profile_id,
    created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  )
  values (
    v_cart.tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id,
    v_order_no, 'Order for ' || p_recipient_name,
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable,
    v_order_status, case when v_order_status = 'negotiating' then 1 else 0 end,
    p_recipient_name, v_phone, nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    p_shipping_address, nullif(trim(coalesce(p_shipping_district, '')), ''), nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_billing_profile_id,
    public.current_user_email(),
    p_cod_charge_amount, p_delivery_charge_amount, p_print_charge_amount, p_packing_charge_amount, p_discount_amount,
    p_is_prepaid, p_delivery_instructions, v_shop.deduct_charges_from_margin,
    false, false, v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  )
  returning id into v_order_id;

  insert into public.shop_order_items (
    order_id, product_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    ordered_quantity
  )
  select
    v_order_id, ci.product_id, ci.global_stock_id, ci.global_stock_allocation_id,
    ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_amount else null end,
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_currency_id else null end,
    case
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, ci.unit_list_price_amount)
      else null
    end,
    case
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id, ci.unit_list_price_currency_id)
      else null
    end,
    ci.quantity
  from public.shop_cart_items ci
  where ci.cart_id = p_cart_id;

  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = p_cart_id);

  update public.shop_carts
  set status = 'converted', updated_at = now()
  where id = p_cart_id;

  select jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_order_status
  ) into v_result;

  return v_result;
end;
$$;

grant execute on function public.submit_shop_order_from_cart(bigint, text, text, text, text, text, text, bigint, boolean, text, numeric, numeric, numeric, numeric, numeric) to authenticated;

-- =========================================================
-- 1f. update_dropship_consignment (+ recipient A)
-- =========================================================
drop function if exists public.update_dropship_consignment(
  bigint, numeric, text, text, text, text, text, text, text, text, text, text, boolean, text, uuid, text, text, text, text, numeric
);

create or replace function public.update_dropship_consignment(
  p_order_id bigint,
  p_cod_collect_amount numeric default 0.00,
  p_package_weight_band text default 'under_1kg',
  p_item_category text default null,
  p_parcel_description text default null,
  p_courier_order_ref text default null,
  p_delivery_zone text default 'inside_dhaka',
  p_sender_name text default null,
  p_pickup_phone text default null,
  p_pickup_address text default null,
  p_payout_account_type text default 'bank',
  p_payout_account_info text default null,
  p_allow_open_box boolean default false,
  p_delivery_instruction_notes text default null,
  p_courier_service_id uuid default null,
  p_courier_tracking_number text default null,
  p_courier_awb_number text default null,
  p_courier_consignment_id text default null,
  p_tracking_url text default null,
  p_courier_cost_amount numeric default 0.00,
  p_recipient_name text default null,
  p_recipient_phone text default null,
  p_recipient_phone_secondary text default null,
  p_shipping_address text default null,
  p_shipping_district text default null,
  p_shipping_thana text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders%rowtype;
  v_profile jsonb;
  v_recipient_profile_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  update public.shop_orders
  set
    cod_collect_amount = p_cod_collect_amount,
    package_weight_band = p_package_weight_band,
    item_category = p_item_category,
    parcel_description = p_parcel_description,
    courier_order_ref = coalesce(p_courier_order_ref, order_no),
    delivery_zone = p_delivery_zone,
    sender_name = p_sender_name,
    pickup_phone = p_pickup_phone,
    pickup_address = p_pickup_address,
    payout_account_type = p_payout_account_type,
    payout_account_info = p_payout_account_info,
    allow_open_box = p_allow_open_box,
    delivery_instruction_notes = p_delivery_instruction_notes,
    courier_service_id = p_courier_service_id,
    courier_tracking_number = p_courier_tracking_number,
    courier_awb_number = p_courier_awb_number,
    courier_consignment_id = p_courier_consignment_id,
    tracking_url = p_tracking_url,
    courier_cost_amount = p_courier_cost_amount,
    updated_at = now()
  where id = p_order_id;

  if nullif(trim(coalesce(p_recipient_phone, '')), '') is not null then
    v_profile := public.upsert_recipient_profile_by_phone(
      v_order.tenant_id,
      coalesce(nullif(trim(coalesce(p_recipient_name, '')), ''), v_order.recipient_name, 'Recipient'),
      p_recipient_phone,
      p_recipient_phone_secondary,
      coalesce(nullif(trim(coalesce(p_shipping_address, '')), ''), v_order.shipping_address, 'Address pending'),
      p_shipping_district,
      p_shipping_thana
    );
    v_recipient_profile_id := (v_profile->>'id')::bigint;

    update public.shop_orders
    set
      recipient_name = coalesce(nullif(trim(coalesce(p_recipient_name, '')), ''), recipient_name),
      recipient_phone = v_profile->>'phone',
      recipient_phone_secondary = coalesce(nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''), recipient_phone_secondary),
      shipping_address = coalesce(nullif(trim(coalesce(p_shipping_address, '')), ''), shipping_address),
      shipping_district = coalesce(nullif(trim(coalesce(p_shipping_district, '')), ''), shipping_district),
      shipping_thana = coalesce(nullif(trim(coalesce(p_shipping_thana, '')), ''), shipping_thana),
      recipient_profile_id = v_recipient_profile_id,
      updated_at = now()
    where id = p_order_id;
  end if;

  return jsonb_build_object('success', true);
end;
$$;

grant execute on function public.update_dropship_consignment(
  bigint, numeric, text, text, text, text, text, text, text, text, text, text, boolean, text, uuid, text, text, text, text, numeric, text, text, text, text, text, text
) to authenticated;

-- =========================================================
-- 1g. create_dual_invoice_from_dropship_order — set recipient_profile_id
-- =========================================================
create or replace function public.create_dual_invoice_from_dropship_order(
  p_order_id bigint,
  p_invoice_no text default null,
  p_billing_profile_id bigint default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_billing_profile_id bigint;
  v_profile record;
  v_parent_tenant_id bigint;
  v_invoice_no text;
  v_invoice record;
  v_item record;
  v_face_subtotal numeric(12,2) := 0;
  v_accounting_subtotal numeric(12,2) := 0;
  v_middle_man_payout numeric(12,2) := 0;
  v_charges_total numeric(12,2) := 0;
  v_item_recipient_price numeric(12,2);
  v_item_sell_price numeric(12,2);
  v_item_face_line numeric(12,2);
  v_item_acct_line numeric(12,2);
  v_courier_cod_fee numeric(12,2) := 0;
  v_courier record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order is not a dropship order';
  end if;

  if v_order.status <> 'delivered' then
    raise exception 'Dual invoice can only be created for delivered orders (current status: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is not null then
    raise exception 'Dual invoice already created for this order (invoice_id: %)', v_order.global_invoice_id;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);
  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required';
  end if;

  v_billing_profile_id := coalesce(p_billing_profile_id, v_order.billing_profile_id);
  if v_billing_profile_id is null then
    select id into v_billing_profile_id
    from public.billing_profiles
    where tenant_id = v_order.tenant_id
      and (customer_group_id = v_order.customer_group_id or is_default = true)
    order by is_default desc, created_at asc
    limit 1;
  end if;

  if v_billing_profile_id is null then
    raise exception 'Billing profile is required for creating dual invoice';
  end if;

  select * into v_profile from public.billing_profiles where id = v_billing_profile_id;
  if v_profile.id is null then
    raise exception 'Billing profile not found';
  end if;

  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := 'INV-DS-' || v_order.order_no;
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  insert into public.global_invoices (
    tenant_id,
    parent_tenant_id,
    invoice_no,
    invoice_type,
    source_module,
    billing_profile_id,
    customer_group_id,
    recipient_profile_id,
    recipient_name,
    recipient_phone,
    recipient_address,
    collection_source,
    sold_in_tenant_id,
    note,
    due_amount,
    status
  )
  values (
    v_order.tenant_id,
    v_parent_tenant_id,
    v_invoice_no,
    'dropship',
    'shop_dropship',
    v_billing_profile_id,
    v_order.customer_group_id,
    v_order.recipient_profile_id,
    coalesce(v_order.recipient_name, v_order.name),
    v_order.recipient_phone,
    v_order.shipping_address,
    'recipient',
    v_order.tenant_id,
    coalesce(p_note, 'Dual invoice created from dropship order #' || v_order.order_no),
    0,
    'posted'
  )
  returning * into v_invoice;

  for v_item in (
    select soi.*, gs.cost as stock_cost, gs.name as stock_name, gs.barcode as stock_barcode, gs.product_code as stock_product_code
    from public.shop_order_items soi
    left join public.global_stocks gs on gs.id = soi.global_stock_id
    where soi.order_id = v_order.id
  ) loop
    v_item_recipient_price := coalesce(v_item.customer_sell_price_amount, v_item.final_price_amount, v_item.unit_sell_price_amount, 0);
    v_item_sell_price := coalesce(v_item.unit_sell_price_amount, v_item.final_price_amount, 0);

    v_item_face_line := v_item.quantity * v_item_recipient_price;
    v_item_acct_line := v_item.quantity * v_item_sell_price;

    insert into public.global_invoice_items (
      tenant_id,
      parent_tenant_id,
      invoice_id,
      global_stock_id,
      product_id,
      name_snapshot,
      barcode_snapshot,
      product_code_snapshot,
      quantity,
      cost_amount,
      sell_price_amount,
      recipient_price_amount,
      line_discount_amount,
      line_total_amount,
      line_face_total_amount
    )
    values (
      v_invoice.tenant_id,
      v_invoice.parent_tenant_id,
      v_invoice.id,
      v_item.global_stock_id,
      v_item.product_id,
      coalesce(v_item.stock_name, v_item.name),
      v_item.stock_barcode,
      v_item.stock_product_code,
      v_item.quantity,
      coalesce(v_item.stock_cost, 0),
      v_item_sell_price,
      v_item_recipient_price,
      0,
      v_item_acct_line,
      v_item_face_line
    );

    v_face_subtotal := v_face_subtotal + v_item_face_line;
    v_accounting_subtotal := v_accounting_subtotal + v_item_acct_line;
  end loop;

  if coalesce(v_order.cod_collect_amount, 0) > 0 and v_order.courier_service_id is not null then
    select * into v_courier from public.courier_services where id = v_order.courier_service_id;
    if v_courier.id is not null then
      if v_courier.cod_fee_mode = 'percent_of_collect' then
        v_courier_cod_fee := round((coalesce(v_order.cod_collect_amount, 0) * coalesce(v_courier.cod_fee_percent, 0.00) / 100.00), 2);
      elsif v_courier.cod_fee_mode = 'flat' then
        v_courier_cod_fee := coalesce(v_courier.cod_fee_flat_amount, 0.00);
      end if;
    end if;
  end if;

  if v_courier_cod_fee > 0 then
    insert into public.invoice_charge_lines (
      tenant_id, invoice_id, charge_type, name, amount
    )
    values (
      v_invoice.tenant_id, v_invoice.id, 'cod_fee', 'Courier COD Charge', v_courier_cod_fee
    );
    v_charges_total := v_charges_total + v_courier_cod_fee;
  end if;

  v_middle_man_payout := greatest(v_face_subtotal - v_accounting_subtotal, 0);

  update public.global_invoices
  set
    subtotal_amount = v_accounting_subtotal,
    accounting_subtotal_amount = v_accounting_subtotal,
    face_subtotal_amount = v_face_subtotal,
    total_amount = v_face_subtotal + v_charges_total,
    due_amount = v_face_subtotal + v_charges_total,
    middle_man_payout_amount = v_middle_man_payout,
    updated_at = now()
  where id = v_invoice.id;

  update public.shop_orders
  set
    global_invoice_id = v_invoice.id,
    updated_at = now()
  where id = v_order.id;

  if v_order.customer_group_id is not null and v_middle_man_payout > 0 then
    declare
      v_member_id uuid;
      v_prev_bal numeric := 0;
    begin
      select id into v_member_id
      from public.customer_group_members
      where customer_group_id = v_order.customer_group_id
      limit 1;

      if v_member_id is not null then
        select coalesce(balance_after, 0.00) into v_prev_bal
        from public.middle_man_payout_ledger
        where tenant_id = v_order.tenant_id and customer_group_member_id = v_member_id
        order by created_at desc limit 1;

        insert into public.middle_man_payout_ledger (
          tenant_id,
          customer_group_member_id,
          shop_order_id,
          global_invoice_id,
          entry_type,
          amount,
          balance_after,
          reference_notes
        )
        values (
          v_order.tenant_id,
          v_member_id,
          v_order.id,
          v_invoice.id,
          'profit_credit',
          v_middle_man_payout,
          v_prev_bal + v_middle_man_payout,
          'Profit credit from dual invoice #' || v_invoice_no
        );
      end if;
    end;
  end if;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice_no,
    'face_subtotal', v_face_subtotal,
    'accounting_subtotal', v_accounting_subtotal,
    'middle_man_payout_amount', v_middle_man_payout
  );
end;
$$;

grant execute on function public.create_dual_invoice_from_dropship_order(bigint, text, bigint, text) to authenticated;
grant execute on function public.create_dual_invoice_from_dropship_order(bigint, text, bigint, text) to service_role;

commit;
