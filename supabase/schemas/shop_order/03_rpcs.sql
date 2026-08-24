-- Extracted from supabase/schemas/public.sql (shop_order). Move-only.

CREATE OR REPLACE FUNCTION "public"."add_to_shop_cart"("p_shop_id" bigint, "p_product_id" bigint, "p_global_stock_allocation_id" bigint DEFAULT NULL::bigint, "p_quantity" integer DEFAULT 1, "p_customer_sell_price_amount" numeric DEFAULT NULL::numeric, "p_customer_sell_price_currency_id" bigint DEFAULT NULL::bigint, "p_global_stock_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_cart_res jsonb;
  v_cart_id bigint;
  v_shop_type public.shop_type_enum;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_prod_name text;
  v_prod_image text;
  v_prod_vendor text;
  v_prod_is_available boolean;
  v_prod_price_amount numeric;
  v_prod_price_currency_id bigint;
  v_listing_id bigint;
  v_global_stock_id bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
  v_display_qty_override integer;
  v_landed_cost numeric;
  v_available_to_sell integer;
  v_existing_item_id bigint;
  v_existing_item_qty integer;
  v_target_qty integer;
  v_can_add_to_cart boolean;
  v_can_set_dropship_price boolean;
  v_customer_sell_price_amount numeric;
  v_customer_sell_price_currency_id bigint;
begin
  v_cart_res := public.get_or_create_shop_cart(p_shop_id);
  v_cart_id := (v_cart_res->'cart'->>'id')::bigint;

  select tenant_id, shop_type, pricing_method, markup_percentage
  into v_tenant_id, v_shop_type, v_pricing_method, v_markup_percentage
  from public.shops
  where id = p_shop_id;

  select can_add_to_cart, can_set_dropship_price
  into v_can_add_to_cart, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(p_shop_id);

  if coalesce(v_can_add_to_cart, false) is not true then
    raise exception 'cart additions not allowed';
  select name, image_url, vendor_code, is_available, list_price_amount, list_price_currency_id
  into v_prod_name, v_prod_image, v_prod_vendor, v_prod_is_available, v_prod_price_amount, v_prod_price_currency_id
  from public.products
  where id = p_product_id;

  if v_prod_name is null then
    raise exception 'product not found';
  v_global_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id);

  if v_shop_type in ('fixed_price', 'dropship') then
    if v_global_stock_id is null then
      raise exception 'global stock required for this shop type';
    select
      l.id, l.global_stock_id, l.sell_price_amount, l.sell_price_currency_id,
      l.minimum_sell_price_amount, l.minimum_sell_price_currency_id, l.display_quantity_override
    into
      v_listing_id, v_global_stock_id, v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id, v_display_qty_override
    from public.shop_product_listings l
    where l.shop_id = p_shop_id
      and l.global_stock_id = v_global_stock_id
      and l.product_id = p_product_id
      and l.is_active = true;

    if v_listing_id is null then
      raise exception 'active product listing not found on this shop';
    if v_shop_type = 'fixed_price' then
      select coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
      into v_landed_cost
      from public.global_stocks gs
      join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      where gs.id = v_global_stock_id;

      if v_pricing_method = 'markup' then
        v_sell_price_amount := v_landed_cost * (1 + v_markup_percentage / 100.0);
      elsif v_pricing_method = 'direct_cost' then
        v_sell_price_amount := v_landed_cost;
      select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and global_stock_id = v_global_stock_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;
    v_available_to_sell := greatest(0, floor(public.global_stock_atp_qty(v_global_stock_id))::integer);

    if v_target_qty > v_available_to_sell then
      raise exception 'insufficient stock: requested %, available %', v_target_qty, v_available_to_sell;
    if v_shop_type = 'dropship' then
      if coalesce(v_can_set_dropship_price, false) then
        if p_customer_sell_price_amount is not null then
          v_customer_sell_price_amount := p_customer_sell_price_amount;
          v_customer_sell_price_currency_id := p_customer_sell_price_currency_id;
        else
          if v_sell_price_currency_id = v_min_sell_price_currency_id then
            v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
          else
            v_customer_sell_price_amount := v_sell_price_amount;
          v_customer_sell_price_currency_id := v_sell_price_currency_id;
        if v_customer_sell_price_currency_id = v_min_sell_price_currency_id
           and v_customer_sell_price_amount < v_min_sell_price_amount then
          raise exception 'price cannot be lower than the minimum sell price %', v_min_sell_price_amount;
        else
        v_customer_sell_price_amount := v_sell_price_amount;
        v_customer_sell_price_currency_id := v_sell_price_currency_id;
      else
    select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and product_id = p_product_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;
  if v_existing_item_id is not null then
    update public.shop_cart_items
    set
      quantity = v_target_qty,
      unit_sell_price_amount = v_sell_price_amount,
      customer_sell_price_amount = coalesce(v_customer_sell_price_amount, customer_sell_price_amount),
      customer_sell_price_currency_id = coalesce(v_customer_sell_price_currency_id, customer_sell_price_currency_id),
      updated_at = now()
    where id = v_existing_item_id;
  else
    insert into public.shop_cart_items (
      cart_id, product_id, global_stock_id, global_stock_allocation_id,
      quantity, minimum_quantity,
      unit_list_price_amount, unit_list_price_currency_id,
      unit_sell_price_amount, unit_sell_price_currency_id,
      unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
      customer_sell_price_amount, customer_sell_price_currency_id,
      name, image_url
    )
    values (
      v_cart_id, p_product_id, v_global_stock_id, null,
      p_quantity, 1,
      v_prod_price_amount, v_prod_price_currency_id,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_prod_name, v_prod_image
    );
  return public.get_or_create_shop_cart(p_shop_id);
ALTER FUNCTION "public"."add_to_shop_cart"("p_shop_id" bigint, "p_product_id" bigint, "p_global_stock_allocation_id" bigint, "p_quantity" integer, "p_customer_sell_price_amount" numeric, "p_customer_sell_price_currency_id" bigint, "p_global_stock_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."advance_dropship_order_status"("p_order_id" bigint, "p_target_status" "public"."shop_order_status", "p_remittance_ref" "text" DEFAULT NULL::"text", "p_bank_trx_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_current_status public.shop_order_status;
  v_is_valid boolean := false;
  v_profit numeric(12,2) := 0.00;
  v_recipient_subtotal numeric(12,2) := 0;
  v_accounting_subtotal numeric(12,2) := 0;
  v_middleman_cost numeric(12,2) := 0;
  v_tenant_revenue numeric(12,2) := 0;
  v_currency text;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  v_current_status := v_order.status;
  v_currency := 'BDT';

  if v_current_status = p_target_status then
    return jsonb_build_object('success', true, 'message', 'Status unchanged', 'new_status', p_target_status);
  if v_current_status in ('submitted', 'draft', 'placed', 'confirmed') and p_target_status in ('processing', 'cancelled') then
    v_is_valid := true;
  elsif v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
    if p_target_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received', 'cancelled') then
      v_is_valid := true;
    if not v_is_valid then
    return jsonb_build_object(
      'success', false,
      'error', format('Invalid status transition for dropship order from %s to %s', v_current_status, p_target_status)
    );
  update public.shop_orders
  set
    status = p_target_status,
    delivered_at = case when p_target_status = 'delivered' then now() else delivered_at end,
    courier_remittance_ref = coalesce(p_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(p_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  select * into v_order from public.shop_orders where id = p_order_id;

  if p_target_status in ('ready_for_pickup', 'shipped', 'delivered', 'payment_received') then
    if v_order.global_invoice_id is null then
      perform public.create_dual_invoice_from_dropship_order(p_order_id);
    else
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'draft'::public.global_invoice_status then
        perform public.post_global_invoice(v_order.global_invoice_id);
      select * into v_order from public.shop_orders where id = p_order_id;
    if v_order.global_invoice_id is not null then
      perform public.ensure_dropship_invoice_billed_entry(v_order.global_invoice_id);
    v_billing_profile_id := v_order.billing_profile_id;
    if v_billing_profile_id is null and v_order.customer_group_id is not null then
      select id into v_billing_profile_id
      from public.billing_profiles
      where tenant_id = v_order.tenant_id
        and customer_group_id = v_order.customer_group_id
      order by created_at asc
      limit 1;
    select * into v_order from public.shop_orders where id = p_order_id;
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
    select
      coalesce(sum(coalesce(customer_sell_price_amount, 0) * quantity), 0),
      coalesce(sum(coalesce(unit_sell_price_amount, unit_list_price_amount, 0) * quantity), 0)
    into v_recipient_subtotal, v_accounting_subtotal
    from public.shop_order_items
    where order_id = p_order_id;

    v_middleman_cost := v_accounting_subtotal
      + coalesce(v_order.print_charge_amount, 0)
      + coalesce(v_order.packing_charge_amount, 0)
      + case when coalesce(v_order.deduct_delivery_from_margin, false) then coalesce(v_order.delivery_charge_amount, 0) else 0 end
      + case when coalesce(v_order.deduct_cod_from_margin, false) then coalesce(v_order.cod_charge_amount, 0) else 0 end;

    v_profit := v_recipient_subtotal - coalesce(v_order.discount_amount, 0) - v_middleman_cost;

    v_tenant_revenue := v_accounting_subtotal
      + coalesce(v_order.print_charge_amount, 0)
      + coalesce(v_order.packing_charge_amount, 0);

    -- Billing profile wallet: dropship_profit on customer entity (same as invoice_billed)
    if v_billing_profile_id is not null and v_profit > 0 then
      if not exists (
        select 1 from public.universal_wallet_ledger
        where source_type = 'shop_order'
          and source_id = p_order_id::text
          and entity_type in ('customer', 'middleman')
          and entity_id = v_billing_profile_id
          and metadata->>'transaction_type' = 'dropship_profit'
      ) then
        perform public.record_ledger_transaction(
          p_tenant_id => v_order.tenant_id,
          p_entity_type => 'customer',
          p_entity_id => v_billing_profile_id,
          p_type => 'credit',
          p_amount => v_profit,
          p_currency_code => v_currency,
          p_exchange_rate => 1.000000,
          p_source_type => 'shop_order',
          p_source_id => p_order_id::text,
          p_metadata => jsonb_build_object(
            'section', 'payout_earned',
            'transaction_type', 'dropship_profit',
            'label', 'Profit Earned',
            'order_no', v_order.order_no,
            'invoice_id', v_order.global_invoice_id
          )
        );
      if v_tenant_revenue > 0 then
      if not exists (
        select 1 from public.universal_wallet_ledger
        where source_type = 'shop_order'
          and source_id = p_order_id::text
          and entity_type = 'tenant'
          and entity_id = v_order.tenant_id
          and metadata->>'transaction_type' = 'revenue'
      ) then
        perform public.record_ledger_transaction(
          p_tenant_id => v_order.tenant_id,
          p_entity_type => 'tenant',
          p_entity_id => v_order.tenant_id,
          p_type => 'credit',
          p_amount => v_tenant_revenue,
          p_currency_code => v_currency,
          p_exchange_rate => 1.000000,
          p_source_type => 'shop_order',
          p_source_id => p_order_id::text,
          p_metadata => jsonb_build_object(
            'section', 'revenue',
            'transaction_type', 'revenue',
            'label', 'Revenue',
            'order_no', v_order.order_no,
            'invoice_id', v_order.global_invoice_id
          )
        );
      elsif p_target_status = 'processing' then
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'issued'::public.global_invoice_status then
        perform public.unpost_global_invoice(v_order.global_invoice_id);
      delete from public.universal_wallet_ledger
      where source_type = 'shop_order'
        and (source_id = p_order_id::text or source_id = v_order.order_no)
        and tenant_id = v_order.tenant_id;

      update public.shop_orders
      set global_invoice_id = null
      where id = p_order_id;

      delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoices where id = v_order.global_invoice_id;
    return jsonb_build_object('success', true, 'new_status', p_target_status);
ALTER FUNCTION "public"."advance_dropship_order_status"("p_order_id" bigint, "p_target_status" "public"."shop_order_status", "p_remittance_ref" "text", "p_bank_trx_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."apply_dropship_payout_settlement_fifo"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_amount" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_remaining numeric := greatest(coalesce(p_amount, 0), 0);
  r record;
  v_profit numeric;
begin
  if v_remaining <= 0 then
    return;
  -- Only fully unpaid orders (partial stays until a later settled_amount column exists)
  for r in
    select o.id
    from public.shop_orders o
    where o.tenant_id = p_tenant_id
      and o.billing_profile_id = p_billing_profile_id
      and o.shop_type_snapshot = 'dropship'
      and o.global_invoice_id is not null
      and coalesce(o.payout_settlement_status, 'unpaid') = 'unpaid'
    order by o.created_at asc, o.id asc
  loop
    exit when v_remaining <= 0;

    select coalesce(sum(u.amount), 0) into v_profit
    from public.universal_wallet_ledger u
    where u.tenant_id = p_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = r.id::text
      and u.entity_type in ('middleman', 'customer')
      and u.type = 'credit'
      and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit';

    if v_profit <= 0 then
      update public.shop_orders
      set payout_settlement_status = 'paid',
          updated_at = now()
      where id = r.id;
      continue;
    if v_remaining >= v_profit then
      update public.shop_orders
      set payout_settlement_status = 'paid',
          updated_at = now()
      where id = r.id;
      v_remaining := v_remaining - v_profit;
    else
      update public.shop_orders
      set payout_settlement_status = 'partial',
          updated_at = now()
      where id = r.id;
      v_remaining := 0;
    ALTER FUNCTION "public"."apply_dropship_payout_settlement_fifo"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text" DEFAULT NULL::"text", "p_category" "text" DEFAULT NULL::"text", "p_brand" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_shop_id bigint;
  v_tenant_id bigint;
  v_shop_name text;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_order_mode public.shop_order_mode_enum;
  v_is_negotiable boolean;
  v_show_stock_quantity boolean;
  v_default_currency_id bigint;
  v_is_active boolean;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  v_vendor_filters jsonb;
  v_can_browse boolean;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
  v_can_see_resell_minimum_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;
  v_limit integer;
  v_offset integer;
  v_result jsonb;
  v_parent_tenant_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;

  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  select
    id, tenant_id, name, shop_type, vendor_code, order_mode,
    is_negotiable, show_stock_quantity, default_currency_id, is_active,
    buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode,
    vendor_filters
  into
    v_shop_id, v_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_vendor_filters
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select
    can_browse, can_see_buy_price, can_see_sell_price, can_see_resell_minimum_price,
    can_add_to_cart, can_place_order,
    can_negotiate, can_view_quantity, can_set_dropship_price
  into
    v_can_browse, v_can_see_buy_price, v_can_see_sell_price, v_can_see_resell_minimum_price,
    v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_tenant_id);
  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  if v_shop_type = 'vendor_catalog' then
    execute format(
      $sql$
        with filtered as (
          select p.*
          from public.products p
          where p.is_available = true
            and coalesce(p.hazardous, false) = false
            and p.parent_tenant_id = $2
            and (
              (($9 is null or jsonb_array_length($9) = 0) and p.vendor_code = $1)
              or
              ($9 is not null and jsonb_array_length($9) > 0 and exists (
                select 1
                from jsonb_to_recordset($9) as vf(vendor_code text, brands text[])
                where vf.vendor_code = p.vendor_code
                  and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
              ))
            )
            and ($3 is null or trim($3) = '' or p.name ilike ('%%' || trim($3) || '%%') or p.product_code ilike ('%%' || trim($3) || '%%') or p.barcode ilike ('%%' || trim($3) || '%%'))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.category, '')) = lower(trim($4)))
            and ($5 is null or trim($5) = '' or lower(coalesce(p.brand, '')) = lower(trim($5)))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.name asc, f.id asc
          limit $6
          offset $7
        )
        select jsonb_build_object(
          'data',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'product_id', p.id,
                  'product_name', p.name,
                  'product_image_url', p.image_url,
                  'product_barcode', p.barcode,
                  'product_code', p.product_code,
                  'product_brand', p.brand,
                  'product_category', p.category,
                  'vendor_code', p.vendor_code,
                  'is_available', p.is_available,
                  'unit_price', case
                    when $8 then jsonb_build_object(
                      'amount', p.list_price_amount,
                      'currency_id', p.list_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.list_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.list_price_currency_id)
                    )
                    else null
                  end,
                  'sell_price', null,
                  'resell_minimum_price', null,
                  'available_units', null,
                  'global_stock_allocation_id', null,
                  'global_stock_id', null,
                  'minimum_order_quantity', p.minimum_order_quantity
                )
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta',
          jsonb_build_object(
            'total', (select count(*) from filtered),
            'page', (($7 / $6) + 1),
            'page_size', $6,
            'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $6::numeric))
          )
        )
      $sql$
    )
    into v_result
    using
      v_vendor_code,
      v_parent_tenant_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_can_see_buy_price,
      v_vendor_filters;
  else
    execute format(
      $sql$
        with filtered as (
          select
            l.id as listing_id,
            l.global_stock_id,
            case
              when $8 = 'fixed_price' and $11 = 'markup' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + $12 / 100.0)
              when $8 = 'fixed_price' and $11 = 'direct_cost' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
              else
                l.sell_price_amount
            end as computed_sell_price,
            coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) as computed_unit_cost,
            l.sell_price_amount as listing_sell_price_amount,
            l.sell_price_currency_id as listing_sell_price_currency_id,
            l.sell_price_currency_id,
            l.minimum_sell_price_amount,
            l.minimum_sell_price_currency_id,
            l.show_quantity as listing_show_quantity,
            l.display_quantity_override,
            p.id as product_id,
            p.name as product_name,
            p.image_url as product_image_url,
            p.barcode as product_barcode,
            p.product_code as product_code,
            p.brand as product_brand,
            p.category as product_category,
            p.vendor_code as product_vendor_code,
            p.is_available as product_is_available,
            p.minimum_order_quantity as product_moq,
            greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer as available_qty
          from public.shop_product_listings l
          join public.products p on p.id = l.product_id
          join public.global_stocks gs on gs.id = l.global_stock_id
          left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
          left join public.global_shipments gship on gship.id = gsi.shipment_id
            and gship.assigned_child_tenant_id = $14
          where l.shop_id = $1
            and l.global_stock_id is not null
            and coalesce(gship.status, 'received') = 'received'
            and l.is_active = true
            and p.is_available = true
            and coalesce(p.hazardous, false) = false
            and ($2 is null or trim($2) = '' or p.name ilike ('%%' || trim($2) || '%%') or p.product_code ilike ('%%' || trim($2) || '%%') or p.barcode ilike ('%%' || trim($2) || '%%'))
            and ($3 is null or trim($3) = '' or lower(coalesce(p.category, '')) = lower(trim($3)))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.brand, '')) = lower(trim($4)))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.product_name asc, f.listing_id asc
          limit $5
          offset $6
        )
        select jsonb_build_object(
          'data',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'product_id', p.product_id,
                  'product_name', p.product_name,
                  'product_image_url', p.product_image_url,
                  'product_barcode', p.product_barcode,
                  'product_code', p.product_code,
                  'product_brand', p.product_brand,
                  'product_category', p.product_category,
                  'vendor_code', p.product_vendor_code,
                  'is_available', p.product_is_available,
                  'unit_price', case
                    when $8 = 'dropship' and $15 then jsonb_build_object(
                      'amount', p.computed_unit_cost,
                      'currency_id', $16,
                      'code', (select code from public.global_currencies where id = $16),
                      'symbol', (select symbol from public.global_currencies where id = $16)
                    )
                    else null
                  end,
                  'sell_price', case
                    when $7 and $8 = 'fixed_price' then jsonb_build_object(
                      'amount', p.computed_sell_price,
                      'currency_id', p.sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.sell_price_currency_id)
                    )
                    when $7 and $8 = 'dropship' then jsonb_build_object(
                      'amount', p.listing_sell_price_amount,
                      'currency_id', p.listing_sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.listing_sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.listing_sell_price_currency_id)
                    )
                    else null
                  end,
                  'resell_minimum_price', case
                    when $17 and $8 = 'dropship' then jsonb_build_object(
                      'amount', p.minimum_sell_price_amount,
                      'currency_id', p.minimum_sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.minimum_sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.minimum_sell_price_currency_id)
                    )
                    else null
                  end,
                  'available_units', case
                    when not $9 or not coalesce(p.listing_show_quantity, $10) then null
                    when $13 = 'original' then greatest(0, p.available_qty)
                    when p.display_quantity_override is not null then p.display_quantity_override
                    else greatest(0, p.available_qty)
                  end,
                  'global_stock_allocation_id', p.global_stock_id,
                  'global_stock_id', p.global_stock_id,
                  'minimum_order_quantity', p.product_moq
                )
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta',
          jsonb_build_object(
            'total', (select count(*) from filtered),
            'page', (($6 / $5) + 1),
            'page_size', $5,
            'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $5::numeric))
          )
        )
      $sql$
    )
    into v_result
    using
      v_shop_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_can_see_sell_price,
      v_shop_type,
      v_can_view_quantity,
      v_show_stock_quantity,
      v_pricing_method,
      v_markup_percentage,
      v_quantity_display_mode,
      v_tenant_id,
      v_can_see_buy_price,
      v_buy_currency_id,
      v_can_see_resell_minimum_price;
  end if;

  v_result := jsonb_set(v_result, '{meta, shop}', jsonb_build_object(
    'id', v_shop_id,
    'name', v_shop_name,
    'slug', p_shop_slug,
    'shop_type', v_shop_type,
    'vendor_code', v_vendor_code,
    'order_mode', v_order_mode,
    'is_negotiable', v_is_negotiable,
    'show_stock_quantity', v_show_stock_quantity,
    'default_currency_id', v_default_currency_id,
    'is_active', v_is_active,
    'buy_currency_id', v_buy_currency_id,
    'sell_currency_id', v_sell_currency_id,
    'pricing_method', v_pricing_method,
    'markup_percentage', v_markup_percentage,
    'quantity_display_mode', v_quantity_display_mode,
    'vendor_filters', v_vendor_filters
  ));
  v_result := jsonb_set(v_result, '{meta, permissions}', jsonb_build_object(
    'can_browse', v_can_browse,
    'can_see_buy_price', v_can_see_buy_price,
    'can_see_sell_price', v_can_see_sell_price,
    'can_see_resell_minimum_price', v_can_see_resell_minimum_price,
    'can_add_to_cart', v_can_add_to_cart,
    'can_place_order', v_can_place_order,
    'can_negotiate', v_can_negotiate,
    'can_view_quantity', v_can_view_quantity,
    'can_set_dropship_price', v_can_set_dropship_price
  ));

  return v_result;
end;
$_$;


