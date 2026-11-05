CREATE FUNCTION public._test_bootstrap_dropship_golden_a (
  p_ctx jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_tenant bigint := (p_ctx ->> 'tenant_id')::bigint;
  v_merchant_profile bigint := (p_ctx ->> 'customer_profile_id')::bigint;
  v_point bigint := (p_ctx ->> 'cashbook_point_id')::bigint;
  v_bdt bigint;
  v_shop_id bigint;
  v_courier_id uuid;
  v_product_id bigint;
  v_order_id bigint;
  v_bill public.bills;
  v_ap jsonb;
  v_deliver jsonb;
  v_order_no text := 'PGTAP-A-' || substr(md5(random()::text), 1, 8);
BEGIN
  PERFORM public._test_pgtap_auth();

  PERFORM public._test_enable_tenant_module(v_tenant, 'shop_order_mgmt');
  PERFORM public._test_enable_tenant_module(v_tenant, 'global_invoice');

  PERFORM public.upsert_membership_grant(
    (
      SELECT m.id
      FROM public.memberships m
      WHERE m.tenant_id = v_tenant
        AND lower(trim(m.email)) = 'pgtap+money@kernel.test'
      LIMIT 1
    ),
    'shop_order_mgmt',
    'view',
    'allow'
  );

  PERFORM public.upsert_membership_grant(
    (
      SELECT m.id
      FROM public.memberships m
      WHERE m.tenant_id = v_tenant
        AND lower(trim(m.email)) = 'pgtap+money@kernel.test'
      LIMIT 1
    ),
    'shop_order_mgmt',
    'edit',
    'allow'
  );

  v_bdt := public._test_ensure_global_currency('BDT', 'Bangladesh Taka', '৳');

  INSERT INTO public.shops (
    tenant_id,
    parent_tenant_id,
    name,
    slug,
    shop_type,
    order_mode,
    is_negotiable,
    buy_currency_id,
    sell_currency_id,
    default_currency_id,
    pricing_method,
    quantity_display_mode,
    is_active
  )
  VALUES (
    v_tenant,
    v_tenant,
    'pgTAP Dropship',
    'pgtap-ds-' || substr(md5(random()::text), 1, 8),
    'dropship'::public.shop_type_enum,
    'checkout_fixed'::public.shop_order_mode_enum,
    false,
    v_bdt,
    v_bdt,
    v_bdt,
    'direct_cost',
    'original',
    true
  )
  RETURNING id INTO v_shop_id;

  INSERT INTO public.courier_services (
    tenant_id,
    code,
    name,
    is_active,
    cod_fee_mode,
    inside_dhaka_fee,
    outside_dhaka_fee
  )
  VALUES (
    v_tenant,
    'PGTAP-C-' || substr(md5(random()::text), 1, 6),
    'pgTAP Courier',
    true,
    'none',
    80.00,
    120.00
  )
  RETURNING id INTO v_courier_id;

  INSERT INTO public.products (
    name,
    parent_tenant_id,
    inserted_by_tenant_id,
    source,
    is_available
  )
  VALUES (
    'pgTAP Dropship SKU',
    v_tenant,
    v_tenant,
    'website',
    true
  )
  RETURNING id INTO v_product_id;

  INSERT INTO public.shop_orders (
    tenant_id,
    parent_tenant_id,
    shop_id,
    order_no,
    name,
    shop_type_snapshot,
    order_mode_snapshot,
    status,
    profile_id,
    created_by_email,
    collection_source,
    cod_collect_amount,
    delivery_charge_amount,
    cod_charge_amount,
    sender_name,
    pickup_phone,
    pickup_address,
    recipient_name,
    recipient_phone,
    shipping_address,
    delivery_zone,
    courier_service_id,
    courier_name
  )
  VALUES (
    v_tenant,
    v_tenant,
    v_shop_id,
    v_order_no,
    'Golden A order',
    'dropship'::public.shop_type_enum,
    'checkout_fixed'::public.shop_order_mode_enum,
    'ready_for_pickup'::public.shop_order_status,
    v_merchant_profile,
    'pgtap+money@kernel.test',
    'recipient'::public.collection_source_type,
    2200.00,
    80.00,
    0.00,
    'pgTAP Sender',
    '+8801700000000',
    'Dhaka pickup',
    'Recipient',
    '+8801800000000',
    'Dhaka ship',
    'inside_dhaka',
    v_courier_id,
    'pgTAP Courier'
  )
  RETURNING id INTO v_order_id;

  INSERT INTO public.shop_order_items (
    order_id,
    product_id,
    name,
    quantity,
    confirmed_quantity,
    customer_sell_price_amount,
    customer_sell_price_currency_id,
    final_price_amount,
    final_price_currency_id,
    cost_price_amount,
    cost_price_currency_id
  )
  VALUES (
    v_order_id,
    v_product_id,
    'pgTAP line',
    1,
    1,
    1500.0000,
    v_bdt,
    1500.0000,
    v_bdt,
    900.0000,
    v_bdt
  );

  v_bill := public.create_sales_invoice(
    v_tenant,
    'INV-DS-' || v_order_no,
    'dropship'::public.global_invoice_type,
    v_merchant_profile
  );

  INSERT INTO public.bill_lines (
    parent_tenant_id,
    invoice_id,
    line_kind,
    name_snapshot,
    quantity,
    sell_price_amount,
    line_discount_amount,
    line_total_amount
  )
  VALUES (
    v_bill.parent_tenant_id,
    v_bill.id,
    'description',
    'pgTAP dropship sales',
    1,
    1500.00,
    0,
    1500.00
  );

  UPDATE public.bills
  SET
    subtotal_amount = 1500.00,
    total_amount = 1500.00,
    due_amount = 1500.00,
    shop_order_id = v_order_id,
    collection_source = 'profile'::public.collection_source_type,
    updated_at = now()
  WHERE id = v_bill.id;

  PERFORM public.stamp_bill_kernel_fields(v_bill.id);
  PERFORM public.issue_bill(v_bill.id);

  UPDATE public.shop_orders
  SET
    global_invoice_id = v_bill.id,
    status = 'shipped'::public.shop_order_status,
    updated_at = now()
  WHERE id = v_order_id;

  v_ap := public.upsert_dropship_courier_ap_bill(v_order_id, false);
  IF coalesce(v_ap ->> 'success', 'false') <> 'true' THEN
    RAISE EXCEPTION 'golden A courier AP failed: %', v_ap;
  END IF;

  v_deliver := public.mark_dropship_order_delivered(
    v_tenant,
    v_order_id,
    jsonb_build_object(
      'collected_cod_amount', 2200,
      'charge_lines', '[]'::jsonb
    )
  );
  IF coalesce(v_deliver ->> 'success', 'false') <> 'true' THEN
    RAISE EXCEPTION 'golden A deliver failed: %', v_deliver;
  END IF;

  RETURN p_ctx
    || jsonb_build_object(
      'dropship_order_id', v_order_id,
      'dropship_merchant_profile_id', v_merchant_profile,
      'dropship_courier_id', v_courier_id
    );
END;
$function$;

GRANT ALL ON FUNCTION public._test_bootstrap_dropship_golden_a(jsonb) TO anon;

GRANT ALL ON FUNCTION public._test_bootstrap_dropship_golden_a(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public._test_bootstrap_dropship_golden_a(jsonb) TO service_role;