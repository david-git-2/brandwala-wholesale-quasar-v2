-- Redeploy desk issue RPCs (missing on some local DBs; PostgREST PGRST202)

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

CREATE OR REPLACE FUNCTION public.issue_wholesale_invoice(p_invoice_id bigint, p_items jsonb DEFAULT NULL)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public.issue_wholesale_bill(p_invoice_id, p_items);
end;
$$;

GRANT EXECUTE ON FUNCTION public.issue_wholesale_bill(bigint, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_wholesale_bill(bigint, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.issue_wholesale_invoice(bigint, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_wholesale_invoice(bigint, jsonb) TO service_role;

NOTIFY pgrst, 'reload schema';