ALTER FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text", "p_category" "text", "p_brand" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_shop_catalog_for_customer"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_tenant_id bigint;
  v_search text;
  v_limit integer;
  v_offset integer;
  v_result jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;

  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  v_search := nullif(trim(coalesce(p_search, '')), '');
  v_limit := greatest(1, least(coalesce(p_limit, 20), 50));
  v_offset := greatest(0, coalesce(p_offset, 0));

  if v_search is null then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'total', 0,
        'page', 1,
        'page_size', v_limit,
        'total_pages', 1
      )
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  with accessible_shops as (
    select
      s.id,
      s.slug,
      s.name,
      s.shop_type,
      s.vendor_code,
      s.vendor_filters,
      s.tenant_id,
      s.pricing_method,
      s.markup_percentage,
      bool_or(
        case
          when access.status = false or coalesce(profile.is_active, true) = false then false
          when s.shop_type = 'dropship' then true
          else coalesce(access.can_see_buy_price, profile.default_can_see_buy_price, false)
        end
      ) as can_see_buy_price,
      bool_or(
        case
          when access.status = false or coalesce(profile.is_active, true) = false then false
          when s.shop_type = 'dropship' then true
          else coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
        end
      ) as can_see_sell_price
    from public.shops s
    join public.shop_customer_group_access access on access.shop_id = s.id
    join public.customer_groups cg on cg.id = access.customer_group_id
    left join public.customer_group_shop_profiles profile
      on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
    where s.is_active = true
      and s.deleted_at is null
      and s.tenant_id = p_tenant_id
      and cg.id = public.current_customer_group_id(p_tenant_id)
      and cg.is_active = true
      and access.status = true
      and coalesce(profile.is_active, true) = true
      and coalesce(access.can_browse, profile.default_can_browse, false) = true
    group by
      s.id,
      s.slug,
      s.name,
      s.shop_type,
      s.vendor_code,
      s.vendor_filters,
      s.tenant_id,
      s.pricing_method,
      s.markup_percentage
  ),
  vendor_catalog_rows as (
    select
      s.id as shop_id,
      s.slug as shop_slug,
      s.name as shop_name,
      p.id as product_id,
      p.name as product_name,
      p.image_url as product_image_url,
      p.barcode as product_barcode,
      p.product_code as product_code,
      p.brand as product_brand,
      p.category as product_category,
      case when s.can_see_buy_price then p.list_price_amount else null end as unit_price_amount,
      case when s.can_see_buy_price then p.list_price_currency_id else null end as unit_price_currency_id,
      case when s.can_see_buy_price then gc.symbol else null end as unit_price_currency_symbol
    from accessible_shops s
    join public.products p on p.parent_tenant_id = v_parent_tenant_id
    left join public.global_currencies gc on gc.id = p.list_price_currency_id
    where s.shop_type = 'vendor_catalog'
      and p.is_available = true
      and coalesce(p.hazardous, false) = false
      and (
        ((s.vendor_filters is null or jsonb_array_length(s.vendor_filters) = 0) and p.vendor_code = s.vendor_code)
        or (
          s.vendor_filters is not null and jsonb_array_length(s.vendor_filters) > 0 and exists (
            select 1
            from jsonb_to_recordset(s.vendor_filters) as vf(vendor_code text, brands text[])
            where vf.vendor_code = p.vendor_code
              and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
          )
        )
      )
      and (
        p.name ilike ('%' || v_search || '%')
        or p.product_code ilike ('%' || v_search || '%')
        or p.barcode ilike ('%' || v_search || '%')
      )
  ),
  listing_rows as (
    select
      s.id as shop_id,
      s.slug as shop_slug,
      s.name as shop_name,
      p.id as product_id,
      p.name as product_name,
      p.image_url as product_image_url,
      p.barcode as product_barcode,
      p.product_code as product_code,
      p.brand as product_brand,
      p.category as product_category,
      case
        when s.shop_type = 'dropship' and not s.can_see_buy_price then null
        when s.shop_type = 'fixed_price' and not s.can_see_sell_price then null
        when s.shop_type = 'fixed_price' and s.pricing_method = 'markup' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + s.markup_percentage / 100.0)
        when s.shop_type = 'fixed_price' and s.pricing_method = 'direct_cost' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
        else l.sell_price_amount
      end as unit_price_amount,
      case
        when s.shop_type = 'dropship' and s.can_see_buy_price then l.sell_price_currency_id
        when s.shop_type = 'fixed_price' and s.can_see_sell_price then l.sell_price_currency_id
        else null
      end as unit_price_currency_id,
      case
        when s.shop_type = 'dropship' and s.can_see_buy_price then gc.symbol
        when s.shop_type = 'fixed_price' and s.can_see_sell_price then gc.symbol
        else null
      end as unit_price_currency_symbol
    from accessible_shops s
    join public.shop_product_listings l on l.shop_id = s.id
    join public.products p on p.id = l.product_id
    join public.global_stocks gs on gs.id = l.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments gship on gship.id = gsi.shipment_id
      and gship.assigned_child_tenant_id = s.tenant_id
    left join public.global_currencies gc on gc.id = l.sell_price_currency_id
    where s.shop_type <> 'vendor_catalog'
      and l.global_stock_id is not null
      and coalesce(gship.status, 'received') = 'received'
      and l.is_active = true
      and p.is_available = true
      and coalesce(p.hazardous, false) = false
      and (
        p.name ilike ('%' || v_search || '%')
        or p.product_code ilike ('%' || v_search || '%')
        or p.barcode ilike ('%' || v_search || '%')
      )
  ),
  combined as (
    select * from vendor_catalog_rows
    union all
    select * from listing_rows
  ),
  ranked as (
    select
      c.*,
      row_number() over (
        partition by c.product_id
        order by c.shop_name asc, c.shop_id asc
      ) as row_num
    from combined c
  ),
  deduped as (
    select * from ranked where row_num = 1
  )
  select jsonb_build_object(
    'data',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'shop_id', d.shop_id,
            'shop_slug', d.shop_slug,
            'shop_name', d.shop_name,
            'product_id', d.product_id,
            'product_name', d.product_name,
            'product_image_url', d.product_image_url,
            'product_barcode', d.product_barcode,
            'product_code', d.product_code,
            'product_brand', d.product_brand,
            'product_category', d.product_category,
            'unit_price_amount', d.unit_price_amount,
            'unit_price_currency_id', d.unit_price_currency_id,
            'unit_price_currency_symbol', d.unit_price_currency_symbol
          )
          order by d.product_name asc, d.product_id asc
        )
        from (
          select *
          from deduped
          order by product_name asc, product_id asc
          limit v_limit
          offset v_offset
        ) d
      ),
      '[]'::jsonb
    ),
    'meta',
    jsonb_build_object(
      'total', (select count(*)::bigint from deduped),
      'page', (v_offset / v_limit) + 1,
      'page_size', v_limit,
      'total_pages', greatest(1, ceil((select count(*)::numeric from deduped) / v_limit::numeric))
    )
  )
  into v_result;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."search_shop_catalog_for_customer"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shop_catalog_product_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_shop_id bigint;
  v_shop_tenant_id bigint;
  v_parent_tenant_id bigint;
  v_shop_name text;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_order_mode public.shop_order_mode_enum;
  v_is_negotiable boolean;
  v_show_stock_quantity boolean;
  v_default_currency_id bigint;
  v_is_active boolean;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  v_vendor_filters jsonb;
  v_can_browse boolean;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
  v_can_see_resell_minimum_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;
  v_product jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;
  if p_product_id is null then
    raise exception 'product required';
  end if;
  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  select
    id, tenant_id, name, shop_type, vendor_code, order_mode,
    is_negotiable, show_stock_quantity, default_currency_id, is_active,
    buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode,
    vendor_filters
  into
    v_shop_id, v_shop_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_vendor_filters
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select
    can_browse, can_see_buy_price, can_see_sell_price, can_see_resell_minimum_price,
    can_add_to_cart, can_place_order,
    can_negotiate, can_view_quantity, can_set_dropship_price
  into
    v_can_browse, v_can_see_buy_price, v_can_see_sell_price, v_can_see_resell_minimum_price,
    v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop_tenant_id);

  if v_shop_type = 'vendor_catalog' then
    select jsonb_build_object(
      'product_id', p.id,
      'product_name', p.name,
      'product_image_url', p.image_url,
      'product_barcode', p.barcode,
      'product_code', p.product_code,
      'product_brand', p.brand,
      'product_category', p.category,
      'vendor_code', p.vendor_code,
      'is_available', p.is_available,
      'country_of_origin', p.country_of_origin,
      'expire_date', p.expire_date,
      'unit_price_amount', case when v_can_see_buy_price then p.list_price_amount else null end,
      'unit_price_currency_id', case when v_can_see_buy_price then p.list_price_currency_id else null end,
      'unit_price_currency_code', case when v_can_see_buy_price then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
      'unit_price_currency_symbol', case when v_can_see_buy_price then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
      'minimum_sell_price_amount', null,
      'minimum_sell_price_currency_id', null,
      'minimum_sell_price_currency_code', null,
      'minimum_sell_price_currency_symbol', null,
      'available_units', null,
      'global_stock_allocation_id', null,
      'global_stock_id', null,
      'minimum_order_quantity', p.minimum_order_quantity
    )
    into v_product
    from public.products p
    where p.id = p_product_id
      and p.is_available = true
      and coalesce(p.hazardous, false) = false
      and p.parent_tenant_id = v_parent_tenant_id
      and (
        ((v_vendor_filters is null or jsonb_array_length(v_vendor_filters) = 0) and p.vendor_code = v_vendor_code)
        or
        (v_vendor_filters is not null and jsonb_array_length(v_vendor_filters) > 0 and exists (
          select 1
          from jsonb_to_recordset(v_vendor_filters) as vf(vendor_code text, brands text[])
          where vf.vendor_code = p.vendor_code
            and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
        ))
      )
    limit 1;
  else
    select jsonb_build_object(
      'product_id', row.product_id,
      'product_name', row.product_name,
      'product_image_url', row.product_image_url,
      'product_barcode', row.product_barcode,
      'product_code', row.product_code,
      'product_brand', row.product_brand,
      'product_category', row.product_category,
      'vendor_code', row.product_vendor_code,
      'is_available', row.product_is_available,
      'country_of_origin', row.country_of_origin,
      'expire_date', row.expire_date,
      'unit_price_amount', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then row.computed_sell_price
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then row.computed_sell_price
        else null
      end,
      'unit_price_currency_id', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then row.sell_price_currency_id
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then row.sell_price_currency_id
        else null
      end,
      'unit_price_currency_code', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then (select code from public.global_currencies where id = row.sell_price_currency_id)
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then (select code from public.global_currencies where id = row.sell_price_currency_id)
        else null
      end,
      'unit_price_currency_symbol', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then (select symbol from public.global_currencies where id = row.sell_price_currency_id)
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then (select symbol from public.global_currencies where id = row.sell_price_currency_id)
        else null
      end,
      'minimum_sell_price_amount', case when v_can_see_sell_price and v_shop_type = 'dropship' then row.minimum_sell_price_amount else null end,
      'minimum_sell_price_currency_id', case when v_can_see_sell_price and v_shop_type = 'dropship' then row.minimum_sell_price_currency_id else null end,
      'minimum_sell_price_currency_code', case when v_can_see_sell_price and v_shop_type = 'dropship' then (select code from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'minimum_sell_price_currency_symbol', case when v_can_see_sell_price and v_shop_type = 'dropship' then (select symbol from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'available_units', case
        when not v_can_view_quantity or not coalesce(row.listing_show_quantity, v_show_stock_quantity) then null
        when v_quantity_display_mode = 'original' then greatest(0, row.available_qty)
        when row.display_quantity_override is not null then row.display_quantity_override
        else greatest(0, row.available_qty)
      end,
      'global_stock_allocation_id', row.global_stock_id,
      'global_stock_id', row.global_stock_id,
      'minimum_order_quantity', row.product_moq
    )
    into v_product
    from (
      select
        l.id as listing_id,
        l.global_stock_id,
        case
          when v_shop_type = 'fixed_price' and v_pricing_method = 'markup' then
            coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + v_markup_percentage / 100.0)
          when v_shop_type = 'fixed_price' and v_pricing_method = 'direct_cost' then
            coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
          else
            l.sell_price_amount
        end as computed_sell_price,
        l.sell_price_currency_id,
        l.minimum_sell_price_amount,
        l.minimum_sell_price_currency_id,
        l.show_quantity as listing_show_quantity,
        l.display_quantity_override,
        p.id as product_id,
        p.name as product_name,
        p.image_url as product_image_url,
        p.barcode as product_barcode,
        p.product_code as product_code,
        p.brand as product_brand,
        p.category as product_category,
        p.vendor_code as product_vendor_code,
        p.is_available as product_is_available,
        p.country_of_origin,
        p.expire_date,
        p.minimum_order_quantity as product_moq,
        greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer as available_qty
      from public.shop_product_listings l
      join public.products p on p.id = l.product_id
      join public.global_stocks gs on gs.id = l.global_stock_id
      left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      left join public.global_shipments gship on gship.id = gsi.shipment_id
        and gship.assigned_child_tenant_id = v_shop_tenant_id
      where l.shop_id = v_shop_id
        and l.product_id = p_product_id
        and l.global_stock_id is not null
        and coalesce(gship.status, 'received') = 'received'
        and l.is_active = true
        and p.is_available = true
        and coalesce(p.hazardous, false) = false
      order by l.id asc
      limit 1
    ) row;
  end if;

  if v_product is null then
    raise exception 'product not found';
  end if;

  return jsonb_build_object(
    'data', v_product,
    'meta', jsonb_build_object(
      'shop', jsonb_build_object(
        'id', v_shop_id,
        'name', v_shop_name,
        'slug', p_shop_slug,
        'shop_type', v_shop_type,
        'vendor_code', v_vendor_code,
        'order_mode', v_order_mode,
        'is_negotiable', v_is_negotiable,
        'show_stock_quantity', v_show_stock_quantity,
        'default_currency_id', v_default_currency_id,
        'is_active', v_is_active,
        'buy_currency_id', v_buy_currency_id,
        'sell_currency_id', v_sell_currency_id,
        'pricing_method', v_pricing_method,
        'markup_percentage', v_markup_percentage,
        'quantity_display_mode', v_quantity_display_mode,
        'vendor_filters', v_vendor_filters
      ),
      'permissions', jsonb_build_object(
        'can_browse', v_can_browse,
        'can_see_buy_price', v_can_see_buy_price,
    'can_see_sell_price', v_can_see_sell_price,
        'can_add_to_cart', v_can_add_to_cart,
        'can_place_order', v_can_place_order,
        'can_negotiate', v_can_negotiate,
        'can_view_quantity', v_can_view_quantity,
        'can_set_dropship_price', v_can_set_dropship_price
      )
    )
  );
end;
$_$;


ALTER FUNCTION "public"."get_shop_catalog_product_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_related_shop_catalog_products_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint, "p_limit" integer DEFAULT 4) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_id bigint;
  v_shop_tenant_id bigint;
  v_parent_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_is_active boolean;
  v_vendor_filters jsonb;
  v_can_browse boolean;
  v_can_see_buy_price boolean;
  v_category text;
  v_limit integer;
  v_data jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;
  if p_product_id is null then
    raise exception 'product required';
  end if;
  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  select
    id, tenant_id, shop_type, vendor_code, is_active, vendor_filters
  into
    v_shop_id, v_shop_tenant_id, v_shop_type, v_vendor_code, v_is_active, v_vendor_filters
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select can_browse
  into v_can_browse
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  if v_shop_type <> 'vendor_catalog' then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object('category', null)
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop_tenant_id);
  v_limit := greatest(1, least(coalesce(p_limit, 4), 12));

  select can_see_buy_price
  into v_can_see_buy_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  select p.category
  into v_category
  from public.products p
  where p.id = p_product_id
    and p.is_available = true
    and coalesce(p.hazardous, false) = false
    and p.parent_tenant_id = v_parent_tenant_id
    and (
      ((v_vendor_filters is null or jsonb_array_length(v_vendor_filters) = 0) and p.vendor_code = v_vendor_code)
      or
      (v_vendor_filters is not null and jsonb_array_length(v_vendor_filters) > 0 and exists (
        select 1
        from jsonb_to_recordset(v_vendor_filters) as vf(vendor_code text, brands text[])
        where vf.vendor_code = p.vendor_code
          and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
      ))
    )
  limit 1;

  if v_category is null or trim(v_category) = '' or left(trim(v_category), 1) = '=' then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object('category', null)
    );
  end if;

  select coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'product_id', rel.id,
          'product_name', rel.name,
          'product_image_url', rel.image_url,
          'product_barcode', rel.barcode,
          'product_code', rel.product_code,
          'product_brand', rel.brand,
          'product_category', rel.category,
          'vendor_code', rel.vendor_code,
          'is_available', rel.is_available,
          'unit_price_amount', case when v_can_see_buy_price then rel.list_price_amount else null end,
          'unit_price_currency_id', case when v_can_see_buy_price then rel.list_price_currency_id else null end,
          'unit_price_currency_code', case when v_can_see_buy_price then (select code from public.global_currencies where id = rel.list_price_currency_id) else null end,
          'unit_price_currency_symbol', case when v_can_see_buy_price then (select symbol from public.global_currencies where id = rel.list_price_currency_id) else null end,
          'minimum_sell_price_amount', null,
          'minimum_sell_price_currency_id', null,
          'minimum_sell_price_currency_code', null,
          'minimum_sell_price_currency_symbol', null,
          'available_units', null,
          'global_stock_allocation_id', null,
          'global_stock_id', null,
          'minimum_order_quantity', rel.minimum_order_quantity
        )
        order by rel.name asc, rel.id asc
      )
      from (
        select p.*
        from public.products p
        where p.is_available = true
          and coalesce(p.hazardous, false) = false
          and p.parent_tenant_id = v_parent_tenant_id
          and p.id <> p_product_id
          and lower(coalesce(p.category, '')) = lower(trim(v_category))
          and (
            ((v_vendor_filters is null or jsonb_array_length(v_vendor_filters) = 0) and p.vendor_code = v_vendor_code)
            or
            (v_vendor_filters is not null and jsonb_array_length(v_vendor_filters) > 0 and exists (
              select 1
              from jsonb_to_recordset(v_vendor_filters) as vf(vendor_code text, brands text[])
              where vf.vendor_code = p.vendor_code
                and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
            ))
          )
        order by p.name asc, p.id asc
        limit v_limit
      ) rel
    ),
    '[]'::jsonb
  )
  into v_data;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object('category', trim(v_category))
  );
end;
$$;


ALTER FUNCTION "public"."list_related_shop_catalog_products_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint, "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_apply_shop_markup"("p_shop_id" bigint, "p_markup_percentage" numeric DEFAULT NULL::numeric, "p_listing_ids" bigint[] DEFAULT NULL::bigint[]) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_markup numeric;
  v_count integer := 0;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  -- Use provided markup or lookup from rule
  v_markup := p_markup_percentage;
  if v_markup is null then
    select markup_percentage into v_markup
    from public.shop_pricing_rules
    where shop_id = p_shop_id;
  v_markup := coalesce(v_markup, 0.00);

  update public.shop_product_listings spl
  set
    sell_price_amount = round(
      coalesce(spl.minimum_sell_price_amount, spl.sell_price_amount) * (1 + (v_markup / 100.0)),
      2
    ),
    updated_at = now()
  where spl.shop_id = p_shop_id
    and (p_listing_ids is null or spl.id = any(p_listing_ids));

  get diagnostics v_count = row_count;
  return v_count;
ALTER FUNCTION "public"."bulk_apply_shop_markup"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_listing_ids" bigint[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_apply_shop_markup"("p_shop_id" bigint, "p_markup_amount" numeric DEFAULT NULL::numeric, "p_markup_type" "text" DEFAULT 'percentage'::"text", "p_target_price" "text" DEFAULT 'sell_price'::"text", "p_listing_ids" bigint[] DEFAULT NULL::bigint[]) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_amount numeric;
  v_count integer := 0;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  v_amount := p_markup_amount;
  if v_amount is null then
    select markup_percentage into v_amount
    from public.shop_pricing_rules
    where shop_id = p_shop_id;
  v_amount := coalesce(v_amount, 0.00);

  if p_target_price = 'min_sell_price' then
    update public.shop_product_listings spl
    set
      minimum_sell_price_amount = case
        when p_markup_type = 'percentage' then
          round(coalesce(spl.minimum_sell_price_amount, 0.00) * (1 + (v_amount / 100.0)), 2)
        else
          round(coalesce(spl.minimum_sell_price_amount, 0.00) + v_amount, 2)
      end,
      updated_at = now()
    where spl.shop_id = p_shop_id
      and (p_listing_ids is null or spl.id = any(p_listing_ids))
      and spl.is_price_locked is false;
  else
    update public.shop_product_listings spl
    set
      sell_price_amount = case
        when p_markup_type = 'percentage' then
          round(coalesce(spl.minimum_sell_price_amount, spl.sell_price_amount) * (1 + (v_amount / 100.0)), 2)
        else
          round(coalesce(spl.minimum_sell_price_amount, spl.sell_price_amount) + v_amount, 2)
      end,
      updated_at = now()
    where spl.shop_id = p_shop_id
      and (p_listing_ids is null or spl.id = any(p_listing_ids))
      and spl.is_price_locked is false;
  get diagnostics v_count = row_count;
  return v_count;
