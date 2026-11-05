CREATE FUNCTION public._test_bootstrap_shipment_ap_fx (
  p_tenant_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_parent bigint := public.resolve_parent_tenant_id(p_tenant_id);
  v_usd bigint;
  v_gbp bigint;
  v_vendor_id bigint;
  v_cargo_id bigint;
  v_shipment_id bigint;
  v_sync jsonb;
  v_material_bill bigint;
  v_freight_bill bigint;
  v_cargo_profile bigint;
BEGIN
  PERFORM public._test_pgtap_auth();

  v_usd := public._test_ensure_global_currency('USD', 'US Dollar', '$');
  v_gbp := public._test_ensure_global_currency('GBP', 'British Pound', '£');

  IF NOT EXISTS (SELECT 1 FROM public.markets mk WHERE mk.code = 'US') THEN
    INSERT INTO public.markets (name, code, region, is_active, is_system)
    VALUES ('United States', 'US', 'Americas', true, true);
  END IF;

  INSERT INTO public.vendors (name, code, market_code, parent_tenant_id)
  VALUES ('pgTAP Vendor', 'PGV-' || substr(md5(random()::text), 1, 6), 'US', v_parent)
  RETURNING id INTO v_vendor_id;

  INSERT INTO public.cargo_companies (parent_tenant_id, name, code, is_active)
  VALUES (v_parent, 'pgTAP Cargo', 'PGC-' || substr(md5(random()::text), 1, 6), true)
  RETURNING id INTO v_cargo_id;

  INSERT INTO public.global_shipments (
    parent_tenant_id,
    name,
    status,
    vendor_id,
    cargo_company_id,
    stock_ready,
    costs_locked
  )
  VALUES (
    v_parent,
    'S-42 pgTAP',
    'received',
    v_vendor_id,
    v_cargo_id,
    true,
    false
  )
  RETURNING id INTO v_shipment_id;

  INSERT INTO public.global_shipment_cost_entries (
    parent_tenant_id,
    shipment_id,
    amount,
    currency_id,
    cost_bucket,
    cost_component,
    description
  )
  VALUES
    (v_parent, v_shipment_id, 100.00, v_usd, 'material', 'subtotal', 'Material USD'),
    (v_parent, v_shipment_id, 50.00, v_gbp, 'freight', 'subtotal', 'Freight GBP');

  PERFORM set_config('app.allow_costs_lock', '1', true);
  UPDATE public.global_shipments
  SET
    costs_locked = true,
    costs_locked_at = now(),
    updated_at = now()
  WHERE id = v_shipment_id;

  v_sync := public.sync_shipment_ap_bills(v_shipment_id);
  IF coalesce(v_sync ->> 'success', 'false') <> 'true' THEN
    RAISE EXCEPTION 'golden B sync_shipment_ap_bills failed: %', v_sync;
  END IF;

  PERFORM set_config('app.shipment_ap_issue', '1', true);
  PERFORM public.issue_shipment_ap_bills(v_shipment_id);
  PERFORM set_config('app.shipment_ap_issue', '0', true);

  v_sync := jsonb_build_object('success', true);

  SELECT b.id INTO v_material_bill
  FROM public.bills b
  WHERE b.parent_tenant_id = v_parent
    AND b.source_type = 'shipment_cost'
    AND b.source_id = v_shipment_id::text
    AND b.invoice_type = 'ap'::public.global_invoice_type
    AND b.source_key = 'material'
  ORDER BY b.id DESC
  LIMIT 1;

  SELECT b.id INTO v_freight_bill
  FROM public.bills b
  WHERE b.parent_tenant_id = v_parent
    AND b.source_type = 'shipment_cost'
    AND b.source_id = v_shipment_id::text
    AND b.invoice_type = 'ap'::public.global_invoice_type
    AND b.source_key = 'freight'
  ORDER BY b.id DESC
  LIMIT 1;

  IF v_material_bill IS NULL OR v_freight_bill IS NULL THEN
    RAISE EXCEPTION 'golden B: expected material and freight AP bills';
  END IF;

  SELECT p.id INTO v_cargo_profile
  FROM public.profiles p
  WHERE p.parent_tenant_id = v_parent
    AND p.profile_type = 'cargo'::public.profile_party_type
    AND p.subject_id = v_cargo_id
  LIMIT 1;

  IF v_cargo_profile IS NULL THEN
    RAISE EXCEPTION 'golden B: cargo profile missing after sync';
  END IF;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'parent_tenant_id', v_parent,
    'shipment_id', v_shipment_id,
    'material_bill_id', v_material_bill,
    'freight_bill_id', v_freight_bill,
    'cargo_profile_id', v_cargo_profile
  );
END;
$function$;

GRANT ALL ON FUNCTION public._test_bootstrap_shipment_ap_fx(bigint) TO anon;

GRANT ALL ON FUNCTION public._test_bootstrap_shipment_ap_fx(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._test_bootstrap_shipment_ap_fx(bigint) TO service_role;