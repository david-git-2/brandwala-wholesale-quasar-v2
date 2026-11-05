CREATE FUNCTION public._test_issue_ar_bill (
  p_tenant_id           bigint,
  p_customer_profile_id bigint,
  p_amount              numeric,
  p_invoice_no          text    DEFAULT NULL::text
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_bill public.bills;
  v_no text := coalesce(nullif(trim(p_invoice_no), ''), 'PGTAP-' || substr(md5(random()::text), 1, 8));
  v_amt numeric(12, 2) := round(coalesce(p_amount, 0), 2);
BEGIN
  PERFORM public._test_pgtap_auth();

  IF v_amt <= 0 THEN
    RAISE EXCEPTION 'amount must be positive';
  END IF;

  v_bill := public.create_sales_invoice(
    p_tenant_id,
    v_no,
    'wholesale'::public.global_invoice_type,
    p_customer_profile_id
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
    'pgTAP line',
    1,
    v_amt,
    0,
    v_amt
  );

  UPDATE public.bills
  SET
    subtotal_amount = v_amt,
    total_amount = v_amt,
    due_amount = v_amt,
    channel_meta = coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('delivery_kind', 'take'),
    settlement_kind = 'take'::public.bill_settlement_kind,
    updated_at = now()
  WHERE id = v_bill.id;

  PERFORM public.stamp_bill_kernel_fields(v_bill.id);
  PERFORM public.issue_bill(v_bill.id);

  RETURN v_bill.id;
END;
$function$;

GRANT ALL ON FUNCTION public._test_issue_ar_bill(bigint, bigint, numeric, text) TO anon;

GRANT ALL ON FUNCTION public._test_issue_ar_bill(bigint, bigint, numeric, text) TO authenticated;

GRANT ALL ON FUNCTION public._test_issue_ar_bill(bigint, bigint, numeric, text) TO service_role;