CREATE FUNCTION public.list_global_invoice_items (
  p_invoice_id bigint
)
  RETURNS TABLE (
    id                      bigint,
    invoice_id              bigint,
    global_stock_id         bigint,
    name_snapshot           text,
    quantity                numeric,
    sell_price_amount       numeric,
    recipient_price_amount  numeric,
    line_face_total_amount  numeric,
    line_discount_amount    numeric,
    line_total_amount       numeric,
    return_quantity         numeric,
    image_url               text,
    shipment_id             bigint,
    shipment_item_id        bigint,
    purchase_price          numeric,
    product_weight          numeric,
    package_weight          numeric,
    ordered_quantity        integer,
    shipment_type           text,
    product_conversion_rate numeric,
    cargo_conversion_rate   numeric,
    cargo_rate              numeric,
    received_weight         numeric,
    transaction_rate        numeric,
    available_atp           numeric,
    unit_cost_price         numeric
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_parent_tenant_id bigint;
  v_issued_by bigint;
  v_invoice_status public.global_invoice_status;
BEGIN
  SELECT parent_tenant_id, issued_by_tenant_id, invoice_status
  INTO v_parent_tenant_id, v_issued_by, v_invoice_status
  FROM public.bills
  WHERE public.bills.id = p_invoice_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice with ID % not found', p_invoice_id;
  END IF;

  IF NOT (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    OR public.has_active_tenant_membership(v_issued_by)
    OR public.membership_has_module_action(v_issued_by, 'global_invoice', 'view')
  ) THEN
    RAISE EXCEPTION 'Access denied for invoice with ID %', p_invoice_id;
  END IF;

  RETURN QUERY
  SELECT
    gii.id,
    gii.invoice_id,
    gii.global_stock_id,
    gii.name_snapshot,
    gii.quantity,
    gii.sell_price_amount,
    nullif(gii.line_meta->>'resell_price_amount', '')::numeric AS recipient_price_amount,
    (gii.quantity * nullif(gii.line_meta->>'resell_price_amount', '')::numeric) AS line_face_total_amount,
    gii.line_discount_amount,
    gii.line_total_amount,
    gii.return_quantity,
    CASE
      WHEN gii.line_kind = 'stock'::text THEN coalesce(gsi.image_url, p.image_url)
      ELSE NULL::text
    END AS image_url,
    gsi.shipment_id,
    gsi.id AS shipment_item_id,
    gsi.purchase_price,
    gsi.product_weight,
    gsi.package_weight,
    gsi.ordered_quantity,
    gship.type::text AS shipment_type,
    NULL::numeric AS product_conversion_rate,
    NULL::numeric AS cargo_conversion_rate,
    NULL::numeric AS cargo_rate,
    gship.received_weight,
    NULL::numeric AS transaction_rate,
    CASE
      WHEN gii.global_stock_id IS NULL THEN 0::numeric
      WHEN v_invoice_status IN (
        'draft'::public.global_invoice_status,
        'proforma_generated'::public.global_invoice_status
      )
        THEN (
          coalesce(public.global_stock_atp_qty(gii.global_stock_id), gs.quantity, 0) + gii.quantity
        )::numeric
      ELSE (coalesce(public.global_stock_atp_qty(gii.global_stock_id), gs.quantity, 0))::numeric
    END AS available_atp,
    coalesce(gsi.landed_cost_bdt, gsi.purchase_price, 0)::numeric AS unit_cost_price
  FROM public.global_invoice_items gii
  LEFT JOIN public.global_stocks gs ON gs.id = gii.global_stock_id
  LEFT JOIN public.global_shipment_items gsi
    ON gsi.id = coalesce(gii.shipment_item_id, gs.shipment_item_id)
  LEFT JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
  LEFT JOIN public.products p ON p.id = gii.product_id
  WHERE gii.invoice_id = p_invoice_id
  ORDER BY gii.id;
END;
$function$;

GRANT ALL ON FUNCTION public.list_global_invoice_items(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_global_invoice_items(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_global_invoice_items(bigint) TO service_role;