-- Bills desk public API wrappers (delegate to legacy; do not ALTER 05_money_spine.sql)

CREATE OR REPLACE FUNCTION public.update_draft_bill(
  p_tenant_id bigint,
  p_bill_id bigint,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_update_compose_draft(p_tenant_id, p_bill_id, p_payload);
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_wholesale_bill(
  p_bill_id bigint,
  p_items jsonb DEFAULT NULL
)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, money_kernel, pg_temp
AS $$
DECLARE
  v_invoice public.bills;
  v_kernel money_kernel.bills;
BEGIN
  SELECT * INTO v_kernel
  FROM money_kernel.bills
  WHERE id = p_bill_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;

  IF v_kernel.kind NOT IN ('sales_invoice_wholesale', 'sales_invoice_dropship') THEN
    RAISE EXCEPTION 'Only wholesale sales bills can be issued via issue_wholesale_bill';
  END IF;

  IF v_kernel.status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'Only draft bills can be issued';
  END IF;

  IF NOT public.user_can_manage_books_tenant(v_kernel.tenant_id) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  PERFORM public._kernel_backfill_stock_bill_lines(p_bill_id);
  PERFORM public.commit_wholesale_bill_stock(p_bill_id);
  PERFORM public.rpc_issue_bill(v_kernel.tenant_id, p_bill_id);

  SELECT * INTO v_kernel FROM money_kernel.bills WHERE id = p_bill_id;

  v_invoice.id := v_kernel.id;
  v_invoice.tenant_id := v_kernel.tenant_id;
  v_invoice.issued_by_tenant_id := v_kernel.tenant_id;
  v_invoice.invoice_type := CASE v_kernel.kind
    WHEN 'sales_invoice_dropship' THEN 'dropship'::public.global_invoice_type
    ELSE 'wholesale'::public.global_invoice_type
  END;
  v_invoice.invoice_status := 'issued'::public.global_invoice_status;
  v_invoice.payment_status := public._desk_kernel_status_payment(v_kernel.status, v_kernel.due_amount);
  v_invoice.document_kind := 'standard'::public.bill_document_kind;
  v_invoice.invoice_no := v_kernel.invoice_no;
  v_invoice.invoice_date := v_kernel.invoice_date;
  v_invoice.due_date := v_kernel.due_date;
  v_invoice.total_amount := v_kernel.total_amount;
  v_invoice.due_amount := v_kernel.due_amount;
  v_invoice.paid_amount := coalesce(v_kernel.paid_amount, 0);
  v_invoice.from_profile_id := v_kernel.from_profile_id;
  v_invoice.to_profile_id := v_kernel.to_profile_id;
  v_invoice.profile_id := v_kernel.counterparty_profile_id;
  v_invoice.source_type := v_kernel.source_type;
  v_invoice.source_id := v_kernel.source_id;
  v_invoice.source_key := v_kernel.source_key;
  v_invoice.currency_code := v_kernel.currency_code;
  v_invoice.note := v_kernel.note;

  RETURN v_invoice;
END;
$$;

CREATE OR REPLACE FUNCTION public.issue_retail_bill(p_bill_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  perform public.post_sales_invoice(p_bill_id);
end;
$$;

GRANT EXECUTE ON FUNCTION public.update_draft_bill(bigint, bigint, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_draft_bill(bigint, bigint, jsonb) TO service_role;

GRANT EXECUTE ON FUNCTION public.issue_wholesale_bill(bigint, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_wholesale_bill(bigint, jsonb) TO service_role;

GRANT EXECUTE ON FUNCTION public.issue_retail_bill(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_retail_bill(bigint) TO service_role;

CREATE OR REPLACE FUNCTION public.issue_ap_bill_from_desk(p_bill_id bigint)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, money_kernel, pg_temp
AS $$
DECLARE
  v_bill   public.bills;
  v_kernel money_kernel.bills;
  v_result public.bills;
  v_issue  jsonb;
  v_shipment_id bigint;
BEGIN
  SELECT * INTO v_kernel
    FROM money_kernel.bills
   WHERE id = p_bill_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;

  IF public._desk_kernel_kind_invoice_type(v_kernel.kind) IS DISTINCT FROM 'ap' THEN
    RAISE EXCEPTION 'Only AP bills can be issued from the bills desk';
  END IF;

  IF v_kernel.kind IN ('credit_note', 'debit_note') THEN
    RAISE EXCEPTION 'Only standard AP bills can be issued from the bills desk';
  END IF;

  IF v_kernel.status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'Only draft AP bills can be issued from the bills desk';
  END IF;

  IF COALESCE(v_kernel.total_amount, 0) <= 0 THEN
    RAISE EXCEPTION 'Bill total must be greater than zero';
  END IF;

  IF NOT public.user_can_manage_books_tenant(v_kernel.tenant_id) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  v_shipment_id := NULLIF(v_kernel.meta->>'shipment_id', '')::bigint;
  IF v_shipment_id IS NULL AND v_kernel.source_type = 'shipment_cost' THEN
    v_shipment_id := NULLIF(BTRIM(v_kernel.source_id), '')::bigint;
  END IF;
  IF v_shipment_id IS NOT NULL THEN
    PERFORM public._assert_shipment_ap_issue_allowed(v_shipment_id);
  END IF;

  PERFORM set_config('app.bill_desk_issue_shipment_ap', '1', true);
  PERFORM set_config('app.shipment_ap_issue', '1', true);
  BEGIN
    v_issue := public.rpc_issue_bill(v_kernel.tenant_id, p_bill_id);
  EXCEPTION
    WHEN OTHERS THEN
      PERFORM set_config('app.bill_desk_issue_shipment_ap', '0', true);
      PERFORM set_config('app.shipment_ap_issue', '0', true);
      RAISE;
  END;
  PERFORM set_config('app.bill_desk_issue_shipment_ap', '0', true);
  PERFORM set_config('app.shipment_ap_issue', '0', true);

  SELECT * INTO v_result FROM public.bills WHERE id = p_bill_id;
  IF FOUND THEN
    PERFORM public.stamp_bill_kernel_fields(p_bill_id);
    RETURN v_result;
  END IF;

  SELECT * INTO v_kernel FROM money_kernel.bills WHERE id = p_bill_id;

  v_result.id := v_kernel.id;
  v_result.tenant_id := v_kernel.tenant_id;
  v_result.invoice_type := 'ap'::public.global_invoice_type;
  v_result.document_kind := 'standard'::public.bill_document_kind;
  v_result.invoice_status := 'issued'::public.global_invoice_status;
  v_result.payment_status := 'due';
  v_result.total_amount := v_kernel.total_amount;
  v_result.due_amount := v_kernel.due_amount;
  v_result.paid_amount := COALESCE(v_kernel.paid_amount, 0);
  v_result.invoice_no := v_kernel.invoice_no;
  v_result.ap_shipment_id := v_shipment_id;
  v_result.source_type := v_kernel.source_type;
  v_result.source_id := v_kernel.source_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.issue_ap_bill_from_desk(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_ap_bill_from_desk(bigint) TO service_role;

CREATE OR REPLACE FUNCTION public.patch_bill_dates_from_desk(
  p_tenant_id bigint,
  p_bill_id bigint,
  p_invoice_date date,
  p_due_date date DEFAULT NULL,
  p_touch_due_date boolean DEFAULT false
)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_parent_id bigint;
begin
  if p_tenant_id is null or p_bill_id is null then
    raise exception 'tenant_id and bill_id are required';
  end if;

  if p_invoice_date is null then
    raise exception 'invoice_date is required';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  select * into v_bill from public.bills where id = p_bill_id for update;
  if v_bill.id is null then
    raise exception 'bill not found';
  end if;

  if not (v_bill.tenant_id = v_parent_id or v_bill.issued_by_tenant_id = p_tenant_id) then
    raise exception 'Invoice not found for this tenant.';
  end if;

  if not public.user_can_manage_books_tenant(v_bill.tenant_id) then
    raise exception 'Permission denied';
  end if;

  if v_bill.invoice_status = 'voided'::public.global_invoice_status then
    raise exception 'Cannot change dates on a voided bill';
  end if;

  update public.bills
  set
    invoice_date = p_invoice_date,
    due_date = case
      when p_touch_due_date then p_due_date
      else due_date
    end,
    updated_at = now()
  where id = p_bill_id
  returning * into v_bill;

  return v_bill;
end;
$$;

GRANT EXECUTE ON FUNCTION public.patch_bill_dates_from_desk(bigint, bigint, date, date, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.patch_bill_dates_from_desk(bigint, bigint, date, date, boolean) TO service_role;

-- list_bills_desk_page + get_bill_detail_bundle: see 06b_desk_kernel_bridge.sql