ALTER FUNCTION "public"."bulk_apply_shop_markup"("p_shop_id" bigint, "p_markup_amount" numeric, "p_markup_type" "text", "p_target_price" "text", "p_listing_ids" bigint[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_customer_access_shop"("p_shop_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce((select can_browse from public.get_shop_permissions_for_customer(p_shop_id)), false);
ALTER FUNCTION "public"."can_customer_access_shop"("p_shop_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_customer_negotiate_on_shop"("p_shop_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce((select can_negotiate from public.get_shop_permissions_for_customer(p_shop_id)), false);
ALTER FUNCTION "public"."can_customer_negotiate_on_shop"("p_shop_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_customer_see_shop_price"("p_shop_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce((select can_see_buy_price from public.get_shop_permissions_for_customer(p_shop_id)), false);
ALTER FUNCTION "public"."can_customer_see_shop_price"("p_shop_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_shop_login_access"("p_email" "text", "p_tenant_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("has_match" boolean, "matched_role" "public"."customer_group_role", "member_id" bigint, "member_name" "text", "member_email" "text", "member_tenant_id" bigint, "customer_group_id" bigint, "customer_group_name" "text", "member_is_active" boolean, "customer_group_is_active" boolean, "member_created_at" timestamp with time zone, "member_updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_email text;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email(), '')));

  select
    cgm.role,
    cgm.id,
    coalesce(
      nullif(trim(cgm.name), ''),
      (select coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name') from auth.users u where u.email = v_email limit 1)
    ),
    lower(trim(cgm.email)),
    cg.tenant_id,
    cg.id,
    cg.name,
    cgm.is_active,
    cg.is_active,
    cgm.created_at,
    cgm.updated_at
  into
    matched_role,
    member_id,
    member_name,
    member_email,
    member_tenant_id,
    customer_group_id,
    customer_group_name,
    member_is_active,
    customer_group_is_active,
    member_created_at,
    member_updated_at
  from public.customer_group_members cgm
  inner join public.customer_groups cg
    on cg.id = cgm.customer_group_id
  where lower(trim(cgm.email)) = v_email
    and cgm.is_active = true
    and cg.is_active = true
    and (p_tenant_id is null or cg.tenant_id = p_tenant_id)
  order by
    cg.tenant_id asc,
    cg.id asc,
    case cgm.role
      when 'admin' then 1
      when 'negotiator' then 2
      when 'staff' then 3
      else 99
    end asc,
    cgm.id asc
  limit 1;

  has_match := member_id is not null;
  return next;
ALTER FUNCTION "public"."check_shop_login_access"("p_email" "text", "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."confirm_dropship_delivered_costing"("p_order_id" bigint, "p_cod_amount" numeric DEFAULT NULL::numeric, "p_delivery_charge" numeric DEFAULT NULL::numeric, "p_courier_notes" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_courier_id bigint;
  v_cod numeric(15,4) := 0.0000;
  v_delivery_charge numeric(15,4) := 0.0000;
  v_existing_ledger public.universal_wallet_ledger;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id for update;

  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', format('Shop order #%s not found', p_order_id));
  -- Permission check
  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    return jsonb_build_object('success', false, 'error', format('Permission denied for tenant %s', v_order.tenant_id));
  if v_order.status <> 'delivered' and v_order.status <> 'payment_received' then
    return jsonb_build_object(
      'success', false,
      'error', format('Order #%s status is "%s" (must be "delivered" or "payment_received" to confirm costing)', v_order.order_no, v_order.status)
    );
  v_cod := coalesce(p_cod_amount, v_order.cod_collect_amount, 0.0000);
  v_delivery_charge := coalesce(p_delivery_charge, v_order.delivery_charge_amount, 0.0000);

  -- Update order costing fields
  update public.shop_orders
  set
    cod_collect_amount = v_cod,
    delivery_charge_amount = v_delivery_charge,
    courier_notes = coalesce(p_courier_notes, courier_notes),
    updated_at = now()
  where id = p_order_id;

  -- Get numeric courier_id (fallback to 0 if unassigned)
  -- If courier_service_id exists, try to get entity id or use 0
  v_courier_id := coalesce(
    (select coalesce(c.id, 0) from public.courier_services cs left join public.couriers c on c.code = cs.code or c.name = cs.name limit 1),
    0
  );

  -- Idempotency check on universal_wallet_ledger
  select * into v_existing_ledger
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and entity_type = 'courier'
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'delivered_costing'
  limit 1;

  if v_existing_ledger.id is null and v_cod > 0 then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'credit',
      p_amount => v_cod,
      p_currency_code => coalesce(v_order.currency_code, 'BDT'),
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'purpose', 'delivered_costing',
        'order_no', v_order.order_no,
        'delivery_charge', v_delivery_charge
      )
    );
  return jsonb_build_object(
    'success', true,
    'message', 'Delivered costing confirmed and courier wallet credited',
    'order_id', p_order_id,
    'cod_amount', v_cod,
    'delivery_charge', v_delivery_charge
  );
ALTER FUNCTION "public"."confirm_dropship_delivered_costing"("p_order_id" bigint, "p_cod_amount" numeric, "p_delivery_charge" numeric, "p_courier_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."confirm_shop_order"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_is_negotiable boolean;
begin
  select tenant_id, is_negotiable_snapshot into v_tenant_id, v_is_negotiable from public.shop_orders where id = p_order_id;
  
  if v_tenant_id is null then
    raise exception 'order not found';
  if not public.is_tenant_staff(v_tenant_id) then
    raise exception 'access denied';
  -- Finalize pricing: set final price to staff offer or customer offer
  update public.shop_order_items
  set
    final_price_amount = coalesce(staff_offer_amount, customer_offer_amount, unit_sell_price_amount, unit_list_price_amount),
    final_price_currency_id = coalesce(staff_offer_currency_id, customer_offer_currency_id, unit_sell_price_currency_id, unit_list_price_currency_id)
  where order_id = p_order_id;

  update public.shop_orders
  set
    status = 'confirmed',
    updated_at = now()
  where id = p_order_id;
ALTER FUNCTION "public"."confirm_shop_order"("p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."customer_can_select_shop"("p_shop_id" bigint, "p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.shop_customer_group_access access
    join public.customer_groups cg on cg.id = access.customer_group_id
    join public.customer_group_members cgm on cgm.customer_group_id = cg.id
    left join public.customer_group_shop_profiles profile
      on profile.customer_group_id = cg.id
     and profile.tenant_id = p_tenant_id
    where access.shop_id = p_shop_id
      and cg.is_active = true
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and access.status = true
      and coalesce(profile.is_active, true) = true
      and coalesce(access.can_browse, profile.default_can_browse, false) = true
  );
ALTER FUNCTION "public"."customer_can_select_shop"("p_shop_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."customer_confirm_shop_order"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_order record;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'customer_confirm_shop_order is only valid for vendor_catalog orders.';
  END IF;

  IF v_order.status <> 'final_offered' AND v_order.status <> 'priced' THEN
    RAISE EXCEPTION 'Order % cannot be confirmed from status %', p_order_id, v_order.status;
  END IF;

  -- Set confirmed_quantity = quantity where confirmed_quantity is null
  UPDATE public.shop_order_items
  SET
    confirmed_quantity = COALESCE(confirmed_quantity, quantity),
    updated_at = now()
  WHERE order_id = p_order_id;

  -- Update order status to confirmed
  UPDATE public.shop_orders
  SET
    status = 'confirmed'::public.shop_order_status,
    updated_at = now()
  WHERE id = p_order_id;
END;
ALTER FUNCTION "public"."customer_confirm_shop_order"("p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."customer_counter_offer"("p_order_id" bigint, "p_items" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_order record;
  v_item record;
  v_has_counter boolean := false;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'order not found';
  END IF;

  IF v_order.shop_type_snapshot = 'vendor_catalog' THEN
    IF NOT COALESCE(v_order.is_negotiable_snapshot, false) THEN
      RAISE EXCEPTION 'Order % is not negotiable', p_order_id;
    END IF;

    IF v_order.status <> 'priced'::public.shop_order_status THEN
      RAISE EXCEPTION 'Catalog order % cannot respond from status %', p_order_id, v_order.status;
    END IF;

    FOR v_item IN
      SELECT * FROM jsonb_to_recordset(p_items) AS x(
        id bigint,
        customer_offer_amount numeric,
        customer_offer_currency_id bigint
      )
    LOOP
      UPDATE public.shop_order_items
      SET
        customer_offer_amount = v_item.customer_offer_amount,
        customer_offer_currency_id = v_item.customer_offer_currency_id,
        customer_counter_at = now(),
        updated_at = now()
      WHERE id = v_item.id AND order_id = p_order_id;
    END LOOP;

    SELECT EXISTS (
      SELECT 1
      FROM public.shop_order_items soi
      WHERE soi.order_id = p_order_id
        AND soi.customer_offer_amount IS NOT NULL
        AND soi.staff_offer_amount IS NOT NULL
        AND soi.customer_offer_amount <> soi.staff_offer_amount
    )
    INTO v_has_counter;

    IF v_has_counter THEN
      UPDATE public.shop_orders
      SET
        status = 'countered'::public.shop_order_status,
        negotiate_round = negotiate_round + 1,
        updated_at = now()
      WHERE id = p_order_id;
    ELSE
      UPDATE public.shop_order_items
      SET
        confirmed_quantity = COALESCE(confirmed_quantity, quantity),
        updated_at = now()
      WHERE order_id = p_order_id;

      UPDATE public.shop_orders
      SET
        status = 'confirmed'::public.shop_order_status,
        updated_at = now()
      WHERE id = p_order_id;
    END IF;
  ELSE
    IF NOT public.is_cart_owner(v_order.customer_group_id, v_order.tenant_id) THEN
      RAISE EXCEPTION 'access denied';
    END IF;

    FOR v_item IN
      SELECT * FROM jsonb_to_recordset(p_items) AS x(
        id bigint,
        customer_offer_amount numeric,
        customer_offer_currency_id bigint
      )
    LOOP
      UPDATE public.shop_order_items
      SET
        customer_offer_amount = v_item.customer_offer_amount,
        customer_offer_currency_id = v_item.customer_offer_currency_id,
        updated_at = now()
      WHERE id = v_item.id AND order_id = p_order_id;
    END LOOP;

    UPDATE public.shop_orders
    SET
      status = 'negotiating'::public.shop_order_status,
      negotiate_round = negotiate_round + 1,
      updated_at = now()
    WHERE id = p_order_id;
  END IF;
END;
$$;
ALTER FUNCTION "public"."customer_counter_offer"("p_order_id" bigint, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_shop"("p_shop_id" bigint, "p_tenant_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  update public.shops
  set
    deleted_at = now(),
    deleted_by = public.current_user_email(),
    is_active = false
  where id = p_shop_id
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if not found then
    raise exception 'shop not found or already deleted';
  ALTER FUNCTION "public"."delete_shop"("p_shop_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_shop_order"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_allocation_id bigint;
  v_stock_id bigint;
if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'Access denied';
  if v_order.status = 'fulfilled' then
    raise exception 'Cannot delete a fulfilled order';
  -- Rollback stock for dropship or confirmed shop orders
  for v_item in select * from public.shop_order_items where order_id = p_order_id loop
    -- Resolve allocation and stock IDs if missing
    v_allocation_id := v_item.global_stock_allocation_id;
    v_stock_id := v_item.global_stock_id;

    -- Rollback display_quantity_override in shop_product_listings
    if v_item.product_id is not null then
      update public.shop_product_listings
      set display_quantity_override = display_quantity_override + v_item.quantity
      where shop_id = v_order.shop_id
        and product_id = v_item.product_id
        and (v_allocation_id is null or global_stock_allocation_id = v_allocation_id)
        and display_quantity_override is not null;
    -- Rollback actual quantity in global_stock_allocations
    if v_allocation_id is not null then
      update public.global_stock_allocations
      set quantity = quantity + v_item.quantity
      where id = v_allocation_id;
    -- Rollback actual quantity in global_stocks
    if v_stock_id is not null then
      update public.global_stocks
      set quantity = quantity + v_item.quantity
      where id = v_stock_id;
    -- Delete the order (cascade deletes items)
  delete from public.shop_orders where id = p_order_id;
ALTER FUNCTION "public"."delete_shop_order"("p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_shop_product_listing"("p_listing_id" bigint, "p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  delete from public.shop_product_listings
  where id = p_listing_id and tenant_id = p_tenant_id;

  return true;
ALTER FUNCTION "public"."delete_shop_product_listing"("p_listing_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fetch_customer_shop_categories"("p_tenant_id" bigint) RETURNS TABLE("name" "text", "count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return query
  with accessible_shops as (
    select distinct s.id, s.shop_type, s.vendor_code, s.vendor_filters
    from public.shops s
    join public.shop_customer_group_access access on access.shop_id = s.id
    join public.customer_groups cg on cg.id = access.customer_group_id
    join public.customer_group_members cgm on cgm.customer_group_id = cg.id
    left join public.customer_group_shop_profiles profile
      on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
    where s.is_active = true
      and cg.is_active = true
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and s.tenant_id = p_tenant_id
      and access.status = true
      and coalesce(profile.is_active, true) = true
      and coalesce(access.can_browse, profile.default_can_browse, false) = true
  ),
  vendor_products as (
    select distinct p.id, p.category
    from public.products p
    join accessible_shops s on s.shop_type = 'vendor_catalog'
    where p.is_available = true
      and (p.tenant_id = p_tenant_id or p.parent_tenant_id = p_tenant_id)
      and (
        ((s.vendor_filters is null or jsonb_array_length(s.vendor_filters) = 0) and p.vendor_code = s.vendor_code)
        or
        (s.vendor_filters is not null and jsonb_array_length(s.vendor_filters) > 0 and exists (
          select 1 
          from jsonb_to_recordset(s.vendor_filters) as vf(vendor_code text, brands text[])
          where vf.vendor_code = p.vendor_code
            and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
        ))
      )
  ),
  listing_products as (
    select distinct p.id, p.category
    from public.shop_product_listings l
    join accessible_shops s on s.id = l.shop_id and s.shop_type <> 'vendor_catalog'
    join public.products p on p.id = l.product_id
    where l.is_active = true
      and p.is_available = true
  ),
  combined_products as (
    select id, category from vendor_products
    union
    select id, category from listing_products
  )
  select 
    coalesce(nullif(trim(cp.category), ''), 'Uncategorized') as name,
    count(cp.id)::bigint as count
  from combined_products cp
  group by coalesce(nullif(trim(cp.category), ''), 'Uncategorized')
  order by count(cp.id) desc, name asc;
ALTER FUNCTION "public"."fetch_customer_shop_categories"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finalize_dropship_return"("p_order_id" bigint, "p_items" "jsonb", "p_actual_return_charge" numeric DEFAULT 0.00, "p_deduct_from_middle_man" boolean DEFAULT true, "p_override_reason" "text" DEFAULT NULL::"text", "p_return_ref" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_ref text;
  v_item_elem jsonb;
  v_order_item_id bigint;
  v_returned_qty numeric;
  v_condition text;
  v_order_item record;
  v_invoice_item record;
  v_stock record;
  v_target_stock_type_id bigint;
  v_target_stock_id bigint;
  v_net_delivered numeric;
  v_currency text;
  v_is_remitted boolean := false;
  v_existing_ref_order_id bigint;
  v_profit numeric(12,2) := 0;
  v_revenue numeric(12,2) := 0;
  v_billed numeric(12,2) := 0;
  v_remit_net numeric(12,2) := 0;
  v_courier_charge numeric(12,2) := 0;
  v_has_billed boolean := false;
  v_has_profit boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order #% is not a dropship order', p_order_id;
  v_currency := 'BDT';
  v_ref := nullif(trim(coalesce(p_return_ref, '')), '');
  if v_ref is not null then
    select id into v_existing_ref_order_id
    from public.shop_orders
    where tenant_id = v_order.tenant_id
      and return_ref = v_ref;

    if v_existing_ref_order_id is not null then
      if v_existing_ref_order_id = p_order_id and v_order.return_sub_state = 'return_finalized' then
        return jsonb_build_object(
          'success', true,
          'idempotent', true,
          'message', 'Return already finalized with reference ' || v_ref,
          'order_id', p_order_id
        );
      else
        raise exception 'Duplicate return reference % already used for another return', v_ref;
      if v_order.return_sub_state = 'return_finalized' then
    return jsonb_build_object(
      'success', true,
      'idempotent', true,
      'message', 'Order return is already finalized',
      'order_id', p_order_id
    );
  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id for update;
  v_billing_profile_id := v_order.billing_profile_id;
  if v_billing_profile_id is null and v_order.customer_group_id is not null then
    select id into v_billing_profile_id
    from public.billing_profiles
    where tenant_id = v_order.tenant_id
      and customer_group_id = v_order.customer_group_id
    order by is_default desc, created_at asc
    limit 1;
  if p_items is not null and jsonb_array_length(p_items) > 0 then
    for v_item_elem in select * from jsonb_array_elements(p_items) loop
      v_order_item_id := (v_item_elem->>'order_item_id')::bigint;
      v_returned_qty := coalesce((v_item_elem->>'returned_qty')::numeric, 0);
      v_condition := coalesce(lower(trim(v_item_elem->>'condition')), 'perfect');

      if v_returned_qty <= 0 then
        continue;
      select * into v_order_item
      from public.shop_order_items
      where id = v_order_item_id and order_id = p_order_id for update;

      if v_order_item.id is null then
        raise exception 'Order item #% not found on order #%', v_order_item_id, p_order_id;
      v_net_delivered := coalesce(v_order_item.delivered_quantity, v_order_item.quantity) - coalesce(v_order_item.returned_quantity, 0);
      if v_returned_qty > v_net_delivered then
        raise exception 'Returned quantity % exceeds net delivered quantity % for item #%', v_returned_qty, v_net_delivered, v_order_item_id;
      select * into v_stock from public.global_stocks where id = v_order_item.global_stock_id;

      if v_stock.id is not null then
        perform public.create_and_post_stock_movement(
          v_parent_tenant_id,
          v_stock.id,
          ceil(v_returned_qty)::integer,
          public.default_returns_stock_location_id(v_parent_tenant_id),
          case
            when v_condition = 'damaged' then 'unsellable'::public.stock_availability
            else 'held'::public.stock_availability
          end,
          public.stock_grade_tag_id_for_slug(
            case v_condition
              when 'open_box' then 'open_box'
              when 'damaged' then 'badly_damaged'
              else 'standard'
            end
          ),
          'return_inbound'::public.stock_movement_type,
          coalesce(p_override_reason, 'Dropship return'),
          'shop_order',
          p_order_id::text
        );
      update public.shop_order_items
      set returned_quantity = coalesce(returned_quantity, 0) + v_returned_qty, updated_at = now()
      where id = v_order_item_id;

      if v_invoice.id is not null then
        select * into v_invoice_item
        from public.global_invoice_items
        where invoice_id = v_invoice.id
          and (global_stock_id = v_order_item.global_stock_id or product_id = v_order_item.product_id)
        limit 1;

        if v_invoice_item.id is not null then
          -- global_return_items schema: quantity + return_charge_amount only (no return_amount / face / accounting)
          insert into public.global_return_items (
            tenant_id, parent_tenant_id, invoice_id, invoice_item_id, global_stock_id,
            quantity, return_charge_amount, note
          )
          values (
            v_invoice.tenant_id, v_invoice.parent_tenant_id, v_invoice.id, v_invoice_item.id, v_order_item.global_stock_id,
            v_returned_qty, 0.00, coalesce(p_override_reason, 'Dropship return finalization')
          );

          update public.global_invoice_items
          set return_quantity = coalesce(return_quantity, 0) + v_returned_qty, updated_at = now()
          where id = v_invoice_item.id;
        if v_invoice.id is not null then
    perform public.recompute_global_invoice_totals(v_invoice.id);
  select exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) into v_is_remitted;

  -- Resolve amounts from UWL (canonical after billing-profile unification)
  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_billed
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'customer'
    and entity_id = v_billing_profile_id
    and metadata->>'transaction_type' in ('invoice_billed', 'return_reversal', 'invoice_collection');

  -- Net billed outstanding before clawback: invert so positive = amount still billed
  v_billed := greatest(-v_billed, 0);
  v_has_billed := v_billed > 0 or exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
  );

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_profit
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type in ('customer', 'middleman')
    and entity_id = v_billing_profile_id
    and metadata->>'section' = 'payout_earned';

  v_profit := greatest(v_profit, 0);
  v_has_profit := v_profit > 0;

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_revenue
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'tenant'
    and metadata->>'transaction_type' = 'revenue';

  if v_revenue <= 0 then
    v_revenue := coalesce(v_invoice.total_amount, 0.00);
  select coalesce((metadata->>'net_remitted')::numeric, amount, 0)
  into v_remit_net
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received'
  limit 1;

  select coalesce((metadata->>'courier_charge')::numeric, amount, 0)
  into v_courier_charge
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_courier_charge'
  limit 1;

  -- Leg 1: Reverse remaining invoice billed / collection net on customer
  if v_billing_profile_id is not null and v_has_billed and v_billed > 0
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_billing_profile_id,
      p_type => 'credit',
      p_amount => v_billed,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'receivable',
        'transaction_type', 'return_reversal',
        'label', 'Return Billed Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  elsif v_billing_profile_id is not null and v_has_billed and v_billed = 0
     and exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    -- Invoice fully collected already — reverse original billed amount then reverse collection net via billed lookup
    select coalesce(base_amount, 0) into v_billed
    from public.universal_wallet_ledger
    where source_type = 'shop_order' and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
    limit 1;

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_billing_profile_id,
        p_type => 'credit',
        p_amount => v_billed,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'return_reversal',
          'label', 'Return Billed Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );

      if exists (
        select 1 from public.universal_wallet_ledger
        where source_type = 'shop_order' and source_id = p_order_id::text
          and metadata->>'transaction_type' = 'invoice_collection'
      ) then
        perform public.record_ledger_transaction(
          p_tenant_id => v_order.tenant_id,
          p_entity_type => 'customer',
          p_entity_id => v_billing_profile_id,
          p_type => 'debit',
          p_amount => v_billed,
          p_currency_code => v_currency,
          p_exchange_rate => 1.000000,
          p_source_type => 'shop_order',
          p_source_id => p_order_id::text,
          p_metadata => jsonb_build_object(
            'section', 'receivable',
            'transaction_type', 'return_collection_reversal',
            'label', 'Return Collection Reversal',
            'order_no', v_order.order_no,
            'return_ref', v_ref
          )
        );
      -- Historical remittance path: invoice_collection posted without invoice_billed.
  -- Unwind collection only (no synthetic return_reversal credit).
  elsif v_billing_profile_id is not null
     and exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_collection'
     )
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_collection_reversal'
     )
  then
    select coalesce(sum(base_amount), 0) into v_billed
    from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and entity_type = 'customer'
      and entity_id = v_billing_profile_id
      and type = 'credit'
      and metadata->>'transaction_type' = 'invoice_collection';

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_billing_profile_id,
        p_type => 'debit',
        p_amount => v_billed,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'return_collection_reversal',
          'label', 'Return Collection Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    -- Leg 2: Claw back profit on customer (unified billing-profile wallet)
  if v_billing_profile_id is not null and v_has_profit
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_profit_clawback'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_billing_profile_id,
      p_type => 'debit',
      p_amount => v_profit,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payout_earned',
        'transaction_type', 'return_profit_clawback',
        'label', 'Return Profit Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  -- Leg 3: Reverse tenant revenue
  if v_revenue > 0
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_revenue_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_order.tenant_id,
      p_type => 'debit',
      p_amount => v_revenue,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'revenue',
        'transaction_type', 'return_revenue_reversal',
        'label', 'Return Revenue Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  -- Leg 4: Reverse remittance cash + courier fee if remitted
  if v_is_remitted then
    if coalesce(v_remit_net, 0) > 0
       and not exists (
         select 1 from public.universal_wallet_ledger
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'remittance_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_order.tenant_id,
        p_type => 'debit',
        p_amount => v_remit_net,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'payment_received',
          'purpose', 'remittance_return_reversal',
          'transaction_type', 'remittance_return_reversal',
          'label', 'Remittance Return Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    if coalesce(v_courier_charge, 0) > 0
       and not exists (
         select 1 from public.universal_wallet_ledger
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'courier_charge_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_order.tenant_id,
        p_type => 'credit',
        p_amount => v_courier_charge,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'delivery_fee',
          'purpose', 'courier_charge_return_reversal',
          'transaction_type', 'courier_charge_return_reversal',
          'label', 'Courier Fee Return Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    -- Return fee: UWL only (legacy middle_man_payout_ledger was dropped)
  if p_deduct_from_middle_man
     and p_actual_return_charge > 0
     and v_billing_profile_id is not null
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order'
         and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_fee'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_billing_profile_id,
      p_type => 'debit',
      p_amount => p_actual_return_charge,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payout_earned',
        'transaction_type', 'return_fee',
        'label', 'Return Fee',
        'order_no', v_order.order_no,
        'return_ref', v_ref,
        'invoice_id', v_order.global_invoice_id
      )
    );
  update public.shop_orders
  set
    status = 'returned'::public.shop_order_status,
    return_sub_state = 'return_finalized',
    returned_at = coalesce(returned_at, now()),
    return_charge_amount = p_actual_return_charge,
    deduct_return_charge_from_middle_man = p_deduct_from_middle_man,
    return_override_reason = coalesce(p_override_reason, return_override_reason),
    return_ref = v_ref,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'status', 'returned',
    'return_sub_state', 'return_finalized',
    'return_ref', v_ref
  );
ALTER FUNCTION "public"."finalize_dropship_return"("p_order_id" bigint, "p_items" "jsonb", "p_actual_return_charge" numeric, "p_deduct_from_middle_man" boolean, "p_override_reason" "text", "p_return_ref" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fulfill_shop_order_to_invoice"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_retail_billing_mode public.retail_billing_mode;
  if v_order.id is null then
    raise exception 'order not found';
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  if v_order.status <> 'confirmed' then
    raise exception 'only confirmed orders can be fulfilled to an invoice';
  if v_order.shop_type_snapshot = 'vendor_catalog' then
    raise exception 'vendor catalog orders cannot be fulfilled to an invoice directly';
  if v_order.shop_type_snapshot = 'dropship' then
    v_invoice_type := 'dropship'::public.global_invoice_type;
    v_retail_billing_mode := null;
  else
    if v_order.order_mode_snapshot = 'checkout_wholesale' then
      v_invoice_type := 'wholesale'::public.global_invoice_type;
      v_retail_billing_mode := null;
    else
      v_invoice_type := 'retail'::public.global_invoice_type;
      if v_order.billing_profile_id is not null then
        v_retail_billing_mode := 'account'::public.retail_billing_mode;
      else
        v_retail_billing_mode := 'direct'::public.retail_billing_mode;
      v_invoice_no := 'INV-SO-' || v_order.order_no;

  select * into v_invoice from public.create_global_invoice(
    p_tenant_id => v_order.tenant_id,
    p_invoice_no => v_invoice_no,
    p_invoice_type => v_invoice_type,
    p_billing_profile_id => v_order.billing_profile_id,
    p_recipient_profile_id => null,
    p_recipient_name => v_order.recipient_name,
    p_recipient_phone => v_order.recipient_phone,
    p_recipient_address => v_order.shipping_address,
    p_retail_billing_mode => v_retail_billing_mode,
    p_due_date => null,
    p_note => coalesce(v_order.delivery_instructions, 'Fulfillment of Shop Order: ' || v_order.order_no)
  );

  update public.global_invoices
  set
    shipping_charge = coalesce(v_order.delivery_charge_amount, 0),
    cod_charge = coalesce(v_order.cod_charge_amount, 0),
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    collection_source = case when v_order.is_prepaid_snapshot then 'billing_profile'::public.collection_source_type else 'recipient'::public.collection_source_type end
  where id = v_invoice.id;

  for v_item in select * from public.shop_order_items where order_id = p_order_id loop
    if v_item.global_stock_id is null then
      raise exception 'item % is missing global_stock_id association', v_item.name;
    perform public.add_global_invoice_item(
      p_invoice_id => v_invoice.id,
      p_global_stock_id => v_item.global_stock_id,
      p_quantity => v_item.quantity::numeric,
      p_sell_price_amount => coalesce(v_item.final_price_amount, v_item.unit_sell_price_amount, v_item.unit_list_price_amount),
      p_recipient_price_amount => coalesce(v_item.customer_sell_price_amount, v_item.final_price_amount, v_item.unit_sell_price_amount, v_item.unit_list_price_amount),
      p_line_discount_amount => 0.00
    );

    perform public.post_global_invoice(v_invoice.id);

  update public.shop_orders
  set status = 'fulfilled',
      global_invoice_id = v_invoice.id,
      fulfilled_at = now(),
      updated_at = now()
  where id = p_order_id;
ALTER FUNCTION "public"."fulfill_shop_order_to_invoice"("p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_shop_order_number"("p_tenant_id" bigint, "p_shop_id" bigint) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order_no text;
begin
  v_order_no := 'ORD-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 100000)::text, 5, '0');
  return v_order_no;
ALTER FUNCTION "public"."generate_shop_order_number"("p_tenant_id" bigint, "p_shop_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_customer_shop_order"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_group_id bigint;
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_shop_slug text;
  v_sell_currency_id bigint;
  v_buy_currency_id bigint;
  v_sell_symbol text;
  v_buy_symbol text;
  v_item_count bigint;
  v_total_amount numeric;
  v_items jsonb;
  v_order_json jsonb;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  v_group_id := public.current_customer_group_id(p_tenant_id);
  if v_group_id is null then
    raise exception 'access denied';
  select *
  into v_order
  from public.shop_orders o
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  if v_order.customer_group_id is distinct from v_group_id then
    raise exception 'order not found';
  select
    s.name,
    s.slug,
    s.sell_currency_id,
    s.buy_currency_id,
    sell_gc.symbol,
    buy_gc.symbol
  into
    v_shop_name,
    v_shop_slug,
    v_sell_currency_id,
    v_buy_currency_id,
    v_sell_symbol,
    v_buy_symbol
  from public.shops s
  left join public.global_currencies sell_gc on sell_gc.id = s.sell_currency_id
  left join public.global_currencies buy_gc on buy_gc.id = s.buy_currency_id
  where s.id = v_order.shop_id;

  select count(*)::bigint
  into v_item_count
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(
        soi.final_price_amount,
        soi.customer_offer_amount,
        soi.unit_sell_price_amount,
        soi.unit_list_price_amount
      ) * soi.quantity
    ),
    0
  )
  into v_total_amount
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'product_id', soi.product_id,
        'global_stock_id', soi.global_stock_id,
        'global_stock_allocation_id', soi.global_stock_allocation_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'unit_list_price_amount', soi.unit_list_price_amount,
        'unit_list_price_currency_id', soi.unit_list_price_currency_id,
        'unit_sell_price_amount', soi.unit_sell_price_amount,
        'unit_sell_price_currency_id', soi.unit_sell_price_currency_id,
        'unit_minimum_sell_price_amount', soi.unit_minimum_sell_price_amount,
        'unit_minimum_sell_price_currency_id', soi.unit_minimum_sell_price_currency_id,
        'customer_sell_price_amount', soi.customer_sell_price_amount,
        'customer_sell_price_currency_id', soi.customer_sell_price_currency_id,
        'customer_offer_amount', soi.customer_offer_amount,
        'customer_offer_currency_id', soi.customer_offer_currency_id,
        'staff_offer_amount', soi.staff_offer_amount,
        'staff_offer_currency_id', soi.staff_offer_currency_id,
        'is_first_offer_manual', soi.is_first_offer_manual,
        'final_price_amount', soi.final_price_amount,
        'final_price_currency_id', soi.final_price_currency_id,
        'is_final_offer_manual', soi.is_final_offer_manual,
        'confirmed_quantity', soi.confirmed_quantity,
        'weight_kg', soi.weight_kg,
        'customer_decision_status', soi.customer_decision_status,
        'customer_decision_at', soi.customer_decision_at,
        'negotiation_status', soi.negotiation_status,
        'staff_offer_at', soi.staff_offer_at,
        'customer_counter_at', soi.customer_counter_at,
        'final_offer_at', soi.final_offer_at,
        'ordered_quantity', soi.ordered_quantity,
        'delivered_quantity', soi.delivered_quantity,
        'returned_quantity', soi.returned_quantity,
        'sku', p.product_code,
        'brand', p.brand,
        'barcode', p.barcode,
        'minimum_order_quantity', p.minimum_order_quantity,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at
      )
      order by soi.created_at, soi.id
    ),
    '[]'::jsonb
  )
  into v_items
  from public.shop_order_items soi
  left join public.products p on p.id = soi.product_id
  where soi.order_id = v_order.id;

  v_order_json :=
    jsonb_build_object(
      'id', v_order.id,
      'tenant_id', v_order.tenant_id,
      'shop_id', v_order.shop_id,
      'shop_name', v_shop_name,
      'shop_slug', v_shop_slug,
      'customer_group_id', v_order.customer_group_id,
      'cart_id', v_order.cart_id,
      'order_no', v_order.order_no,
      'name', v_order.name,
      'shop_type_snapshot', v_order.shop_type_snapshot,
      'order_mode_snapshot', v_order.order_mode_snapshot,
      'is_negotiable_snapshot', v_order.is_negotiable_snapshot,
      'status', v_order.status,
      'negotiate_round', v_order.negotiate_round,
      'cargo_rate', v_order.cargo_rate,
      'conversion_rate', v_order.conversion_rate,
      'profit_rate', v_order.profit_rate,
      'first_offer_rate', v_order.first_offer_rate,
      'final_offer_rate', v_order.final_offer_rate,
      'profit_basis', v_order.profit_basis,
      'package_weight_kg', v_order.package_weight_kg,
      'recipient_name', v_order.recipient_name,
      'recipient_phone', v_order.recipient_phone,
      'recipient_phone_secondary', v_order.recipient_phone_secondary,
      'shipping_address', v_order.shipping_address,
      'shipping_district', v_order.shipping_district,
      'shipping_thana', v_order.shipping_thana,
      'recipient_profile_id', v_order.recipient_profile_id,
      'billing_profile_id', v_order.billing_profile_id,
      'placed_at', v_order.placed_at,
      'fulfilled_at', v_order.fulfilled_at,
      'shop_sell_currency_id', v_sell_currency_id,
      'shop_buy_currency_id', v_buy_currency_id,
      'shop_sell_currency_symbol', v_sell_symbol,
      'shop_buy_currency_symbol', v_buy_symbol
    )
    || jsonb_build_object(
      'created_at', v_order.created_at,
      'updated_at', v_order.updated_at,
      'cod_charge_amount', v_order.cod_charge_amount,
      'delivery_charge_amount', v_order.delivery_charge_amount,
      'print_charge_amount', v_order.print_charge_amount,
      'packing_charge_amount', v_order.packing_charge_amount,
      'discount_amount', v_order.discount_amount,
      'is_prepaid_snapshot', v_order.is_prepaid_snapshot,
      'delivery_instructions', v_order.delivery_instructions,
      'deduct_charges_from_margin', v_order.deduct_charges_from_margin,
      'deduct_cod_from_margin', v_order.deduct_cod_from_margin,
      'deduct_delivery_from_margin', v_order.deduct_delivery_from_margin,
      'deduct_print_from_margin', v_order.deduct_print_from_margin,
      'deduct_packing_from_margin', v_order.deduct_packing_from_margin,
      'item_count', v_item_count,
      'total_amount', v_total_amount,
      'cod_collect_amount', v_order.cod_collect_amount,
      'courier_name', v_order.courier_name,
      'courier_awb_number', v_order.courier_awb_number,
      'tracking_url', v_order.tracking_url,
      'payout_settlement_status', v_order.payout_settlement_status
    );

  return jsonb_build_object(
    'order', v_order_json,
    'items', v_items
  );
ALTER FUNCTION "public"."get_customer_shop_order"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dropship_shop_readiness"("p_shop_id" bigint) RETURNS TABLE("shop_id" bigint, "has_access_group_with_price" boolean, "has_customer_group_with_members" boolean, "has_billing_profile_linked" boolean, "has_listing_with_floor" boolean, "has_active_courier" boolean, "ready" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;

  v_has_access_group_with_price boolean := false;
  v_has_customer_group_with_members boolean := false;
  v_has_billing_profile_linked boolean := false;
  v_has_listing_with_floor boolean := false;
  v_has_active_courier boolean := false;
  v_ready boolean := false;
begin
  select tenant_id, shop_type
  into v_tenant_id, v_shop_type
  from public.shops
  where id = p_shop_id;

  if v_tenant_id is null then
    return;
  -- 1. Access group with can_set_dropship_price
  select coalesce(bool_or(
    access.status = true and coalesce(access.can_set_dropship_price, profile.default_can_set_dropship_price, false) = true
  ), false)
  into v_has_access_group_with_price
  from public.shop_customer_group_access access
  left join public.customer_group_shop_profiles profile
    on profile.customer_group_id = access.customer_group_id and profile.tenant_id = v_tenant_id
  where access.shop_id = p_shop_id;

  -- 2. Customer group with active members attached to shop access
  select exists (
    select 1
    from public.shop_customer_group_access access
    join public.customer_group_members cgm on cgm.customer_group_id = access.customer_group_id
    where access.shop_id = p_shop_id
      and access.status = true
  )
  into v_has_customer_group_with_members;

  -- 3. Billing profile linked (resolve_billing_profile_for_customer_group returns non-null for at least one linked group)
  select exists (
    select 1
    from public.shop_customer_group_access access
    where access.shop_id = p_shop_id
      and access.status = true
      and public.resolve_billing_profile_for_customer_group(v_tenant_id, access.customer_group_id) is not null
  )
  into v_has_billing_profile_linked;

  -- 4. Active listing with floor price set (minimum_sell_price_amount is not null and > 0)
  select exists (
    select 1
    from public.shop_product_listings
    where shop_id = p_shop_id
      and is_active = true
      and minimum_sell_price_amount is not null
      and minimum_sell_price_amount > 0
  )
  into v_has_listing_with_floor;

  -- 5. Active courier service available for tenant
  select exists (
    select 1
    from public.courier_services
    where tenant_id = v_tenant_id
      and is_active = true
  )
  into v_has_active_courier;

  v_ready := (
    v_has_access_group_with_price and
    v_has_customer_group_with_members and
    v_has_billing_profile_linked and
    v_has_listing_with_floor and
    v_has_active_courier
  );

  return query select
    p_shop_id,
    v_has_access_group_with_price,
    v_has_customer_group_with_members,
    v_has_billing_profile_linked,
    v_has_listing_with_floor,
    v_has_active_courier,
    v_ready;
ALTER FUNCTION "public"."get_dropship_shop_readiness"("p_shop_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dropship_finance_hub_data"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_summary jsonb;
  v_orders jsonb;
  v_merchants jsonb;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  v_summary := public.get_wallet_dashboard_summary(p_tenant_id);

  with finance_orders as (
    select
      o.id,
      o.order_no,
      o.recipient_name,
      o.status,
      o.cod_collect_amount,
      o.delivery_charge_amount,
      o.cod_charge_amount,
      o.driver_notes,
      o.courier_name,
      o.courier_remittance_ref,
      o.courier_bank_trx_id,
      o.billing_profile_id,
      o.created_at,
      o.collection_source,
      o.payout_settlement_status,
      o.is_prepaid_snapshot,
      o.global_invoice_id,
      s.name as shop_name,
      bp.name as billing_profile_name,
      inv.collection_source as invoice_collection_source,
      inv.total_amount as invoice_total_amount,
      inv.paid_amount as invoice_paid_amount
    from public.shop_orders o
    left join public.shops s on s.id = o.shop_id
    left join public.billing_profiles bp on bp.id = o.billing_profile_id
    left join public.sales_invoices inv on inv.id = o.global_invoice_id
    where o.tenant_id = p_tenant_id
      and o.shop_type_snapshot = 'dropship'
      and o.status in ('delivered', 'payment_received')
  ),
  ledger_flags as (
    select
      l.source_id,
      max(case when coalesce(l.metadata->>'purpose', '') = 'delivered_costing' then 1 else 0 end) as has_delivered_costing,
      max(case when coalesce(l.metadata->>'purpose', '') = 'courier_remittance' then 1 else 0 end) as has_remittance
    from public.universal_wallet_ledger l
    where l.tenant_id = p_tenant_id
      and l.source_type = 'shop_order'
      and l.source_id in (select fo.id::text from finance_orders fo)
    group by l.source_id
  ),
  order_rows as (
    select
      fo.id,
      fo.order_no as "orderNo",
      fo.recipient_name as "customerName",
      fo.shop_name as "shopName",
      fo.courier_name as "courierName",
      fo.status::text as status,
      case
        when fo.global_invoice_id is not null then coalesce(fo.invoice_total_amount, 0)
        else coalesce(fo.cod_collect_amount, 0)
      end as "totalAmount",
      coalesce(fo.cod_collect_amount, 0) as "codCollectAmount",
      coalesce(fo.delivery_charge_amount, 0) as "deliveryChargeAmount",
      coalesce(fo.cod_charge_amount, 0) as "codChargeAmount",
      fo.driver_notes as "courierNotes",
      fo.courier_remittance_ref as "courierRemittanceRef",
      fo.courier_bank_trx_id as "courierBankTrxId",
      fo.billing_profile_id as "billingProfileId",
      fo.billing_profile_name as "billingProfileName",
      fo.created_at as "createdAt",
      case
        when coalesce(lf.has_delivered_costing, 0) = 0 and fo.status::text = 'delivered' then 'delivered_costing'
        when fo.status::text = 'delivered'
          or (coalesce(lf.has_remittance, 0) = 0 and fo.status::text <> 'payment_received')
          then 'courier_remittance'
        else 'completed'
      end as "nextStep",
      coalesce(
        fo.collection_source,
        fo.invoice_collection_source,
        case when fo.is_prepaid_snapshot then 'billing_profile' else null end
      ) as "collectionSource",
      coalesce(fo.payout_settlement_status, 'unpaid') as "payoutSettlementStatus",
      case
        when fo.global_invoice_id is not null then greatest(coalesce(fo.invoice_total_amount, 0) - coalesce(fo.invoice_paid_amount, 0), 0)
        else null
      end as "invoiceOutstanding"
    from finance_orders fo
    left join ledger_flags lf on lf.source_id = fo.id::text
    order by fo.created_at desc
  )
  select coalesce(jsonb_agg(to_jsonb(order_rows)), '[]'::jsonb)
  into v_orders
  from order_rows;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', bp.id,
        'name', bp.name,
        'payableBalance', coalesce(wa.available_balance, 0)
      )
      order by bp.name
    ),
    '[]'::jsonb
  )
  into v_merchants
  from public.billing_profiles bp
  left join public.wallet_accounts wa
    on wa.tenant_id = p_tenant_id
   and wa.entity_type = 'customer'
   and wa.entity_id = bp.id
  where bp.tenant_id = p_tenant_id;

  return jsonb_build_object(
    'kpis', jsonb_build_object(
      'courierOwedTotal', coalesce((v_summary->>'courier_cod_holding_total')::numeric, 0),
      'tenantCashTotal', coalesce((v_summary->>'tenant_cash_total')::numeric, 0),
      'middlemanPayableTotal', coalesce((v_summary->>'merchant_available_total')::numeric, 0)
    ),
    'orders', coalesce(v_orders, '[]'::jsonb),
    'merchants', coalesce(v_merchants, '[]'::jsonb)
  );
end;
$$;


ALTER FUNCTION "public"."get_dropship_finance_hub_data"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dropship_wallet_reconciliation_report"("p_tenant_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_target_tenant_id bigint;
  v_missing_invoice_billed bigint := 0;
  v_missing_courier_remittance bigint := 0;
  v_missing_return_compensation bigint := 0;
  v_mixed_customer_profit bigint := 0;
  v_uncanonicalized_source_ids bigint := 0;
  v_conflicting_active_offers bigint := 0;
  v_missing_or_duplicate_gifts bigint := 0;
begin
  v_target_tenant_id := coalesce(p_tenant_id, public.current_tenant_id());

  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where (v_target_tenant_id is null or m.tenant_id = v_target_tenant_id)
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Admin or Staff role required for reconciliation report';
  -- 1. Posted dropship invoices missing invoice_billed (P0A contract)
  select count(*) into v_missing_invoice_billed
  from public.global_invoices i
  where i.invoice_type = 'dropship'
    and i.invoice_status = 'posted'
    and i.billing_profile_id is not null
    and i.total_amount > 0
    and (v_target_tenant_id is null or i.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.universal_wallet_ledger u
      where u.tenant_id = i.tenant_id
        and u.entity_type = 'customer'
        and u.entity_id = i.billing_profile_id
        and u.source_type = 'shop_order'
        and u.metadata->>'transaction_type' = 'invoice_billed'
        and (u.metadata->>'invoice_id' = i.id::text or u.source_id = i.invoice_no)
    );

  -- 2. Remitted shop orders missing courier remittance UWL entry
  select count(*) into v_missing_courier_remittance
  from public.shop_orders o
  where o.shop_type_snapshot = 'dropship'
    and o.status = 'payment_received'
    and o.courier_remittance_ref is not null
    and (v_target_tenant_id is null or o.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.universal_wallet_ledger u
      where u.tenant_id = o.tenant_id
        and u.entity_type = 'courier'
        and u.source_type = 'shop_order'
        and u.source_id = o.id::text
        and u.metadata->>'purpose' = 'courier_remittance'
    );

  -- 3. Finalized returns missing return compensating UWL entry
  select count(*) into v_missing_return_compensation
  from public.shop_orders o
  where o.shop_type_snapshot = 'dropship'
    and o.status = 'returned'
    and (v_target_tenant_id is null or o.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.universal_wallet_ledger u
      where u.tenant_id = o.tenant_id
        and u.source_type = 'shop_order'
        and u.source_id = o.id::text
        and (
          u.metadata->>'purpose' = 'dropship_return_finalize'
          or u.metadata->>'transaction_type' in (
            'return_reversal',
            'return_profit_clawback',
            'return_revenue_reversal'
          )
        )
    );

  -- 4. Mixed customer vs middleman profit rows
  select count(*) into v_mixed_customer_profit
  from public.universal_wallet_ledger u
  where u.entity_type = 'customer'
    and u.source_type = 'shop_order'
    and u.metadata->>'transaction_type' = 'dropship_profit'
    and (v_target_tenant_id is null or u.tenant_id = v_target_tenant_id);

  -- 5. Uncanonicalized source_ids (order_no instead of order_id string), exclude invoice_billed
  select count(*) into v_uncanonicalized_source_ids
  from public.universal_wallet_ledger u
  join public.shop_orders o on o.tenant_id = u.tenant_id and o.order_no = u.source_id
  where u.source_type = 'shop_order'
    and coalesce(u.metadata->>'transaction_type', '') <> 'invoice_billed'
    and (v_target_tenant_id is null or u.tenant_id = v_target_tenant_id);

  -- 6. Conflicting active offer prices (P2 shop_product_offers)
  select count(*) into v_conflicting_active_offers
  from (
    select shop_id, product_id, condition_bucket
    from public.shop_product_offers
    where is_active = true
    group by shop_id, product_id, condition_bucket
    having count(*) > 1
  ) t;

  -- 7. Duplicate gift redemptions for same (order, rule)
  select count(*) into v_missing_or_duplicate_gifts
  from (
    select order_id, rule_id
    from public.gift_rule_redemptions
    group by order_id, rule_id
    having count(*) > 1
  ) t;

  return jsonb_build_object(
    'reconciliation_time', now(),
    'tenant_id', v_target_tenant_id,
    'healthy', (
      v_missing_invoice_billed = 0 and
      v_missing_courier_remittance = 0 and
      v_missing_return_compensation = 0 and
      v_mixed_customer_profit = 0 and
      v_uncanonicalized_source_ids = 0 and
      v_conflicting_active_offers = 0 and
      v_missing_or_duplicate_gifts = 0
    ),
    'drift_counts', jsonb_build_object(
      'missing_invoice_billed', v_missing_invoice_billed,
      'missing_courier_remittance', v_missing_courier_remittance,
      'missing_return_compensation', v_missing_return_compensation,
      'mixed_customer_profit', v_mixed_customer_profit,
      'uncanonicalized_source_ids', v_uncanonicalized_source_ids,
      'conflicting_active_offers', v_conflicting_active_offers,
      'missing_or_duplicate_gifts', v_missing_or_duplicate_gifts
    )
  );
ALTER FUNCTION "public"."get_dropship_wallet_reconciliation_report"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_dropship_wallet_summary"() RETURNS TABLE("billing_profile_id" bigint, "available_balance" numeric, "pending_balance" numeric, "locked_balance" numeric, "currency" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_email text := public.current_user_email();
  v_group_id bigint;
  v_bp_id bigint;
  v_available numeric := 0;
  v_pending numeric := 0;
  v_locked numeric := 0;
begin
  if v_email is null or length(trim(v_email)) = 0 then
    raise exception 'Not authenticated';
  select cg.tenant_id, cgm.customer_group_id
  into v_tenant_id, v_group_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where lower(trim(cgm.email)) = lower(trim(v_email))
    and cgm.is_active = true
    and cg.is_active = true
  order by cgm.id
  limit 1;

  if v_tenant_id is null or v_group_id is null then
    raise exception 'No active customer group membership';
  v_bp_id := public.resolve_billing_profile_for_customer_group(v_tenant_id, v_group_id);
  if v_bp_id is null then
    raise exception 'No billing profile linked for your customer group';
  select coalesce(sum(
    case when u.type = 'credit' then u.amount else -u.amount end
  ), 0)
  into v_available
  from public.universal_wallet_ledger u
  where u.tenant_id = v_tenant_id
    and u.entity_id = v_bp_id
    and u.entity_type in ('middleman', 'customer');

  -- Pending: profit credits on delivered orders not yet remitted / unsettled (best-effort)
  select coalesce(sum(u.amount), 0)
  into v_pending
  from public.universal_wallet_ledger u
  join public.shop_orders o
    on o.id::text = u.source_id
   and o.tenant_id = u.tenant_id
  where u.tenant_id = v_tenant_id
    and u.entity_id = v_bp_id
    and u.entity_type in ('middleman', 'customer')
    and u.type = 'credit'
    and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit'
    and coalesce(o.payout_settlement_status, 'unpaid') in ('unpaid', 'partial')
    and o.status::text in ('delivered', 'payment_received', 'shipped', 'ready_for_pickup');

  -- Locked: remittance escrow style — delivered but courier not remitted
  select coalesce(sum(greatest(coalesce(o.cod_collect_amount, 0), 0)), 0)
  into v_locked
  from public.shop_orders o
  where o.tenant_id = v_tenant_id
    and o.billing_profile_id = v_bp_id
    and o.shop_type_snapshot = 'dropship'
    and o.status = 'delivered'
    and o.courier_remittance_ref is null
    and coalesce(o.collection_source, 'recipient') = 'recipient';

  return query select
    v_bp_id,
    v_available,
    v_pending,
    v_locked,
    'BDT'::text;
ALTER FUNCTION "public"."get_my_dropship_wallet_summary"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_or_create_shop_cart"("p_shop_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id         bigint;
  v_customer_group_id bigint;
  v_can_see_buy_price_snapshot boolean;
  v_can_see_sell_price_snapshot boolean;
  v_cart_id           bigint;
  v_result            jsonb;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id and is_active = true;
  if v_tenant_id is null then
    raise exception 'shop not found or inactive';
  select access.customer_group_id into v_customer_group_id
  from public.shop_customer_group_access access
  join public.customer_groups cg on cg.id = access.customer_group_id
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where access.shop_id = p_shop_id
    and access.status = true
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
  order by access.created_at asc
  limit 1;

  if v_customer_group_id is null then
    raise exception 'no customer group access found';
  if not public.can_customer_access_shop(p_shop_id) then
    raise exception 'access denied';

  select can_see_buy_price, can_see_sell_price
  into v_can_see_buy_price_snapshot, v_can_see_sell_price_snapshot
  from public.get_shop_permissions_for_customer(p_shop_id);

  select id into v_cart_id
  from public.shop_carts
  where tenant_id = v_tenant_id
    and shop_id = p_shop_id
    and customer_group_id = v_customer_group_id
    and status = 'active'
  order by id desc
  limit 1;

  if v_cart_id is null then
    insert into public.shop_carts (
      tenant_id, shop_id, customer_group_id, can_see_buy_price_snapshot, can_see_sell_price_snapshot, status, deduct_charges_from_margin,
      deduct_print_from_margin, deduct_packing_from_margin
    )
    values (
      v_tenant_id, p_shop_id, v_customer_group_id, v_can_see_buy_price_snapshot, v_can_see_sell_price_snapshot, 'active',
      (select deduct_charges_from_margin from public.shops where id = p_shop_id),
      (select deduct_print_from_margin from public.shops where id = p_shop_id),
      (select deduct_packing_from_margin from public.shops where id = p_shop_id)
    )
    returning id into v_cart_id;
  else
    update public.shop_carts
    set
      deduct_charges_from_margin = (select deduct_charges_from_margin from public.shops where id = p_shop_id),
      deduct_print_from_margin = (select deduct_print_from_margin from public.shops where id = p_shop_id),
      deduct_packing_from_margin = (select deduct_packing_from_margin from public.shops where id = p_shop_id)
    where id = v_cart_id;
  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'customer_group_id', c.customer_group_id,
      'can_see_buy_price_snapshot', c.can_see_buy_price_snapshot,
      'can_see_sell_price_snapshot', c.can_see_sell_price_snapshot,
      'status', c.status,
      'created_at', c.created_at,
      'updated_at', c.updated_at,
      'shop_type', s.shop_type,
      'allow_delivery', s.allow_delivery,
      'default_print_charge_amount', s.default_print_charge_amount,
      'default_packing_charge_amount', s.default_packing_charge_amount,
      'deduct_charges_from_margin', s.deduct_charges_from_margin,
      'deduct_print_from_margin', s.deduct_print_from_margin,
      'deduct_packing_from_margin', s.deduct_packing_from_margin
    ),
    'items', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'global_stock_id', ci.global_stock_id,
            'global_stock_allocation_id', ci.global_stock_allocation_id,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'minimum_order_quantity', p.minimum_order_quantity,
            'unit_list_price_amount', case when c.can_see_buy_price_snapshot then ci.unit_list_price_amount else null end,
            'unit_list_price_currency_id', case when c.can_see_buy_price_snapshot then ci.unit_list_price_currency_id else null end,
            'unit_sell_price_amount', case when c.can_see_sell_price_snapshot then ci.unit_sell_price_amount else null end,
            'unit_sell_price_currency_id', case when c.can_see_sell_price_snapshot then ci.unit_sell_price_currency_id else null end,
            'unit_minimum_sell_price_amount', case when c.can_see_sell_price_snapshot then ci.unit_minimum_sell_price_amount else null end,
            'unit_minimum_sell_price_currency_id', case when c.can_see_sell_price_snapshot then ci.unit_minimum_sell_price_currency_id else null end,
            'customer_sell_price_amount', case when c.can_see_sell_price_snapshot then ci.customer_sell_price_amount else null end,
            'customer_sell_price_currency_id', case when c.can_see_sell_price_snapshot then ci.customer_sell_price_currency_id else null end,
            'name', ci.name,
            'image_url', ci.image_url
          )
        )
        from public.shop_cart_items ci
        left join public.products p on p.id = ci.product_id
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  where c.id = v_cart_id;

  return v_result;
ALTER FUNCTION "public"."get_or_create_shop_cart"("p_shop_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shop_bootstrap_context"("p_email" "text" DEFAULT NULL::"text", "p_tenant_id" bigint DEFAULT NULL::bigint, "p_customer_group_member_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("member_id" bigint, "member_name" "text", "member_email" "text", "member_role" "public"."customer_group_role", "member_is_active" boolean, "customer_group_id" bigint, "customer_group_name" "text", "customer_group_is_active" boolean, "customer_group_accent_color" "text", "tenant_id" bigint, "tenant_name" "text", "tenant_slug" "text", "tenant_is_active" boolean, "active_module_keys" "text"[], "tenant_role_id" bigint, "is_admin" boolean, "effective_grants" "jsonb", "permission_version" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_email text;
  v_member record;
  v_grants jsonb;
  v_perm_version bigint;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email())));

  select
    cgm.id,
    coalesce(
      nullif(trim(cgm.name), ''),
      (select coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name') from auth.users u where u.email = v_email limit 1)
    ) as name,
    lower(trim(cgm.email)) as email,
    cgm.role,
    cgm.is_active,
    cgm.tenant_role_id,
    cg.id as customer_group_id,
    cg.name as customer_group_name,
    cg.is_active as customer_group_is_active,
    cg.accent_color as customer_group_accent_color,
    t.id as tenant_id,
    t.name as tenant_name,
    t.slug as tenant_slug,
    t.is_active as tenant_is_active,
    coalesce(tr.is_admin, cgm.role = 'admin', false) as is_admin
  into v_member
  from public.customer_group_members cgm
  inner join public.customer_groups cg on cg.id = cgm.customer_group_id
  inner join public.tenants t on t.id = cg.tenant_id
  left join public.tenant_roles tr on tr.id = cgm.tenant_role_id
  where p_tenant_id is not null
    and lower(trim(cgm.email)) = v_email
    and cgm.is_active = true
    and cg.is_active = true
    and t.is_active = true
    and cg.tenant_id = p_tenant_id
    and (p_customer_group_member_id is null or cgm.id = p_customer_group_member_id)
  order by
    case cgm.role
      when 'admin' then 1
      when 'negotiator' then 2
      when 'staff' then 3
      else 99
    end,
    cgm.id asc
  limit 1;

  if v_member.id is null then
    return;
  select coalesce(
    jsonb_agg(jsonb_build_object('module_key', module_key, 'action', action)),
    '[]'::jsonb
  )
  into v_grants
  from public.get_shop_effective_grants(v_member.tenant_id, v_member.id);

  select tpv.version into v_perm_version
  from public.tenant_permission_versions tpv
  where tpv.tenant_id = v_member.tenant_id;

  if v_perm_version is null then
    perform public.bump_tenant_permission_version(v_member.tenant_id);
    v_perm_version := 1;
  return query
  select
    v_member.id as member_id,
    v_member.name as member_name,
    v_member.email as member_email,
    v_member.role as member_role,
    v_member.is_active as member_is_active,
    v_member.customer_group_id,
    v_member.customer_group_name,
    v_member.customer_group_is_active,
    v_member.customer_group_accent_color,
    v_member.tenant_id,
    v_member.tenant_name,
    v_member.tenant_slug,
    v_member.tenant_is_active,
    coalesce(public.get_active_module_keys_for_tenant(v_member.tenant_id), array[]::text[]) as active_module_keys,
    v_member.tenant_role_id,
    v_member.is_admin,
    v_grants as effective_grants,
    v_perm_version as permission_version;
ALTER FUNCTION "public"."get_shop_bootstrap_context"("p_email" "text", "p_tenant_id" bigint, "p_customer_group_member_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shop_effective_grants"("p_tenant_id" bigint, "p_customer_group_member_id" bigint) RETURNS TABLE("module_key" "text", "action" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
  v_cgm_role public.customer_group_role;
begin
  select cgm.tenant_role_id, tr.is_admin, cgm.role
  into v_tenant_role_id, v_role_is_admin, v_cgm_role
  from public.customer_group_members cgm
  left join public.tenant_roles tr on tr.id = cgm.tenant_role_id
  where cgm.id = p_customer_group_member_id
    and cgm.is_active = true;

  if coalesce(v_role_is_admin, v_cgm_role = 'admin', false) = true then
    return query
    select ma.module_key, ma.action
    from public.module_actions ma
    join public.tenant_modules tm on tm.module_key = ma.module_key or tm.module_key = (
      select mo.parent_module_key from public.modules mo where mo.key = ma.module_key limit 1
    )
    where tm.tenant_id = p_tenant_id
      and tm.is_active = true
      and ma.is_active = true
      and ma.scope = 'shop';
    return;
  return query
  with role_allowed as (
    select rg.module_key, rg.action
    from public.tenant_role_grants rg
    where rg.tenant_role_id = v_tenant_role_id
      and rg.allowed = true
  ),
  with_overrides as (
    select ra.module_key, ra.action from role_allowed ra
    union
    select g.module_key, g.action
    from public.customer_group_member_grants g
    where g.customer_group_member_id = p_customer_group_member_id
      and g.effect = 'allow'
  ),
  effective as (
    select wo.module_key, wo.action from with_overrides wo
    except
    select g.module_key, g.action
    from public.customer_group_member_grants g
    where g.customer_group_member_id = p_customer_group_member_id
      and g.effect = 'deny'
  )
  select e.module_key, e.action
  from effective e
  join public.module_actions ma on ma.module_key = e.module_key and ma.action = e.action
  join public.tenant_modules tm on tm.module_key = e.module_key or tm.module_key = (
    select mo.parent_module_key from public.modules mo where mo.key = e.module_key limit 1
  )
  where tm.tenant_id = p_tenant_id
    and tm.is_active = true
    and ma.is_active = true
    and ma.scope = 'shop';
ALTER FUNCTION "public"."get_shop_effective_grants"("p_tenant_id" bigint, "p_customer_group_member_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shop_permissions_for_customer"("p_shop_id" bigint) RETURNS TABLE("can_browse" boolean, "can_see_buy_price" boolean, "can_see_sell_price" boolean, "can_see_resell_minimum_price" boolean, "can_add_to_cart" boolean, "can_place_order" boolean, "can_negotiate" boolean, "can_view_quantity" boolean, "can_set_dropship_price" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_active boolean;
  v_shop_type public.shop_type_enum;
  v_shop_allows_negotiate boolean;
begin
  select is_active, tenant_id, shop_type
  into v_shop_active, v_tenant_id, v_shop_type
  from public.shops
  where id = p_shop_id;

  if v_shop_active is not true then
    return query select false, false, false, false, false, false, false, false, false;
    return;
  end if;
  v_shop_allows_negotiate := v_shop_type = 'vendor_catalog';

  return query
  select
    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_browse, profile.default_can_browse, false)
      end
    ), false) as can_browse,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else
        case when v_shop_type = 'dropship' then true
        else coalesce(access.can_see_buy_price, profile.default_can_see_buy_price, false)
        end
      end
    ), false) as can_see_buy_price,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else
        case when v_shop_type = 'dropship' then true
        else coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
        end
      end
    ), false) as can_see_sell_price,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_see_resell_minimum_price, profile.default_can_see_resell_minimum_price, false)
      end
    ), false) as can_see_resell_minimum_price,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_add_to_cart, profile.default_can_add_to_cart, false)
      end
    ), false) as can_add_to_cart,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_place_order, profile.default_can_place_order, false)
      end
    ), false) as can_place_order,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_negotiate, profile.default_can_negotiate, false)
      end
    ) and v_shop_allows_negotiate, false) as can_negotiate,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_view_quantity, profile.default_can_view_quantity, false)
      end
    ), false) as can_view_quantity,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else
        case when v_shop_type = 'dropship' then true
        else coalesce(access.can_set_dropship_price, profile.default_can_set_dropship_price, false)
        end
      end
    ), false) as can_set_dropship_price
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  join public.shop_customer_group_access access on access.customer_group_id = cg.id
  left join public.customer_group_shop_profiles profile
    on profile.customer_group_id = cg.id and profile.tenant_id = v_tenant_id
  where access.shop_id = p_shop_id
    and cg.tenant_id = v_tenant_id
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email();
end;
$$;


ALTER FUNCTION "public"."get_shop_permissions_for_customer"("p_shop_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_cart_owner"("p_customer_group_id" bigint, "p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    p_customer_group_id is not null
    and public.current_customer_group_id(p_tenant_id) = p_customer_group_id;
ALTER FUNCTION "public"."is_cart_owner"("p_customer_group_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_allocations_for_shop_pick"("p_tenant_id" bigint, "p_shop_id" bigint) RETURNS TABLE("allocation_id" bigint, "stock_id" bigint, "product_id" bigint, "product_name" "text", "product_image_url" "text", "product_barcode" "text", "product_code" "text", "product_brand" "text", "product_category" "text", "allocated_quantity" integer, "minimum_sell_price_amount" numeric, "minimum_sell_price_currency_id" bigint, "unit_cost_amount" numeric, "shipment_item_id" bigint, "shipment_id" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  -- Caller must be member of this tenant
  if not exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  return query
  select
    gsa.id as allocation_id,
    gsa.stock_id,
    gsi.product_id,
    p.name as product_name,
    p.image_url as product_image_url,
    p.barcode as product_barcode,
    p.product_code as product_code,
    p.brand as product_brand,
    p.category as product_category,
    gsa.quantity as allocated_quantity,
    coalesce(
      public.calculate_landed_unit_cost(gs.shipment_item_id),
      gsi.purchase_price * coalesce(gship.product_conversion_rate, 1.0),
      0.00
    )::numeric as minimum_sell_price_amount,
    (select default_currency_id from public.shops where id = p_shop_id) as minimum_sell_price_currency_id,
    coalesce(
      public.calculate_landed_unit_cost(gs.shipment_item_id),
      gsi.purchase_price * coalesce(gship.product_conversion_rate, 1.0),
      0.00
    )::numeric as unit_cost_amount,
    gs.shipment_item_id,
    gsi.shipment_id
  from public.global_stock_allocations gsa
  join public.global_stocks gs on gs.id = gsa.stock_id
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  join public.global_shipments gship on gship.id = gsi.shipment_id
  join public.products p on p.id = gsi.product_id
  where gsa.child_tenant_id = p_tenant_id
    and not exists (
      select 1 from public.shop_product_listings spl
      where spl.shop_id = p_shop_id
        and spl.global_stock_allocation_id = gsa.id
    )
  order by p.name asc;
ALTER FUNCTION "public"."list_allocations_for_shop_pick"("p_tenant_id" bigint, "p_shop_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_allocations_for_shop_pick"("p_shop_id" bigint, "p_search" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select jsonb_build_object('data', '[]'::jsonb, 'total', 0);
ALTER FUNCTION "public"."list_allocations_for_shop_pick"("p_shop_id" bigint, "p_search" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_customer_active_carts"("p_tenant_id" bigint) RETURNS TABLE("cart_id" bigint, "shop_id" bigint, "shop_name" "text", "shop_slug" "text", "shop_logo_url" "text", "shop_type" "text", "can_see_buy_price" boolean, "can_see_sell_price" boolean, "currency_id" bigint, "currency_code" "text", "currency_symbol" "text", "item_count" bigint, "cart_total" numeric, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    c.id as cart_id,
    s.id as shop_id,
    s.name as shop_name,
    s.slug as shop_slug,
    null::text as shop_logo_url,
    s.shop_type::text as shop_type,
    c.can_see_buy_price_snapshot as can_see_buy_price,
    c.can_see_sell_price_snapshot as can_see_sell_price,
    s.sell_currency_id as currency_id,
    gc.code as currency_code,
    gc.symbol as currency_symbol,
    coalesce(sum(ci.quantity), 0)::bigint as item_count,
    case
      when c.can_see_sell_price_snapshot then
        sum(
          ci.quantity * coalesce(
            ci.customer_sell_price_amount,
            ci.unit_sell_price_amount,
            ci.unit_list_price_amount,
            0
          )
        )::numeric
      else null
    end as cart_total,
    c.updated_at
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  join public.shop_cart_items ci on ci.cart_id = c.id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where p_tenant_id is not null
    and c.status = 'active'
    and c.tenant_id = p_tenant_id
    and c.customer_group_id = public.current_customer_group_id(p_tenant_id)
  group by c.id, s.id, gc.code, gc.symbol
  order by c.updated_at desc;
ALTER FUNCTION "public"."list_customer_active_carts"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_customer_shop_orders"("p_tenant_id" bigint, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0, "p_status_bucket" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "shop_id" bigint, "shop_name" "text", "shop_slug" "text", "shop_type_snapshot" "public"."shop_type_enum", "order_no" "text", "status" "public"."shop_order_status", "item_count" bigint, "can_see_buy_price" boolean, "can_see_sell_price" boolean, "sell_currency_id" bigint, "currency_symbol" "text", "total_amount" numeric, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_group_id bigint;
  v_limit integer;
  v_offset integer;
begin
  if p_tenant_id is null then
    return;
  end if;

  if p_status_bucket is not null
     and p_status_bucket not in ('needs_you', 'in_progress', 'done') then
    return;
  end if;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  if v_group_id is null then
    return;
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  return query
  select
    o.id,
    o.shop_id,
    s.name as shop_name,
    s.slug as shop_slug,
    o.shop_type_snapshot,
    o.order_no,
    o.status,
    (
      select count(*)::bigint
      from public.shop_order_items soi
      where soi.order_id = o.id
    ) as item_count,
    case
      when o.shop_type_snapshot = 'dropship' then true
      when o.cart_id is not null then coalesce(c.can_see_buy_price_snapshot, false)
      else coalesce(live_perm.can_see_buy_price, false)
    end as can_see_buy_price,
    case
      when o.shop_type_snapshot = 'dropship' then true
      when o.cart_id is not null then coalesce(c.can_see_sell_price_snapshot, false)
      else coalesce(live_perm.can_see_sell_price, false)
    end as can_see_sell_price,
    s.sell_currency_id,
    gc.symbol as currency_symbol,
    case
      when (
        case
          when o.shop_type_snapshot = 'dropship' then true
          when o.cart_id is not null then coalesce(c.can_see_sell_price_snapshot, false)
          else coalesce(live_perm.can_see_sell_price, false)
        end
      ) then
        coalesce(
          (
            select sum(
              coalesce(
                soi.final_price_amount,
                soi.customer_offer_amount,
                soi.unit_sell_price_amount,
                soi.unit_list_price_amount
              ) * soi.quantity
            )
            from public.shop_order_items soi
            where soi.order_id = o.id
          ),
          0
        )::numeric
      else null
    end as total_amount,
    o.created_at
  from public.shop_orders o
  join public.shops s on s.id = o.shop_id
  left join public.shop_carts c on c.id = o.cart_id
  left join lateral (
    select p.can_see_buy_price, p.can_see_sell_price
    from public.get_shop_permissions_for_customer(o.shop_id) p
    limit 1
  ) live_perm on true
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where o.tenant_id = p_tenant_id
    and o.customer_group_id = v_group_id
    and o.status is distinct from 'draft'
    and (
      p_status_bucket is null
      or (
        p_status_bucket = 'needs_you'
        and o.status in ('priced', 'countered', 'final_offered')
      )
      or (
        p_status_bucket = 'done'
        and o.status in ('fulfilled', 'delivered', 'payment_received', 'cancelled', 'returned')
      )
      or (
        p_status_bucket = 'in_progress'
        and o.status not in (
          'draft',
          'priced',
          'negotiating',
          'countered',
          'final_offered',
          'fulfilled',
          'delivered',
          'payment_received',
          'cancelled',
          'returned'
        )
      )
    )
  order by o.created_at desc
  limit v_limit
  offset v_offset;
end;
$$;
ALTER FUNCTION "public"."list_customer_shop_orders"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_status_bucket" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_customer_shops"("p_tenant_id" bigint) RETURNS TABLE("id" bigint, "tenant_id" bigint, "name" "text", "slug" "text", "shop_type" "public"."shop_type_enum", "order_mode" "public"."shop_order_mode_enum", "is_negotiable" boolean, "can_see_buy_price" boolean, "can_see_sell_price" boolean, "description" "text", "category_ids" bigint[], "categories" "jsonb", "sell_currency_id" bigint, "sell_currency_code" "text", "sell_currency_symbol" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.order_mode,
    s.is_negotiable,
    bool_or(
      case
        when access.status = false or coalesce(profile.is_active, true) = false then false
        when s.shop_type = 'dropship' then true
        else coalesce(access.can_see_buy_price, profile.default_can_see_buy_price, false)
      end
    ) as can_see_buy_price,
    bool_or(
      case
        when access.status = false or coalesce(profile.is_active, true) = false then false
        when s.shop_type = 'dropship' then true
        else coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
      end
    ) as can_see_sell_price,
    s.description,
    s.category_ids,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', c.id,
            'name', c.name,
            'slug', c.slug,
            'icon', c.icon
          )
        )
        from public.shop_categories c
        where c.id = any(s.category_ids)
          and c.is_active = true
      ),
      '[]'::jsonb
    ) as categories,
    s.sell_currency_id,
    gc.code as sell_currency_code,
    gc.symbol as sell_currency_symbol
  from public.shops s
  join public.shop_customer_group_access access on access.shop_id = s.id
  join public.customer_groups cg on cg.id = access.customer_group_id
  left join public.customer_group_shop_profiles profile
    on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where p_tenant_id is not null
    and s.is_active = true
    and s.deleted_at is null
    and s.tenant_id = p_tenant_id
    and cg.id = public.current_customer_group_id(p_tenant_id)
    and cg.is_active = true
    and access.status = true
    and coalesce(profile.is_active, true) = true
    and coalesce(access.can_browse, profile.default_can_browse, false) = true
  group by
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.order_mode,
    s.is_negotiable,
    s.description,
    s.category_ids,
    s.sell_currency_id,
    gc.code,
    gc.symbol
  order by s.name asc;
ALTER FUNCTION "public"."list_customer_shops"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_dropship_shop_orders_for_staff"("p_tenant_id" bigint, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0, "p_status" "text" DEFAULT NULL::"text", "p_search" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "order_no" "text", "status" "public"."shop_order_status", "created_at" timestamp with time zone, "customer_group_name" "text", "created_by_email" "text", "recipient_name" "text", "recipient_phone" "text", "courier_name" "text", "courier_awb_number" "text", "cod_collect_amount" numeric, "total_amount" numeric, "global_invoice_id" bigint, "courier_remittance_ref" "text", "collection_source" "public"."collection_source_type", "payout_settlement_status" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  return query
  select
    o.id,
    o.order_no,
    o.status,
    o.created_at,
    cg.name as customer_group_name,
    o.created_by_email,
    o.recipient_name,
    o.recipient_phone,
    coalesce(cs.name, o.courier_name) as courier_name,
    o.courier_awb_number,
    o.cod_collect_amount,
    coalesce(
      (
        select sum(
          coalesce(
            final_price_amount,
            staff_offer_amount,
            customer_offer_amount,
            unit_sell_price_amount,
            unit_list_price_amount
          ) * quantity
        )
        from public.shop_order_items
        where order_id = o.id
      ),
      0
    )::numeric as total_amount,
    o.global_invoice_id,
    o.courier_remittance_ref,
    o.collection_source,
    o.payout_settlement_status
  from public.shop_orders o
  join public.customer_groups cg on cg.id = o.customer_group_id
  left join public.courier_services cs on cs.id::text = o.courier_service_id::text
  where o.tenant_id = p_tenant_id
    and o.shop_type_snapshot = 'dropship'
    and (
      case
        when p_status is null then o.status::text in (
          'submitted',
          'confirmed',
          'placed',
          'processing',
          'ready_for_pickup',
          'shipped',
          'delivered',
          'returned',
          'payment_received'
        )
        else o.status::text = p_status
      end
    )
    and (
      p_search is null
      or o.order_no ilike ('%' || p_search || '%')
      or o.recipient_name ilike ('%' || p_search || '%')
      or o.recipient_phone ilike ('%' || p_search || '%')
      or o.courier_awb_number ilike ('%' || p_search || '%')
      or o.courier_name ilike ('%' || p_search || '%')
      or cs.name ilike ('%' || p_search || '%')
      or cg.name ilike ('%' || p_search || '%')
      or o.created_by_email ilike ('%' || p_search || '%')
    )
  order by o.created_at desc
  limit p_limit
  offset p_offset;
ALTER FUNCTION "public"."list_dropship_shop_orders_for_staff"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_status" "text", "p_search" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_listable_stock_for_shop"("p_shop_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_tenant_id bigint;
  begin
  select s.tenant_id into v_shop_tenant_id
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;
  if v_shop_tenant_id is null then
    raise exception 'shop not found';
  if not public.has_active_tenant_membership(v_shop_tenant_id)
     and not public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_shop_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not authorized';
  select count(distinct gs.id)
  into v_total_count
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.stock_locations sl on sl.id = gs.location_id
  where gship.assigned_child_tenant_id = v_shop_tenant_id
    and gship.status = 'received'
    and gs.availability = 'sellable'::public.stock_availability
    and (gs.location_id is null or sl.is_pickable = true)
    and public.global_stock_atp_qty(gs.id) > 0
    and not exists (
      select 1 from public.shop_product_listings spl
      where spl.shop_id = p_shop_id
        and spl.global_stock_id = gs.id
        and spl.is_active = true
    )
    and (
      p_search is null or p_search = '' or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
      )
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id as sort_id,
      jsonb_build_object(
        'global_stock_id', gs.id,
        'shipment_item_id', gsi.id,
        'shipment_id', gship.id,
        'shipment_name', gship.name,
        'item_name', gsi.name,
        'product_id', gsi.product_id,
        'product_code', gsi.product_code,
        'barcode', gsi.barcode,
        'image_url', gsi.image_url,
        'available_atp', public.global_stock_atp_qty(gs.id),
        'total_stock_qty', gs.quantity,
        'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00)
      ) as row_json
    from public.global_stocks gs
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.stock_locations sl on sl.id = gs.location_id
    where gship.assigned_child_tenant_id = v_shop_tenant_id
      and gship.status = 'received'
      and gs.availability = 'sellable'::public.stock_availability
      and (gs.location_id is null or sl.is_pickable = true)
      and public.global_stock_atp_qty(gs.id) > 0
      and not exists (
        select 1 from public.shop_product_listings spl
        where spl.shop_id = p_shop_id
          and spl.global_stock_id = gs.id
          and spl.is_active = true
      )
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
    order by gs.id desc
    limit p_limit
    offset p_offset
  ) q;

  return jsonb_build_object(
    'data', v_data,
    'total', v_total_count
  );
ALTER FUNCTION "public"."list_listable_stock_for_shop"("p_shop_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_my_dropship_wallet_ledger"("p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" "text", "created_at" timestamp with time zone, "transaction_type" "text", "amount" numeric, "balance_after" numeric, "source_id" "text", "order_id" bigint, "note" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_email text := public.current_user_email();
  v_group_id bigint;
  v_bp_id bigint;
begin
  if v_email is null or length(trim(v_email)) = 0 then
    raise exception 'Not authenticated';
  select cg.tenant_id, cgm.customer_group_id
  into v_tenant_id, v_group_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where lower(trim(cgm.email)) = lower(trim(v_email))
    and cgm.is_active = true
    and cg.is_active = true
  order by cgm.id
  limit 1;

  if v_tenant_id is null then
    raise exception 'No active customer group membership';
  v_bp_id := public.resolve_billing_profile_for_customer_group(v_tenant_id, v_group_id);
  if v_bp_id is null then
    raise exception 'No billing profile linked for your customer group';
  return query
  select
    u.id::text,
    u.created_at,
    coalesce(u.metadata->>'transaction_type', u.metadata->>'purpose', u.type)::text as transaction_type,
    case when u.type = 'debit' then -u.amount else u.amount end,
    u.balance_after,
    u.source_id,
    case
      when u.source_type = 'shop_order' and u.source_id ~ '^[0-9]+$' then u.source_id::bigint
      else null
    end as order_id,
    coalesce(u.metadata->>'notes', u.metadata->>'note', '')::text as note
  from public.universal_wallet_ledger u
  where u.tenant_id = v_tenant_id
    and u.entity_id = v_bp_id
    and u.entity_type in ('middleman', 'customer')
  order by u.created_at desc, u.id desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
$_$;


ALTER FUNCTION "public"."list_my_dropship_wallet_ledger"("p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_procurement_shop_order_lines"("p_parent_tenant_id" bigint, "p_child_tenant_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 100, "p_offset" integer DEFAULT 0) RETURNS TABLE("source_type" "text", "source_id" bigint, "child_tenant_id" bigint, "child_tenant_name" "text", "name" "text", "product_id" bigint, "quantity" integer, "cost_bdt" numeric, "price_gbp" numeric, "image_url" "text", "barcode" "text", "product_code" "text", "reference_label" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  return query
  select
    'shop_order_item'::text as source_type,
    oi.id as source_id,
    o.tenant_id as child_tenant_id,
    t.name as child_tenant_name,
    oi.name,
    oi.product_id,
    greatest(coalesce(oi.ordered_quantity, 0), 0)::integer as quantity,
    case when gc.code = 'BDT' then oi.final_price_amount else null::numeric end as cost_bdt,
    case when gc.code = 'GBP' then oi.final_price_amount else null::numeric end as price_gbp,
    oi.image_url,
    p.barcode,
    p.product_code,
    ('Shop Order #' || o.order_no || ' — ' || o.name) as reference_label
  from public.shop_order_items oi
  inner join public.shop_orders o on o.id = oi.order_id
  inner join public.tenants t on t.id = o.tenant_id
  left join public.products p on p.id = oi.product_id
  left join public.global_currencies gc on gc.id = oi.final_price_currency_id
  where o.status = 'placed'
    and oi.procurement_pulled = false
    and o.shop_type_snapshot = 'vendor_catalog'
    and t.parent_id = p_parent_tenant_id
    and (p_child_tenant_id is null or o.tenant_id = p_child_tenant_id)
    and (
      p_search is null or trim(p_search) = ''
      or oi.name ilike '%' || trim(p_search) || '%'
      or o.name ilike '%' || trim(p_search) || '%'
    )
  order by t.name, oi.id
  limit greatest(coalesce(p_limit, 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
ALTER FUNCTION "public"."list_procurement_shop_order_lines"("p_parent_tenant_id" bigint, "p_child_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shop_orders_for_staff"("p_tenant_id" bigint, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_shop_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "tenant_id" bigint, "shop_id" bigint, "shop_name" "text", "customer_group_id" bigint, "customer_group_name" "text", "order_no" "text", "name" "text", "status" "public"."shop_order_status", "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "item_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  return query
  select
    o.id,
    o.tenant_id,
    o.shop_id,
    s.name as shop_name,
    o.customer_group_id,
    cg.name as customer_group_name,
    o.order_no,
    o.name,
    o.status,
    o.created_at,
    o.updated_at,
    (select count(*)::bigint from public.shop_order_items where order_id = o.id) as item_count
  from public.shop_orders o
  join public.shops s on s.id = o.shop_id
  join public.customer_groups cg on cg.id = o.customer_group_id
  where o.tenant_id = p_tenant_id
    and (p_status is null or o.status::text = p_status)
    and (p_shop_id is null or o.shop_id = p_shop_id)
    and (
      p_search is null
      or o.order_no ilike ('%' || p_search || '%')
      or o.name ilike ('%' || p_search || '%')
      or s.name ilike ('%' || p_search || '%')
      or cg.name ilike ('%' || p_search || '%')
    )
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;
ALTER FUNCTION "public"."list_shop_orders_for_staff"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_status" "text", "p_shop_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shop_product_listings"("p_shop_id" bigint) RETURNS TABLE("id" bigint, "tenant_id" bigint, "shop_id" bigint, "global_stock_allocation_id" bigint, "global_stock_id" bigint, "product_id" bigint, "sell_price_amount" numeric, "sell_price_currency_id" bigint, "minimum_sell_price_amount" numeric, "minimum_sell_price_currency_id" bigint, "show_quantity" boolean, "display_quantity_override" integer, "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "product_name" "text", "product_image_url" "text", "product_barcode" "text", "product_code" "text", "product_brand" "text", "product_category" "text", "allocated_quantity" integer, "available_to_sell" integer, "unit_cost_amount" numeric, "shipment_item_id" bigint, "shipment_id" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select s.tenant_id into v_tenant_id
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;
  if v_tenant_id is null then
    raise exception 'shop not found';
  if not public.has_active_tenant_membership(v_tenant_id)
     and not public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  return query
  select
    l.id,
    l.tenant_id,
    l.shop_id,
    l.global_stock_allocation_id,
    coalesce(l.global_stock_id, gs.id) as global_stock_id,
    l.product_id,
    l.sell_price_amount,
    l.sell_price_currency_id,
    l.minimum_sell_price_amount,
    l.minimum_sell_price_currency_id,
    l.show_quantity,
    l.display_quantity_override,
    l.is_active,
    l.created_at,
    l.updated_at,
    gsi.name as product_name,
    gsi.image_url as product_image_url,
    gsi.barcode as product_barcode,
    gsi.product_code as product_code,
    p.brand as product_brand,
    p.category as product_category,
    gs.quantity::integer as allocated_quantity,
    greatest(0, floor(public.global_stock_atp_qty(coalesce(l.global_stock_id, gs.id))))::integer as available_to_sell,
    coalesce(public.calculate_landed_unit_cost(gs.shipment_item_id), 0.00)::numeric as unit_cost_amount,
    gs.shipment_item_id as shipment_item_id,
    gsi.shipment_id as shipment_id
  from public.shop_product_listings l
  left join public.products p on p.id = l.product_id
  left join public.global_stocks gs on gs.id = l.global_stock_id
  left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where l.shop_id = p_shop_id
  order by gsi.name asc;
ALTER FUNCTION "public"."list_shop_product_listings"("p_shop_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shops"("p_tenant_id" bigint, "p_limit" integer DEFAULT 200, "p_offset" integer DEFAULT 0, "p_search" "text" DEFAULT NULL::"text", "p_active" boolean DEFAULT NULL::boolean) RETURNS TABLE("id" bigint, "tenant_id" bigint, "name" "text", "slug" "text", "shop_type" "public"."shop_type_enum", "vendor_code" "text", "order_mode" "public"."shop_order_mode_enum", "is_negotiable" boolean, "show_stock_quantity" boolean, "default_currency_id" bigint, "global_stock_type_id" bigint, "is_active" boolean, "allow_delivery" boolean, "buy_currency_id" bigint, "sell_currency_id" bigint, "pricing_method" "text", "markup_percentage" numeric, "quantity_display_mode" "text", "default_print_charge_amount" numeric, "default_packing_charge_amount" numeric, "deduct_charges_from_margin" boolean, "vendor_filters" "jsonb", "deduct_print_from_margin" boolean, "deduct_packing_from_margin" boolean, "description" "text", "category_ids" bigint[], "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "total_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total bigint;
begin
  if not exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  select count(*)
  into v_total
  from public.shops s
  where s.tenant_id = p_tenant_id
    and s.deleted_at is null
    and (p_active  is null or s.is_active = p_active)
    and (p_search  is null or s.name ilike '%' || p_search || '%' or s.slug ilike '%' || p_search || '%');

  return query
  select
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.vendor_code,
    s.order_mode,
    s.is_negotiable,
    s.show_stock_quantity,
    s.default_currency_id,
    s.global_stock_type_id,
    s.is_active,
    s.allow_delivery,
    s.buy_currency_id,
    s.sell_currency_id,
    s.pricing_method,
    s.markup_percentage,
    s.quantity_display_mode,
    s.default_print_charge_amount,
    s.default_packing_charge_amount,
    s.deduct_charges_from_margin,
    s.vendor_filters,
    s.deduct_print_from_margin,
    s.deduct_packing_from_margin,
    s.description,
    s.category_ids,
    s.created_at,
    s.updated_at,
    v_total
  from public.shops s
  where s.tenant_id = p_tenant_id
    and s.deleted_at is null
    and (p_active  is null or s.is_active = p_active)
    and (p_search  is null or s.name ilike '%' || p_search || '%' or s.slug ilike '%' || p_search || '%')
  order by s.name asc
  limit  p_limit
  offset p_offset;
ALTER FUNCTION "public"."list_shops"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_dropship_order_returned"("p_order_id" bigint, "p_actual_return_charge" numeric, "p_deduct_from_middle_man" boolean, "p_reason" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_items jsonb;
begin
  select jsonb_agg(
    jsonb_build_object(
      'order_item_id', id,
      'returned_qty', greatest(coalesce(delivered_quantity, quantity) - coalesce(returned_quantity, 0), 0),
      'condition', 'perfect'
    )
  )
  into v_items
  from public.shop_order_items
  where order_id = p_order_id;

  return public.finalize_dropship_return(
    p_order_id => p_order_id,
    p_items => coalesce(v_items, '[]'::jsonb),
    p_actual_return_charge => coalesce(p_actual_return_charge, 0.00),
    p_deduct_from_middle_man => coalesce(p_deduct_from_middle_man, true),
    p_override_reason => p_reason,
    p_return_ref => 'AUTO-RET-' || p_order_id::text || '-' || extract(epoch from now())::bigint
  );
ALTER FUNCTION "public"."mark_dropship_order_returned"("p_order_id" bigint, "p_actual_return_charge" numeric, "p_deduct_from_middle_man" boolean, "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."place_shop_order_for_procurement"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_status public.shop_order_status;
  v_type public.shop_type_enum;
begin
  select tenant_id, status, shop_type_snapshot
  into v_tenant_id, v_status, v_type
  from public.shop_orders
  where id = p_order_id;

  if v_tenant_id is null then
    raise exception 'order not found';
  if not public.is_tenant_staff(v_tenant_id) then
    raise exception 'access denied';
  if v_type <> 'vendor_catalog' then
    raise exception 'only vendor catalog orders can be placed for procurement';
  if v_status <> 'confirmed' then
    raise exception 'order must be confirmed before placing';
  update public.shop_orders
  set status = 'placed',
      placed_at = now(),
      updated_at = now()
  where id = p_order_id;
ALTER FUNCTION "public"."place_shop_order_for_procurement"("p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_dropship_courier_remittance_uwl"("p_order_id" bigint, "p_net_amount" numeric, "p_courier_charge" numeric DEFAULT 0.00, "p_remittance_ref" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_courier_id bigint := 0;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_currency text;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  v_currency := 'BDT';
  v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);

  -- Resolve courier entity ID from courier_services if available
  if v_order.courier_service_id is not null then
    select coalesce(wallet_entity_id, 0) into v_courier_id
    from public.courier_services
    where id = v_order.courier_service_id;
    
    if v_courier_id is null then
      v_courier_id := 0;
    else
    v_courier_id := 0;
  -- Leg 1: Courier Debit (reduces courier liability)
  if not exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'courier_remittance'
  ) then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'debit',
      p_amount => greatest(v_cod, p_net_amount + v_charge),
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'purpose', 'courier_remittance',
        'order_no', v_order.order_no,
        'courier_charge', v_charge,
        'net_remitted', p_net_amount,
        'remittance_ref', p_remittance_ref,
        'courier_service_id', v_order.courier_service_id
      )
    );
  -- Leg 2: Tenant Credit (tenant received net remitted cash)
  if not exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and entity_type = 'tenant'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_order.tenant_id,
      p_type => 'credit',
      p_amount => p_net_amount,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'purpose', 'tenant_remittance_received',
        'order_no', v_order.order_no,
        'gross_cod', v_cod,
        'courier_charge', v_charge,
        'remittance_ref', p_remittance_ref
      )
    );
  ALTER FUNCTION "public"."process_dropship_courier_remittance_uwl"("p_order_id" bigint, "p_net_amount" numeric, "p_courier_charge" numeric, "p_remittance_ref" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_dropship_shop_order"("p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_order public.shop_orders%rowtype;
begin
  -- Fetch order
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Only dropship orders can be handed off to the dropship desk');
  if v_order.status <> 'confirmed' then
    return jsonb_build_object('success', false, 'error', 'Only confirmed orders can be handed off to the dropship desk');
  -- Update status to processing (merchant details will be added later)
  update public.shop_orders
  set
    status = 'processing',
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'new_status', 'processing'
  );
ALTER FUNCTION "public"."process_dropship_shop_order"("p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_dropship_courier_remittance"("p_order_id" bigint, "p_net_amount" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text" DEFAULT NULL::"text", "p_payment_date" "date" DEFAULT NULL::"date", "p_method" "text" DEFAULT 'cash'::"text", "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_ref text;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.status <> 'delivered' then
    raise exception 'Courier remittance requires order status delivered (current: %)', v_order.status;
  if v_order.global_invoice_id is null then
    raise exception 'Accounting invoice is required before recording courier remittance';
  v_ref := nullif(trim(coalesce(p_remittance_ref, '')), '');
  if v_ref is null then
    raise exception 'Remittance reference is required';
  if coalesce(p_net_amount, 0.00) <= 0.00 then
    raise exception 'Net remittance amount must be positive';
  select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id for update;
  -- Same money-in path as record_recipient_invoice_collection
  insert into public.global_payments (
    tenant_id,
    billing_profile_id,
    collection_source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    v_invoice.tenant_id,
    null,
    'recipient'::public.collection_source_type,
    p_net_amount,
    0.00,
    coalesce(p_payment_date, current_date),
    coalesce(nullif(trim(p_method), ''), 'cash'),
    v_ref,
    coalesce(
      nullif(trim(p_note), ''),
      'Courier remittance order #' || v_order.order_no
        || coalesce(' bank:' || nullif(trim(p_bank_trx_id), ''), '')
    )
  )
  returning id into v_payment_id;

  insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
  values (v_invoice.tenant_id, v_payment_id, v_order.global_invoice_id, p_net_amount);

  update public.global_invoices
  set
    paid_amount = coalesce(paid_amount, 0.00) + p_net_amount,
    note = coalesce(nullif(trim(p_note), ''), note),
    updated_at = now()
  where id = v_order.global_invoice_id;

  perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);

  update public.shop_orders
  set
    status = 'payment_received'::public.shop_order_status,
    courier_remittance_ref = v_ref,
    courier_bank_trx_id = coalesce(nullif(trim(p_bank_trx_id), ''), courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_order.global_invoice_id,
    'payment_id', v_payment_id,
    'order_id', p_order_id,
    'status', 'payment_received'
  );
ALTER FUNCTION "public"."record_dropship_courier_remittance"("p_order_id" bigint, "p_net_amount" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text", "p_payment_date" "date", "p_method" "text", "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_dropship_courier_remittance"("p_order_id" bigint, "p_net_amount" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text" DEFAULT NULL::"text", "p_payment_date" "date" DEFAULT NULL::"date", "p_method" "text" DEFAULT 'cash'::"text", "p_note" "text" DEFAULT NULL::"text", "p_courier_charge" numeric DEFAULT 0.00) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_ref text;
  v_cod numeric(12,2);
  v_charge numeric(12,2);
  v_net numeric(12,2);
  v_invoice_due numeric(12,2);
  v_invoice_pay numeric(12,2);
  v_profit_hold numeric(12,2);
  v_currency text := 'BDT';
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.status <> 'delivered' then
    raise exception 'Courier remittance requires order status delivered (current: %)', v_order.status;
  if v_order.global_invoice_id is null then
    raise exception 'Accounting invoice is required before recording courier remittance';
  v_ref := nullif(trim(coalesce(p_remittance_ref, '')), '');
  if v_ref is null then
    raise exception 'Remittance reference is required';
  v_net := coalesce(p_net_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);
  v_cod := coalesce(v_order.cod_collect_amount, 0.00);

  if v_net <= 0.00 then
    raise exception 'Net remittance amount must be positive';
  if v_charge < 0.00 then
    raise exception 'Courier charge cannot be negative';
  -- Cap: net + charge must not exceed COD collect (full economic remittance)
  if v_cod > 0 and (v_net + v_charge) > (v_cod + 0.01) then
    raise exception 'Remittance net (%) + charge (%) exceeds COD collect (%)', v_net, v_charge, v_cod;
  select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id for update;
  v_invoice_due := greatest(coalesce(v_invoice.total_amount, 0.00) - coalesce(v_invoice.paid_amount, 0.00), 0.00);
  v_invoice_pay := least(v_net, v_invoice_due);
  v_profit_hold := greatest(v_net - v_invoice_pay, 0.00);

  -- 1. UWL courier + tenant remittance + courier fee
  -- Allocation is returned to caller; held remainder stays as cash float until profit payout
  -- (dropship_profit already accrued on billing profile at accounting invoice).
  perform public.process_dropship_courier_remittance_uwl(
    p_order_id => p_order_id,
    p_net_amount => v_net,
    p_courier_charge => v_charge,
    p_remittance_ref => v_ref
  );

  -- Annotate remittance credit with allocation breakdown
  update public.universal_wallet_ledger
  set metadata = metadata || jsonb_build_object(
    'invoice_allocated', v_invoice_pay,
    'merchant_funds_held', v_profit_hold
  )
  where tenant_id = v_order.tenant_id
    and entity_type = 'tenant'
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received';

  -- 2. Clear B2B invoice up to due (do not over-pay invoice)
  if v_invoice_pay > 0 then
    insert into public.global_payments (
      tenant_id,
      billing_profile_id,
      collection_source,
      amount,
      unallocated_amount,
      payment_date,
      method,
      reference,
      note
    )
    values (
      v_invoice.tenant_id,
      null,
      'recipient'::public.collection_source_type,
      v_invoice_pay,
      0.00,
      coalesce(p_payment_date, current_date),
      coalesce(nullif(trim(p_method), ''), 'cash'),
      v_ref,
      coalesce(
        nullif(trim(p_note), ''),
        'Courier remittance order #' || v_order.order_no
          || coalesce(' bank:' || nullif(trim(p_bank_trx_id), ''), '')
          || ' (invoice ' || v_invoice_pay::text || ' / held ' || v_profit_hold::text || ')'
      )
    )
    returning id into v_payment_id;

    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_invoice.tenant_id, v_payment_id, v_order.global_invoice_id, v_invoice_pay);

    update public.global_invoices
    set
      paid_amount = coalesce(paid_amount, 0.00) + v_invoice_pay,
      note = coalesce(nullif(trim(p_note), ''), note),
      updated_at = now()
    where id = v_order.global_invoice_id;

    perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);

    -- Clear customer AR for the invoice portion (idempotent)
    if v_invoice.billing_profile_id is not null and not exists (
      select 1 from public.universal_wallet_ledger
      where tenant_id = v_order.tenant_id
        and entity_type = 'customer'
        and entity_id = v_invoice.billing_profile_id
        and source_type = 'shop_order'
        and source_id = p_order_id::text
        and metadata->>'transaction_type' = 'invoice_collection'
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.billing_profile_id,
        p_type => 'credit',
        p_amount => v_invoice_pay,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'invoice_collection',
          'label', 'Invoice Cleared via COD Remittance',
          'order_no', v_order.order_no,
          'invoice_id', v_order.global_invoice_id,
          'invoice_no', v_invoice.invoice_no,
          'remittance_ref', v_ref
        )
      );
    update public.shop_orders
  set
    status = 'payment_received'::public.shop_order_status,
    courier_remittance_ref = v_ref,
    courier_bank_trx_id = coalesce(nullif(trim(p_bank_trx_id), ''), courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_order.global_invoice_id,
    'payment_id', v_payment_id,
    'order_id', p_order_id,
    'status', 'payment_received',
    'net_amount', v_net,
    'courier_charge', v_charge,
    'invoice_allocated', v_invoice_pay,
    'merchant_funds_held', v_profit_hold
  );
ALTER FUNCTION "public"."record_dropship_courier_remittance"("p_order_id" bigint, "p_net_amount" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text", "p_payment_date" "date", "p_method" "text", "p_note" "text", "p_courier_charge" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_shop_cart_item"("p_cart_item_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_cart_id bigint;
  v_shop_id bigint;
  begin
  select ci.cart_id, c.shop_id, c.tenant_id
  into v_cart_id, v_shop_id, v_tenant_id
  from public.shop_cart_items ci
  join public.shop_carts c on c.id = ci.cart_id
  where ci.id = p_cart_item_id;

  if v_cart_id is null then
    raise exception 'cart item not found';
  -- Access verification
  if not public.is_cart_owner((select customer_group_id from public.shop_carts where id = v_cart_id), v_tenant_id) then
    raise exception 'access denied';
  delete from public.shop_cart_items where id = p_cart_item_id;

  return public.get_or_create_shop_cart(v_shop_id);
ALTER FUNCTION "public"."remove_shop_cart_item"("p_cart_item_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_customer_group_shop_profiles_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  ALTER FUNCTION "public"."set_customer_group_shop_profiles_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_shop_customer_group_access_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  ALTER FUNCTION "public"."set_shop_customer_group_access_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_shop_order_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  ALTER FUNCTION "public"."set_shop_order_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_shop_pricing_rules_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  ALTER FUNCTION "public"."set_shop_pricing_rules_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_shop_product_listings_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  ALTER FUNCTION "public"."set_shop_product_listings_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_shops_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  ALTER FUNCTION "public"."set_shops_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."shops_derive_is_negotiable"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.shop_type = 'vendor_catalog' then
    new.is_negotiable := true;
  else
    new.is_negotiable := false;
  ALTER FUNCTION "public"."shops_derive_is_negotiable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_counter_offer"("p_order_id" bigint, "p_items" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  begin
  select tenant_id into v_tenant_id from public.shop_orders where id = p_order_id;
  
  if v_tenant_id is null then
    raise exception 'order not found';
  if not public.is_tenant_staff(v_tenant_id) then
    raise exception 'access denied';
  for v_item in select * from jsonb_to_recordset(p_items) as x(id bigint, staff_offer_amount numeric, staff_offer_currency_id bigint) loop
    update public.shop_order_items
    set
      staff_offer_amount = v_item.staff_offer_amount,
      staff_offer_currency_id = v_item.staff_offer_currency_id
    where id = v_item.id and order_id = p_order_id;
  update public.shop_orders
  set
    status = 'negotiating',
    updated_at = now()
  where id = p_order_id;
ALTER FUNCTION "public"."staff_counter_offer"("p_order_id" bigint, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_price_shop_order"("p_order_id" bigint, "p_items" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_is_negotiable boolean;
  begin
  select tenant_id, is_negotiable_snapshot into v_tenant_id, v_is_negotiable from public.shop_orders where id = p_order_id;
  
  if v_tenant_id is null then
    raise exception 'order not found';
  if not public.is_tenant_staff(v_tenant_id) then
    raise exception 'access denied';
  for v_item in select * from jsonb_to_recordset(p_items) as x(id bigint, staff_offer_amount numeric, staff_offer_currency_id bigint) loop
    update public.shop_order_items
    set
      staff_offer_amount = v_item.staff_offer_amount,
      staff_offer_currency_id = v_item.staff_offer_currency_id,
      final_price_amount = case when not v_is_negotiable then v_item.staff_offer_amount else final_price_amount end,
      final_price_currency_id = case when not v_is_negotiable then v_item.staff_offer_currency_id else final_price_currency_id end
    where id = v_item.id and order_id = p_order_id;
  update public.shop_orders
  set
    status = case when v_is_negotiable then 'negotiating'::public.shop_order_status else 'priced'::public.shop_order_status end,
    updated_at = now()
  where id = p_order_id;
ALTER FUNCTION "public"."staff_price_shop_order"("p_order_id" bigint, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_price_shop_order"("p_order_id" bigint, "p_items" "jsonb", "p_profit_basis" "text" DEFAULT NULL::"text", "p_fx_rate" numeric DEFAULT NULL::numeric, "p_cargo_rate" numeric DEFAULT NULL::numeric, "p_profit_pct" numeric DEFAULT NULL::numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_offer_amount numeric;
  v_offer_currency_id bigint;
  v_weight_kg numeric;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_price_shop_order is only valid for vendor_catalog orders.';
  END IF;

  IF v_order.status NOT IN ('submitted'::public.shop_order_status, 'costing_pending'::public.shop_order_status) THEN
    RAISE EXCEPTION 'Order % cannot send first offer from status %', p_order_id, v_order.status;
  END IF;

  -- Update order level rates if provided
  UPDATE public.shop_orders
  SET
    profit_basis = COALESCE(p_profit_basis, profit_basis),
    conversion_rate = COALESCE(p_fx_rate, conversion_rate),
    cargo_rate = COALESCE(p_cargo_rate, cargo_rate),
    first_offer_rate = COALESCE(p_profit_pct, first_offer_rate),
    profit_rate = COALESCE(p_profit_pct, profit_rate),
    status = 'priced'::public.shop_order_status,
    updated_at = now()
  WHERE id = p_order_id;

  -- Update item pricing & weights (shop_order_items.weight_kg — not gross_weight_kg)
  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_elem->>'id')::bigint;
    v_offer_amount := (v_elem->>'staff_offer_amount')::numeric;
    v_offer_currency_id := (v_elem->>'staff_offer_currency_id')::bigint;
    v_weight_kg := COALESCE(
      NULLIF(v_elem->>'weight_kg', '')::numeric,
      NULLIF(v_elem->>'gross_weight_kg', '')::numeric,
      NULL
    );

    UPDATE public.shop_order_items
    SET
      staff_offer_amount = v_offer_amount,
      staff_offer_currency_id = v_offer_currency_id,
      weight_kg = COALESCE(v_weight_kg, weight_kg),
      staff_offer_at = now(),
      updated_at = now()
    WHERE id = v_item_id AND order_id = p_order_id;
  END LOOP;
END;
ALTER FUNCTION "public"."staff_price_shop_order"("p_order_id" bigint, "p_items" "jsonb", "p_profit_basis" "text", "p_fx_rate" numeric, "p_cargo_rate" numeric, "p_profit_pct" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_finalize_catalog_prices"("p_order_id" bigint, "p_items" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_final_amount numeric;
  v_final_currency_id bigint;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_finalize_catalog_prices is only valid for vendor_catalog orders.';
  END IF;

  IF v_order.status <> 'countered'::public.shop_order_status THEN
    RAISE EXCEPTION 'Order % cannot send final offer from status %', p_order_id, v_order.status;
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_elem->>'id')::bigint;
    v_final_amount := (v_elem->>'final_offer_amount')::numeric;
    v_final_currency_id := (v_elem->>'final_offer_currency_id')::bigint;

    UPDATE public.shop_order_items
    SET
      final_price_amount = v_final_amount,
      final_price_currency_id = v_final_currency_id,
      final_offer_at = now(),
      updated_at = now()
    WHERE id = v_item_id AND order_id = p_order_id;
  END LOOP;

  UPDATE public.shop_orders
  SET
    status = 'final_offered'::public.shop_order_status,
    updated_at = now()
  WHERE id = p_order_id;
END;
$$;


ALTER FUNCTION "public"."staff_finalize_catalog_prices"("p_order_id" bigint, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_shop_order_from_cart"("p_cart_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text" DEFAULT NULL::"text", "p_shipping_district" "text" DEFAULT NULL::"text", "p_shipping_thana" "text" DEFAULT NULL::"text", "p_billing_profile_id" bigint DEFAULT NULL::bigint, "p_is_prepaid" boolean DEFAULT false, "p_delivery_instructions" "text" DEFAULT NULL::"text", "p_cod_charge_amount" numeric DEFAULT 0, "p_delivery_charge_amount" numeric DEFAULT 0, "p_print_charge_amount" numeric DEFAULT 0, "p_packing_charge_amount" numeric DEFAULT 0, "p_discount_amount" numeric DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_cart record;
  v_shop record;
  v_order_id bigint;
  v_order_no text;
  v_initial_status public.shop_order_status;
BEGIN
  -- Fetch cart
  SELECT * INTO v_cart FROM public.shop_carts WHERE id = p_cart_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active cart not found for ID %', p_cart_id;
  END IF;

  -- Fetch shop
  SELECT * INTO v_shop FROM public.shops WHERE id = v_cart.shop_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shop not found for ID %', v_cart.shop_id;
  END IF;

  -- Determine status based on shop_type
  IF v_shop.shop_type = 'vendor_catalog' THEN
    v_initial_status := 'submitted'::public.shop_order_status;
  ELSE
    -- Dropship / default behavior
    v_initial_status := 'draft'::public.shop_order_status;
  END IF;

  -- Generate order_no
  v_order_no := 'ORD-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 100000)::text, 5, '0');

  -- Create shop order
  INSERT INTO public.shop_orders (
    tenant_id,
    customer_group_id,
    shop_id,
    cart_id,
    order_no,
    name,
    status,
    shop_type_snapshot,
    order_mode_snapshot,
    is_negotiable_snapshot,
    billing_profile_id,
    created_by_email,
    recipient_name,
    recipient_phone,
    recipient_phone_secondary,
    shipping_address,
    shipping_district,
    shipping_thana,
    is_prepaid_snapshot,
    delivery_instructions,
    cod_charge_amount,
    delivery_charge_amount,
    print_charge_amount,
    packing_charge_amount,
    discount_amount,
    created_at,
    updated_at
  ) VALUES (
    v_cart.tenant_id,
    v_cart.customer_group_id,
    v_cart.shop_id,
    p_cart_id,
    v_order_no,
    'Order for ' || coalesce(nullif(trim(coalesce(p_recipient_name, '')), ''), 'customer'),
    v_initial_status,
    v_shop.shop_type,
    v_shop.order_mode,
    v_shop.is_negotiable,
    p_billing_profile_id,
    public.current_user_email(),
    p_recipient_name,
    p_recipient_phone,
    p_recipient_phone_secondary,
    p_shipping_address,
    p_shipping_district,
    p_shipping_thana,
    p_is_prepaid,
    p_delivery_instructions,
    p_cod_charge_amount,
    p_delivery_charge_amount,
    p_print_charge_amount,
    p_packing_charge_amount,
    p_discount_amount,
    now(),
    now()
  )
  RETURNING id INTO v_order_id;

  -- Copy cart items to shop order items using correct shop_order_items schema
  INSERT INTO public.shop_order_items (
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
  SELECT
    v_order_id, ci.product_id, ci.global_stock_id, ci.global_stock_allocation_id,
    ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    CASE WHEN v_shop.shop_type = 'dropship' THEN ci.customer_sell_price_amount ELSE NULL END,
    CASE WHEN v_shop.shop_type = 'dropship' THEN ci.customer_sell_price_currency_id ELSE NULL END,
    CASE
      WHEN v_initial_status = 'confirmed' THEN COALESCE(ci.customer_sell_price_amount, ci.unit_sell_price_amount, ci.unit_list_price_amount)
      ELSE NULL
    END,
    CASE
      WHEN v_initial_status = 'confirmed' THEN COALESCE(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id, ci.unit_list_price_currency_id)
      ELSE NULL
    END,
    ci.quantity
  FROM public.shop_cart_items ci
  WHERE ci.cart_id = p_cart_id;

  -- Deactivate cart
  UPDATE public.shop_carts SET status = 'converted', updated_at = now() WHERE id = p_cart_id;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_initial_status
  );
END;
ALTER FUNCTION "public"."submit_shop_order_from_cart"("p_cart_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_billing_profile_id" bigint, "p_is_prepaid" boolean, "p_delivery_instructions" "text", "p_cod_charge_amount" numeric, "p_delivery_charge_amount" numeric, "p_print_charge_amount" numeric, "p_packing_charge_amount" numeric, "p_discount_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_shop_cart_item_reservation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if tg_op = 'DELETE' then
    delete from public.shop_stock_reservations where cart_item_id = old.id;
    return old;
  if new.quantity > 0 and new.global_stock_id is not null then
    insert into public.shop_stock_reservations (cart_item_id, global_stock_id, global_stock_allocation_id, quantity)
    values (new.id, new.global_stock_id, null, new.quantity)
    on conflict (cart_item_id) do update set
      global_stock_id = excluded.global_stock_id,
      global_stock_allocation_id = null,
      quantity = excluded.quantity;
  else
    delete from public.shop_stock_reservations where cart_item_id = new.id;
  ALTER FUNCTION "public"."sync_shop_cart_item_reservation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_auto_publish_dropship_listing"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop record;
  v_rule record;
  v_landed_cost numeric;
  v_currency_id bigint;
  v_stock_id bigint;
  v_sell_price numeric;
begin
  -- For each shop owned by the target child tenant that has auto_publish enabled
  for v_shop in (
    select s.id as shop_id, s.tenant_id
    from public.shops s
    where s.tenant_id = new.tenant_id
  ) loop
    select * into v_rule
    from public.shop_pricing_rules
    where shop_id = v_shop.shop_id;

    if v_rule.is_auto_publish is true then
      -- Calculate parent landed cost for minimum_sell_price
      select
        (gsi.purchase_price * coalesce(gship.product_conversion_rate, 1.0)),
        gsi.purchase_price_currency_id,
        gsi.product_id,
        gs.id
      into v_landed_cost, v_currency_id, v_product_id, v_stock_id
      from public.global_stocks gs
      join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      join public.global_shipments gship on gship.id = gsi.shipment_id
      where gs.id = new.stock_id;

      if v_landed_cost is not null and v_currency_id is not null then
        v_sell_price := round(v_landed_cost * (1 + (coalesce(v_rule.markup_percentage, 0.00) / 100.0)), 2);

        insert into public.shop_product_listings (
          tenant_id,
          shop_id,
          global_stock_allocation_id,
          global_stock_id,
          product_id,
          sell_price_amount,
          sell_price_currency_id,
          minimum_sell_price_amount,
          minimum_sell_price_currency_id,
          is_active
        )
        values (
          v_shop.tenant_id,
          v_shop.shop_id,
          new.id,
          v_stock_id,
          v_product_id,
          v_sell_price,
          v_currency_id,
          round(v_landed_cost, 2),
          v_currency_id,
          true
        )
        on conflict (shop_id, global_stock_allocation_id) do update set
          minimum_sell_price_amount = excluded.minimum_sell_price_amount,
          minimum_sell_price_currency_id = excluded.minimum_sell_price_currency_id,
          sell_price_amount = case
            when shop_product_listings.sell_price_amount < excluded.minimum_sell_price_amount then excluded.sell_price_amount
            else shop_product_listings.sell_price_amount
          end,
          updated_at = now();
      ALTER FUNCTION "public"."trg_auto_publish_dropship_listing"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_dropship_consignment"("p_order_id" bigint, "p_cod_collect_amount" numeric DEFAULT 0.00, "p_package_weight_band" "text" DEFAULT 'under_1kg'::"text", "p_item_category" "text" DEFAULT NULL::"text", "p_parcel_description" "text" DEFAULT NULL::"text", "p_courier_order_ref" "text" DEFAULT NULL::"text", "p_delivery_zone" "text" DEFAULT 'inside_dhaka'::"text", "p_sender_name" "text" DEFAULT NULL::"text", "p_pickup_phone" "text" DEFAULT NULL::"text", "p_pickup_address" "text" DEFAULT NULL::"text", "p_payout_account_type" "text" DEFAULT 'bank'::"text", "p_payout_account_info" "text" DEFAULT NULL::"text", "p_allow_open_box" boolean DEFAULT false, "p_delivery_instruction_notes" "text" DEFAULT NULL::"text", "p_courier_service_id" "uuid" DEFAULT NULL::"uuid", "p_courier_tracking_number" "text" DEFAULT NULL::"text", "p_courier_awb_number" "text" DEFAULT NULL::"text", "p_courier_consignment_id" "text" DEFAULT NULL::"text", "p_tracking_url" "text" DEFAULT NULL::"text", "p_courier_cost_amount" numeric DEFAULT 0.00, "p_recipient_name" "text" DEFAULT NULL::"text", "p_recipient_phone" "text" DEFAULT NULL::"text", "p_recipient_phone_secondary" "text" DEFAULT NULL::"text", "p_shipping_address" "text" DEFAULT NULL::"text", "p_shipping_district" "text" DEFAULT NULL::"text", "p_shipping_thana" "text" DEFAULT NULL::"text", "p_delivery_charge_amount" numeric DEFAULT NULL::numeric, "p_cod_charge_amount" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders%rowtype;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_delivery_charge numeric;
  v_cod_charge numeric;
if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  v_delivery_charge := coalesce(p_delivery_charge_amount, p_courier_cost_amount, 0.00);
  v_cod_charge := coalesce(p_cod_charge_amount, 0.00);

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
    delivery_charge_amount = v_delivery_charge,
    cod_charge_amount = v_cod_charge,
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
  return jsonb_build_object('success', true);
ALTER FUNCTION "public"."update_dropship_consignment"("p_order_id" bigint, "p_cod_collect_amount" numeric, "p_package_weight_band" "text", "p_item_category" "text", "p_parcel_description" "text", "p_courier_order_ref" "text", "p_delivery_zone" "text", "p_sender_name" "text", "p_pickup_phone" "text", "p_pickup_address" "text", "p_payout_account_type" "text", "p_payout_account_info" "text", "p_allow_open_box" boolean, "p_delivery_instruction_notes" "text", "p_courier_service_id" "uuid", "p_courier_tracking_number" "text", "p_courier_awb_number" "text", "p_courier_consignment_id" "text", "p_tracking_url" "text", "p_courier_cost_amount" numeric, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_phone_secondary" "text", "p_shipping_address" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_delivery_charge_amount" numeric, "p_cod_charge_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_shop_cart_item_price"("p_cart_item_id" bigint, "p_price" numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_cart_id bigint;
  v_shop_id bigint;
  v_shop_type public.shop_type_enum;
  v_global_stock_allocation_id bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_customer_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
begin
  select ci.cart_id, ci.global_stock_allocation_id, c.shop_id, c.tenant_id, s.shop_type,
         ci.unit_sell_price_amount, ci.unit_sell_price_currency_id, ci.customer_sell_price_currency_id,
         ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id
  into v_cart_id, v_global_stock_allocation_id, v_shop_id, v_tenant_id, v_shop_type,
       v_sell_price_amount, v_sell_price_currency_id, v_customer_sell_price_currency_id,
       v_min_sell_price_amount, v_min_sell_price_currency_id
  from public.shop_cart_items ci
  join public.shop_carts c on c.id = ci.cart_id
  join public.shops s on s.id = c.shop_id
  where ci.id = p_cart_item_id;

  if v_cart_id is null then
    raise exception 'cart item not found';
  if not public.is_cart_owner((select customer_group_id from public.shop_carts where id = v_cart_id), v_tenant_id) then
    raise exception 'access denied';
  if v_shop_type <> 'dropship' then
    raise exception 'price updates only allowed for dropship shops';
  if p_price < 0 then
    raise exception 'price cannot be negative';
  -- Enforce minimum sell price floor
  if v_customer_sell_price_currency_id = v_min_sell_price_currency_id 
     and p_price < v_min_sell_price_amount then
    raise exception 'price cannot be lower than the minimum sell price %', v_min_sell_price_amount;
  update public.shop_cart_items
  set customer_sell_price_amount = p_price, updated_at = now()
  where id = p_cart_item_id;

  return public.get_or_create_shop_cart(v_shop_id);
ALTER FUNCTION "public"."update_shop_cart_item_price"("p_cart_item_id" bigint, "p_price" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_shop_cart_item_qty"("p_cart_item_id" bigint, "p_quantity" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_cart_id bigint;
  v_shop_id bigint;
  v_shop_type public.shop_type_enum;
  v_global_stock_allocation_id bigint;
  v_allocated_qty integer;
  v_other_reserved_qty integer;
  v_available_to_sell integer;
begin
  if p_quantity <= 0 then
    return public.remove_shop_cart_item(p_cart_item_id);
  select ci.cart_id, ci.global_stock_allocation_id, c.shop_id, c.tenant_id, s.shop_type
  into v_cart_id, v_global_stock_allocation_id, v_shop_id, v_tenant_id, v_shop_type
  from public.shop_cart_items ci
  join public.shop_carts c on c.id = ci.cart_id
  join public.shops s on s.id = c.shop_id
  where ci.id = p_cart_item_id;

  if v_cart_id is null then
    raise exception 'cart item not found';
  -- Access verification via is_cart_owner RLS trigger fallback check
  if not public.is_cart_owner((select customer_group_id from public.shop_carts where id = v_cart_id), v_tenant_id) then
    raise exception 'access denied';
  -- Verify stock if stock-backed
  if v_shop_type in ('fixed_price', 'dropship') and v_global_stock_allocation_id is not null then
    select quantity into v_allocated_qty
    from public.global_stock_allocations
    where id = v_global_stock_allocation_id;

    select coalesce(sum(quantity), 0)
    into v_other_reserved_qty
    from public.shop_stock_reservations r
    where r.global_stock_allocation_id = v_global_stock_allocation_id
      and r.cart_item_id <> p_cart_item_id;

    v_available_to_sell := v_allocated_qty - v_other_reserved_qty;

    if p_quantity > v_available_to_sell then
      raise exception 'insufficient stock: requested %, available %', p_quantity, greatest(0, v_available_to_sell);
    update public.shop_cart_items
  set quantity = p_quantity, updated_at = now()
  where id = p_cart_item_id;

  return public.get_or_create_shop_cart(v_shop_id);
ALTER FUNCTION "public"."update_shop_cart_item_qty"("p_cart_item_id" bigint, "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_customer_group_shop_profile"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_is_active" boolean, "p_default_can_browse" boolean, "p_default_can_see_buy_price" boolean, "p_default_can_see_sell_price" boolean, "p_default_can_add_to_cart" boolean, "p_default_can_place_order" boolean, "p_default_can_negotiate" boolean, "p_default_can_view_quantity" boolean, "p_default_can_set_dropship_price" boolean) RETURNS SETOF "public"."customer_group_shop_profiles"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  return query
  insert into public.customer_group_shop_profiles (
    tenant_id,
    customer_group_id,
    is_active,
    default_can_browse,
    default_can_see_buy_price,
    default_can_see_sell_price,
    default_can_add_to_cart,
    default_can_place_order,
    default_can_negotiate,
    default_can_view_quantity,
    default_can_set_dropship_price
  )
  values (
    p_tenant_id,
    p_customer_group_id,
    p_is_active,
    p_default_can_browse,
    p_default_can_see_buy_price,
    p_default_can_see_sell_price,
    p_default_can_add_to_cart,
    p_default_can_place_order,
    p_default_can_negotiate,
    p_default_can_view_quantity,
    p_default_can_set_dropship_price
  )
  on conflict (tenant_id, customer_group_id) do update set
    is_active = excluded.is_active,
    default_can_browse = excluded.default_can_browse,
    default_can_see_buy_price = excluded.default_can_see_buy_price,
    default_can_see_sell_price = excluded.default_can_see_sell_price,
    default_can_add_to_cart = excluded.default_can_add_to_cart,
    default_can_place_order = excluded.default_can_place_order,
    default_can_negotiate = excluded.default_can_negotiate,
    default_can_view_quantity = excluded.default_can_view_quantity,
    default_can_set_dropship_price = excluded.default_can_set_dropship_price,
    updated_at = now()
  returning *;
ALTER FUNCTION "public"."upsert_customer_group_shop_profile"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_is_active" boolean, "p_default_can_browse" boolean, "p_default_can_see_buy_price" boolean, "p_default_can_see_sell_price" boolean, "p_default_can_add_to_cart" boolean, "p_default_can_place_order" boolean, "p_default_can_negotiate" boolean, "p_default_can_view_quantity" boolean, "p_default_can_set_dropship_price" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_shop"("p_tenant_id" bigint, "p_name" "text", "p_slug" "text", "p_order_mode" "public"."shop_order_mode_enum", "p_is_negotiable" boolean, "p_show_stock_quantity" boolean, "p_is_active" boolean, "p_shop_type" "public"."shop_type_enum" DEFAULT NULL::"public"."shop_type_enum", "p_vendor_code" "text" DEFAULT NULL::"text", "p_id" bigint DEFAULT NULL::bigint, "p_default_currency_id" bigint DEFAULT NULL::bigint, "p_global_stock_type_id" bigint DEFAULT NULL::bigint, "p_allow_delivery" boolean DEFAULT false, "p_buy_currency_id" bigint DEFAULT NULL::bigint, "p_sell_currency_id" bigint DEFAULT NULL::bigint, "p_pricing_method" "text" DEFAULT NULL::"text", "p_markup_percentage" numeric DEFAULT 0, "p_quantity_display_mode" "text" DEFAULT NULL::"text", "p_default_print_charge_amount" numeric DEFAULT 0, "p_default_packing_charge_amount" numeric DEFAULT 0, "p_deduct_charges_from_margin" boolean DEFAULT false, "p_vendor_filters" "jsonb" DEFAULT NULL::"jsonb", "p_deduct_print_from_margin" boolean DEFAULT false, "p_deduct_packing_from_margin" boolean DEFAULT false, "p_description" "text" DEFAULT NULL::"text", "p_category_ids" bigint[] DEFAULT '{}'::bigint[]) RETURNS SETOF "public"."shops"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_type public.shop_type_enum;
  v_result    public.shops;
  v_vendor_code text;
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  if p_pricing_method is not null and p_pricing_method not in ('direct_cost', 'markup') then
    raise exception 'invalid pricing method';
  if p_quantity_display_mode is not null and p_quantity_display_mode not in ('original', 'custom_override') then
    raise exception 'invalid quantity display mode';
  if p_markup_percentage < 0 then
    raise exception 'markup percentage must be non-negative';
  v_vendor_code := nullif(trim(coalesce(p_vendor_code, '')), '');
  if v_vendor_code is null
     and p_vendor_filters is not null
     and jsonb_typeof(p_vendor_filters) = 'array'
     and jsonb_array_length(p_vendor_filters) > 0 then
    v_vendor_code := nullif(trim(coalesce(p_vendor_filters->0->>'vendor_code', '')), '');
  if p_id is null then
    if p_shop_type is null then
      raise exception 'shop_type is required when creating a shop';
    if p_shop_type = 'dropship' and p_is_negotiable then
      raise exception 'dropship shops cannot be negotiable';
    insert into public.shops (
      tenant_id,
      name,
      slug,
      shop_type,
      vendor_code,
      order_mode,
      is_negotiable,
      show_stock_quantity,
      default_currency_id,
      global_stock_type_id,
      is_active,
      allow_delivery,
      buy_currency_id,
      sell_currency_id,
      pricing_method,
      markup_percentage,
      quantity_display_mode,
      default_print_charge_amount,
      default_packing_charge_amount,
      deduct_charges_from_margin,
      vendor_filters,
      deduct_print_from_margin,
      deduct_packing_from_margin,
      description,
      category_ids
    )
    values (
      p_tenant_id,
      trim(p_name),
      lower(trim(p_slug)),
      p_shop_type,
      v_vendor_code,
      p_order_mode,
      p_is_negotiable,
      p_show_stock_quantity,
      coalesce(p_default_currency_id, p_sell_currency_id),
      p_global_stock_type_id,
      p_is_active,
      p_allow_delivery,
      coalesce(p_buy_currency_id, p_default_currency_id, (select id from public.global_currencies where code = 'BDT' limit 1)),
      coalesce(p_sell_currency_id, p_default_currency_id, (select id from public.global_currencies where code = 'BDT' limit 1)),
      coalesce(p_pricing_method, 'direct_cost'),
      coalesce(p_markup_percentage, 0),
      coalesce(p_quantity_display_mode, 'original'),
      coalesce(p_default_print_charge_amount, 0),
      coalesce(p_default_packing_charge_amount, 0),
      coalesce(p_deduct_charges_from_margin, false),
      p_vendor_filters,
      coalesce(p_deduct_print_from_margin, false),
      coalesce(p_deduct_packing_from_margin, false),
      trim(p_description),
      coalesce(p_category_ids, '{}')
    )
    returning * into v_result;

  else
    select shop_type into v_shop_type
    from public.shops
    where id = p_id and tenant_id = p_tenant_id
      and deleted_at is null;

    if v_shop_type is null then
      raise exception 'shop not found';
    if v_shop_type = 'dropship' and p_is_negotiable then
      raise exception 'dropship shops cannot be negotiable';
    update public.shops
    set
      name                            = trim(p_name),
      slug                            = lower(trim(p_slug)),
      order_mode                      = p_order_mode,
      is_negotiable                   = p_is_negotiable,
      show_stock_quantity             = p_show_stock_quantity,
      default_currency_id             = coalesce(p_default_currency_id, p_sell_currency_id, default_currency_id),
      global_stock_type_id            = p_global_stock_type_id,
      is_active                       = p_is_active,
      allow_delivery                  = p_allow_delivery,
      buy_currency_id                 = coalesce(p_buy_currency_id, buy_currency_id),
      sell_currency_id                = coalesce(p_sell_currency_id, p_default_currency_id, sell_currency_id),
      pricing_method                  = coalesce(p_pricing_method, pricing_method),
      markup_percentage               = coalesce(p_markup_percentage, markup_percentage),
      quantity_display_mode           = coalesce(p_quantity_display_mode, quantity_display_mode),
      default_print_charge_amount     = coalesce(p_default_print_charge_amount, default_print_charge_amount),
      default_packing_charge_amount   = coalesce(p_default_packing_charge_amount, default_packing_charge_amount),
      deduct_charges_from_margin      = coalesce(p_deduct_charges_from_margin, deduct_charges_from_margin),
      vendor_code                     = case
                                          when p_vendor_code is not null or p_vendor_filters is not null
                                            then v_vendor_code
                                          else vendor_code
                                        end,
      vendor_filters                  = coalesce(p_vendor_filters, vendor_filters),
      deduct_print_from_margin        = coalesce(p_deduct_print_from_margin, deduct_print_from_margin),
      deduct_packing_from_margin      = coalesce(p_deduct_packing_from_margin, deduct_packing_from_margin),
      description                     = trim(p_description),
      category_ids                    = coalesce(p_category_ids, '{}'),
      updated_at                      = now()
    where id = p_id
      and tenant_id = p_tenant_id
      and deleted_at is null
    returning * into v_result;

    if v_result is null then
      raise exception 'shop not found or update failed';
    return next v_result;
ALTER FUNCTION "public"."upsert_shop"("p_tenant_id" bigint, "p_name" "text", "p_slug" "text", "p_order_mode" "public"."shop_order_mode_enum", "p_is_negotiable" boolean, "p_show_stock_quantity" boolean, "p_is_active" boolean, "p_shop_type" "public"."shop_type_enum", "p_vendor_code" "text", "p_id" bigint, "p_default_currency_id" bigint, "p_global_stock_type_id" bigint, "p_allow_delivery" boolean, "p_buy_currency_id" bigint, "p_sell_currency_id" bigint, "p_pricing_method" "text", "p_markup_percentage" numeric, "p_quantity_display_mode" "text", "p_default_print_charge_amount" numeric, "p_default_packing_charge_amount" numeric, "p_deduct_charges_from_margin" boolean, "p_vendor_filters" "jsonb", "p_deduct_print_from_margin" boolean, "p_deduct_packing_from_margin" boolean, "p_description" "text", "p_category_ids" bigint[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_shop_customer_group_access"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_status" boolean, "p_can_browse" boolean DEFAULT NULL::boolean, "p_can_see_buy_price" boolean DEFAULT NULL::boolean, "p_can_see_sell_price" boolean DEFAULT NULL::boolean, "p_can_add_to_cart" boolean DEFAULT NULL::boolean, "p_can_place_order" boolean DEFAULT NULL::boolean, "p_can_negotiate" boolean DEFAULT NULL::boolean, "p_can_view_quantity" boolean DEFAULT NULL::boolean, "p_can_set_dropship_price" boolean DEFAULT NULL::boolean, "p_price_tier_code" "text" DEFAULT NULL::"text", "p_credit_limit_amount" numeric DEFAULT NULL::numeric, "p_credit_limit_currency_id" bigint DEFAULT NULL::bigint) RETURNS SETOF "public"."shop_customer_group_access"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.shops
  where id = p_shop_id;

  if v_tenant_id is null then
    raise exception 'shop not found';
  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  if (p_credit_limit_amount is null) <> (p_credit_limit_currency_id is null) then
    raise exception 'both credit_limit_amount and credit_limit_currency_id must be provided together or be null';
  return query
  insert into public.shop_customer_group_access (
    shop_id,
    customer_group_id,
    status,
    can_browse,
    can_see_buy_price,
    can_see_sell_price,
    can_add_to_cart,
    can_place_order,
    can_negotiate,
    can_view_quantity,
    can_set_dropship_price,
    price_tier_code,
    credit_limit_amount,
    credit_limit_currency_id
  )
  values (
    p_shop_id,
    p_customer_group_id,
    p_status,
    p_can_browse,
    p_can_see_buy_price,
    p_can_see_sell_price,
    p_can_add_to_cart,
    p_can_place_order,
    p_can_negotiate,
    p_can_view_quantity,
    p_can_set_dropship_price,
    p_price_tier_code,
    p_credit_limit_amount,
    p_credit_limit_currency_id
  )
  on conflict (shop_id, customer_group_id) do update set
    status = excluded.status,
    can_browse = excluded.can_browse,
    can_see_buy_price = excluded.can_see_buy_price,
    can_see_sell_price = excluded.can_see_sell_price,
    can_add_to_cart = excluded.can_add_to_cart,
    can_place_order = excluded.can_place_order,
    can_negotiate = excluded.can_negotiate,
    can_view_quantity = excluded.can_view_quantity,
    can_set_dropship_price = excluded.can_set_dropship_price,
    price_tier_code = excluded.price_tier_code,
    credit_limit_amount = excluded.credit_limit_amount,
    credit_limit_currency_id = excluded.credit_limit_currency_id,
    updated_at = now()
  returning *;
ALTER FUNCTION "public"."upsert_shop_customer_group_access"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_status" boolean, "p_can_browse" boolean, "p_can_see_buy_price" boolean, "p_can_see_sell_price" boolean, "p_can_add_to_cart" boolean, "p_can_place_order" boolean, "p_can_negotiate" boolean, "p_can_view_quantity" boolean, "p_can_set_dropship_price" boolean, "p_price_tier_code" "text", "p_credit_limit_amount" numeric, "p_credit_limit_currency_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_shop_pricing_rule"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_is_auto_publish" boolean) RETURNS SETOF "public"."shop_pricing_rules"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  return query
  insert into public.shop_pricing_rules (
    tenant_id,
    shop_id,
    markup_percentage,
    is_auto_publish
  )
  values (
    v_tenant_id,
    p_shop_id,
    p_markup_percentage,
    p_is_auto_publish
  )
  on conflict (shop_id) do update set
    markup_percentage = excluded.markup_percentage,
    is_auto_publish = excluded.is_auto_publish,
    updated_at = now()
  returning *;
ALTER FUNCTION "public"."upsert_shop_pricing_rule"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_is_auto_publish" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_shop_pricing_rule"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_is_auto_publish" boolean, "p_default_show_quantity" boolean DEFAULT true) RETURNS SETOF "public"."shop_pricing_rules"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  return query
  insert into public.shop_pricing_rules (
    tenant_id,
    shop_id,
    markup_percentage,
    is_auto_publish,
    default_show_quantity
  )
  values (
    v_tenant_id,
    p_shop_id,
    p_markup_percentage,
    p_is_auto_publish,
    coalesce(p_default_show_quantity, true)
  )
  on conflict (shop_id) do update set
    markup_percentage = excluded.markup_percentage,
    is_auto_publish = excluded.is_auto_publish,
    default_show_quantity = excluded.default_show_quantity,
    updated_at = now()
  returning *;
ALTER FUNCTION "public"."upsert_shop_pricing_rule"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_is_auto_publish" boolean, "p_default_show_quantity" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_shop_pricing_rule"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_is_auto_publish" boolean, "p_default_show_quantity" boolean DEFAULT true, "p_default_add_quantity" integer DEFAULT 0) RETURNS SETOF "public"."shop_pricing_rules"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  return query
  insert into public.shop_pricing_rules (
    tenant_id,
    shop_id,
    markup_percentage,
    is_auto_publish,
    default_show_quantity,
    default_add_quantity
  )
  values (
    v_tenant_id,
    p_shop_id,
    p_markup_percentage,
    p_is_auto_publish,
    coalesce(p_default_show_quantity, true),
    coalesce(p_default_add_quantity, 0)
  )
  on conflict (shop_id) do update set
    markup_percentage = excluded.markup_percentage,
    is_auto_publish = excluded.is_auto_publish,
    default_show_quantity = excluded.default_show_quantity,
    default_add_quantity = excluded.default_add_quantity,
    updated_at = now()
  returning *;
ALTER FUNCTION "public"."upsert_shop_pricing_rule"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_is_auto_publish" boolean, "p_default_show_quantity" boolean, "p_default_add_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_shop_pricing_rule"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_is_auto_publish" boolean, "p_default_show_quantity" boolean DEFAULT true, "p_default_add_quantity" integer DEFAULT 0, "p_dropship_markup_percentage" numeric DEFAULT 0) RETURNS SETOF "public"."shop_pricing_rules"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  return query
  insert into public.shop_pricing_rules (
    tenant_id,
    shop_id,
    markup_percentage,
    is_auto_publish,
    default_show_quantity,
    default_add_quantity,
    dropship_markup_percentage
  )
  values (
    v_tenant_id,
    p_shop_id,
    p_markup_percentage,
    p_is_auto_publish,
    coalesce(p_default_show_quantity, true),
    coalesce(p_default_add_quantity, 0),
    coalesce(p_dropship_markup_percentage, 0)
  )
  on conflict (shop_id) do update set
    markup_percentage = excluded.markup_percentage,
    is_auto_publish = excluded.is_auto_publish,
    default_show_quantity = excluded.default_show_quantity,
    default_add_quantity = excluded.default_add_quantity,
    dropship_markup_percentage = excluded.dropship_markup_percentage,
    updated_at = now()
  returning *;
ALTER FUNCTION "public"."upsert_shop_pricing_rule"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_is_auto_publish" boolean, "p_default_show_quantity" boolean, "p_default_add_quantity" integer, "p_dropship_markup_percentage" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_shop_product_listing"("p_tenant_id" bigint, "p_shop_id" bigint, "p_global_stock_allocation_id" bigint, "p_sell_price_amount" numeric, "p_sell_price_currency_id" bigint, "p_minimum_sell_price_amount" numeric DEFAULT NULL::numeric, "p_minimum_sell_price_currency_id" bigint DEFAULT NULL::bigint, "p_show_quantity" boolean DEFAULT NULL::boolean, "p_display_quantity_override" integer DEFAULT NULL::integer, "p_is_active" boolean DEFAULT true, "p_id" bigint DEFAULT NULL::bigint) RETURNS SETOF "public"."shop_product_listings"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_global_stock_id bigint;
  begin
  -- Caller must be admin/staff of this tenant
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  -- Resolve denormalized IDs
  select gsa.stock_id, gsi.product_id
  into v_global_stock_id, v_product_id
  from public.global_stock_allocations gsa
  join public.global_stocks gs on gs.id = gsa.stock_id
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gsa.id = p_global_stock_allocation_id;

  if v_global_stock_id is null or v_product_id is null then
    raise exception 'invalid global stock allocation';
  -- Dropship dual money constraint
  if (p_minimum_sell_price_amount is null) <> (p_minimum_sell_price_currency_id is null) then
    raise exception 'both minimum_sell_price_amount and minimum_sell_price_currency_id must be provided together or be null';
  return query
  insert into public.shop_product_listings (
    id,
    tenant_id,
    shop_id,
    global_stock_allocation_id,
    global_stock_id,
    product_id,
    sell_price_amount,
    sell_price_currency_id,
    minimum_sell_price_amount,
    minimum_sell_price_currency_id,
    show_quantity,
    display_quantity_override,
    is_active
  )
  overriding system value
  values (
    coalesce(p_id, nextval(pg_get_serial_sequence('public.shop_product_listings', 'id'))),
    p_tenant_id,
    p_shop_id,
    p_global_stock_allocation_id,
    v_global_stock_id,
    v_product_id,
    p_sell_price_amount,
    p_sell_price_currency_id,
    p_minimum_sell_price_amount,
    p_minimum_sell_price_currency_id,
    p_show_quantity,
    p_display_quantity_override,
    p_is_active
  )
  on conflict (shop_id, global_stock_allocation_id) do update set
    sell_price_amount = excluded.sell_price_amount,
    sell_price_currency_id = excluded.sell_price_currency_id,
    minimum_sell_price_amount = excluded.minimum_sell_price_amount,
    minimum_sell_price_currency_id = excluded.minimum_sell_price_currency_id,
    show_quantity = excluded.show_quantity,
    display_quantity_override = excluded.display_quantity_override,
    is_active = excluded.is_active,
    updated_at = now()
  returning *;
ALTER FUNCTION "public"."upsert_shop_product_listing"("p_tenant_id" bigint, "p_shop_id" bigint, "p_global_stock_allocation_id" bigint, "p_sell_price_amount" numeric, "p_sell_price_currency_id" bigint, "p_minimum_sell_price_amount" numeric, "p_minimum_sell_price_currency_id" bigint, "p_show_quantity" boolean, "p_display_quantity_override" integer, "p_is_active" boolean, "p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_shop_product_listing"("p_tenant_id" bigint, "p_shop_id" bigint, "p_global_stock_allocation_id" bigint, "p_sell_price_amount" numeric, "p_sell_price_currency_id" bigint, "p_minimum_sell_price_amount" numeric DEFAULT NULL::numeric, "p_minimum_sell_price_currency_id" bigint DEFAULT NULL::bigint, "p_show_quantity" boolean DEFAULT NULL::boolean, "p_display_quantity_override" integer DEFAULT NULL::integer, "p_is_active" boolean DEFAULT true, "p_id" bigint DEFAULT NULL::bigint, "p_is_price_locked" boolean DEFAULT NULL::boolean, "p_is_quantity_locked" boolean DEFAULT NULL::boolean, "p_quantity_override_type" "text" DEFAULT NULL::"text") RETURNS SETOF "public"."shop_product_listings"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_product_id bigint;
  v_global_stock_id bigint;
  v_existing record;
  v_price_locked boolean;
  v_qty_locked boolean;
  v_override_type text;
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  -- Resolve stock & product id from allocation by joining global_stocks and global_shipment_items
  select gsa.stock_id, gsi.product_id
  into v_global_stock_id, v_product_id
  from public.global_stock_allocations gsa
  join public.global_stocks gs on gs.id = gsa.stock_id
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gsa.id = p_global_stock_allocation_id;

  if v_global_stock_id is null then
    raise exception 'allocation not found';
  if p_id is not null then
    select * into v_existing from public.shop_product_listings where id = p_id;
  else
    select * into v_existing from public.shop_product_listings
    where shop_id = p_shop_id and global_stock_allocation_id = p_global_stock_allocation_id;
  v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
  v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
  v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

  if v_existing.id is not null then
    return query
    update public.shop_product_listings
    set
      sell_price_amount = p_sell_price_amount,
      sell_price_currency_id = p_sell_price_currency_id,
      minimum_sell_price_amount = p_minimum_sell_price_amount,
      minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
      show_quantity = p_show_quantity,
      display_quantity_override = p_display_quantity_override,
      is_active = p_is_active,
      is_price_locked = v_price_locked,
      is_quantity_locked = v_qty_locked,
      quantity_override_type = v_override_type,
      updated_at = now()
    where id = v_existing.id
    returning *;
  else
    return query
    insert into public.shop_product_listings (
      tenant_id,
      shop_id,
      global_stock_allocation_id,
      global_stock_id,
      product_id,
      sell_price_amount,
      sell_price_currency_id,
      minimum_sell_price_amount,
      minimum_sell_price_currency_id,
      show_quantity,
      display_quantity_override,
      is_active,
      is_price_locked,
      is_quantity_locked,
      quantity_override_type
    )
    values (
      p_tenant_id,
      p_shop_id,
      p_global_stock_allocation_id,
      v_global_stock_id,
      v_product_id,
      p_sell_price_amount,
      p_sell_price_currency_id,
      p_minimum_sell_price_amount,
      p_minimum_sell_price_currency_id,
      p_show_quantity,
      p_display_quantity_override,
      p_is_active,
      v_price_locked,
      v_qty_locked,
      v_override_type
    )
    returning *;
  ALTER FUNCTION "public"."upsert_shop_product_listing"("p_tenant_id" bigint, "p_shop_id" bigint, "p_global_stock_allocation_id" bigint, "p_sell_price_amount" numeric, "p_sell_price_currency_id" bigint, "p_minimum_sell_price_amount" numeric, "p_minimum_sell_price_currency_id" bigint, "p_show_quantity" boolean, "p_display_quantity_override" integer, "p_is_active" boolean, "p_id" bigint, "p_is_price_locked" boolean, "p_is_quantity_locked" boolean, "p_quantity_override_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_shop_product_listing"("p_tenant_id" bigint, "p_shop_id" bigint, "p_global_stock_allocation_id" bigint DEFAULT NULL::bigint, "p_sell_price_amount" numeric DEFAULT NULL::numeric, "p_sell_price_currency_id" bigint DEFAULT NULL::bigint, "p_minimum_sell_price_amount" numeric DEFAULT NULL::numeric, "p_minimum_sell_price_currency_id" bigint DEFAULT NULL::bigint, "p_show_quantity" boolean DEFAULT NULL::boolean, "p_display_quantity_override" integer DEFAULT NULL::integer, "p_is_active" boolean DEFAULT true, "p_id" bigint DEFAULT NULL::bigint, "p_is_price_locked" boolean DEFAULT NULL::boolean, "p_is_quantity_locked" boolean DEFAULT NULL::boolean, "p_quantity_override_type" "text" DEFAULT NULL::"text", "p_global_stock_id" bigint DEFAULT NULL::bigint) RETURNS SETOF "public"."shop_product_listings"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_product_id bigint;
  v_target_stock_id bigint;
  v_existing record;
  v_price_locked boolean;
  v_qty_locked boolean;
  v_override_type text;
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id)
     and not public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(p_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  v_target_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id);

  if v_target_stock_id is null then
    raise exception 'global stock not found';
  select gsi.product_id into v_product_id
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gs.id = v_target_stock_id;

  if v_product_id is null then
    raise exception 'global stock not found';
  if p_id is not null then
    select * into v_existing from public.shop_product_listings where id = p_id;
  else
    select * into v_existing from public.shop_product_listings
    where shop_id = p_shop_id and global_stock_id = v_target_stock_id;
  v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
  v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
  v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

  if v_existing.id is not null then
    return query
    update public.shop_product_listings
    set
      sell_price_amount = p_sell_price_amount,
      sell_price_currency_id = p_sell_price_currency_id,
      minimum_sell_price_amount = p_minimum_sell_price_amount,
      minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
      show_quantity = coalesce(p_show_quantity, show_quantity),
      display_quantity_override = p_display_quantity_override,
      is_active = coalesce(p_is_active, true),
      is_price_locked = v_price_locked,
      is_quantity_locked = v_qty_locked,
      quantity_override_type = v_override_type,
      global_stock_allocation_id = null,
      updated_at = now()
    where id = v_existing.id
    returning *;
    return;
  return query
  insert into public.shop_product_listings (
    tenant_id,
    shop_id,
    global_stock_allocation_id,
    global_stock_id,
    product_id,
    sell_price_amount,
    sell_price_currency_id,
    minimum_sell_price_amount,
    minimum_sell_price_currency_id,
    show_quantity,
    display_quantity_override,
    is_active,
    is_price_locked,
    is_quantity_locked,
    quantity_override_type
  ) values (
    p_tenant_id,
    p_shop_id,
    null,
    v_target_stock_id,
    v_product_id,
    p_sell_price_amount,
    p_sell_price_currency_id,
    p_minimum_sell_price_amount,
    p_minimum_sell_price_currency_id,
    p_show_quantity,
    p_display_quantity_override,
    coalesce(p_is_active, true),
    v_price_locked,
    v_qty_locked,
    v_override_type
  )
  returning *;
ALTER FUNCTION "public"."upsert_shop_product_listing"("p_tenant_id" bigint, "p_shop_id" bigint, "p_global_stock_allocation_id" bigint, "p_sell_price_amount" numeric, "p_sell_price_currency_id" bigint, "p_minimum_sell_price_amount" numeric, "p_minimum_sell_price_currency_id" bigint, "p_show_quantity" boolean, "p_display_quantity_override" integer, "p_is_active" boolean, "p_id" bigint, "p_is_price_locked" boolean, "p_is_quantity_locked" boolean, "p_quantity_override_type" "text", "p_global_stock_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_can_manage_shop_tenant"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  );
ALTER FUNCTION "public"."user_can_manage_shop_tenant"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."restock_dropship_order_on_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item record;
  v_is_dropship boolean := false;
  v_new_alloc_qty integer;
  v_new_override_qty integer;
begin
  if OLD.shop_type_snapshot = 'dropship' then
    v_is_dropship := true;
  else
    select (shop_type = 'dropship') into v_is_dropship
    from public.shops
    where id = OLD.shop_id;
  if coalesce(v_is_dropship, false) then
    for v_item in select * from public.shop_order_items where order_id = OLD.id loop
      -- Restock display quantity override on shop listing (if set)
      if v_item.product_id is not null and v_item.global_stock_allocation_id is not null then
        update public.shop_product_listings
        set display_quantity_override = display_quantity_override + v_item.quantity
        where shop_id = OLD.shop_id
          and product_id = v_item.product_id
          and global_stock_allocation_id = v_item.global_stock_allocation_id
          and display_quantity_override is not null;
      -- Restock original quantity in stock allocation
      if v_item.global_stock_allocation_id is not null then
        update public.global_stock_allocations
        set quantity = quantity + v_item.quantity
        where id = v_item.global_stock_allocation_id;
      -- Restock original quantity in global stocks
      if v_item.global_stock_id is not null then
        update public.global_stocks
        set quantity = quantity + v_item.quantity
        where id = v_item.global_stock_id;
      -- Check updated available stock & override quantity; reactivate listing if > 0
      if v_item.product_id is not null and v_item.global_stock_allocation_id is not null then
        select gsa.quantity into v_new_alloc_qty
        from public.global_stock_allocations gsa
        where gsa.id = v_item.global_stock_allocation_id;

        select display_quantity_override into v_new_override_qty
        from public.shop_product_listings
        where shop_id = OLD.shop_id
          and product_id = v_item.product_id
          and global_stock_allocation_id = v_item.global_stock_allocation_id;

        if coalesce(v_new_override_qty, v_new_alloc_qty, 0) > 0 then
          update public.shop_product_listings
          set is_active = true
          where shop_id = OLD.shop_id
            and product_id = v_item.product_id
            and global_stock_allocation_id = v_item.global_stock_allocation_id;
        return OLD;
ALTER FUNCTION "public"."restock_dropship_order_on_delete"() OWNER TO "postgres";


