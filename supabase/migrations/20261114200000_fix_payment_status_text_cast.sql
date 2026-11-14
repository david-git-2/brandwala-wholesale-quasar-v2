-- public.bills.payment_status is text, not global_payment_status enum

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
  SELECT * INTO v_invoice FROM public.bills WHERE id = p_bill_id FOR UPDATE;
  IF FOUND THEN
    PERFORM public.commit_wholesale_bill_stock(p_bill_id);
    RETURN public._kernel_issue_wholesale_stock(p_bill_id, p_items);
  END IF;

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
$$;CREATE OR REPLACE FUNCTION public.issue_bill(p_bill_id bigint)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, money_kernel, pg_temp
AS $$
declare
  v_bill public.bills;
  v_kernel money_kernel.bills;
  v_shipment_id bigint;
  v_invoice_type text;
begin
  select * into v_bill from public.bills where id = p_bill_id for update;
  if v_bill.id is not null then
    if v_bill.invoice_status <> 'draft'::public.global_invoice_status then
      raise exception 'only draft bills can be issued';
    end if;

    if v_bill.ap_shipment_id is not null
       and v_bill.invoice_type = 'ap'::public.global_invoice_type then
      perform public._assert_shipment_ap_issue_allowed(v_bill.ap_shipment_id);
    elsif v_bill.invoice_type = 'ap'::public.global_invoice_type
      and v_bill.source_type = 'shipment_cost'
      and nullif(trim(v_bill.source_id), '') is not null then
      perform public._assert_shipment_ap_issue_allowed(nullif(trim(v_bill.source_id), '')::bigint);
    end if;

    update public.bills
    set
      invoice_status = 'issued'::public.global_invoice_status,
      due_amount = total_amount,
      paid_amount = 0,
      payment_status = 'due',
      updated_at = now()
    where id = p_bill_id
    returning * into v_bill;

    perform public._kernel_freeze_bill_txn_face(p_bill_id);
    select * into v_bill from public.bills where id = p_bill_id;

    return v_bill;
  end if;

  select * into v_kernel from money_kernel.bills where id = p_bill_id for update;
  if not found then
    raise exception 'bill not found';
  end if;

  if v_kernel.status is distinct from 'draft' then
    raise exception 'only draft bills can be issued';
  end if;

  if not public.user_can_manage_books_tenant(v_kernel.tenant_id) then
    raise exception 'Permission denied';
  end if;

  v_invoice_type := public._desk_kernel_kind_invoice_type(v_kernel.kind);
  if v_invoice_type = 'ap' then
    v_shipment_id := nullif(v_kernel.meta->>'shipment_id', '')::bigint;
    if v_shipment_id is null and v_kernel.source_type = 'shipment_cost' then
      v_shipment_id := nullif(btrim(v_kernel.source_id), '')::bigint;
    end if;
    if v_shipment_id is not null then
      perform public._assert_shipment_ap_issue_allowed(v_shipment_id);
    end if;
  end if;

  perform public._kernel_backfill_stock_bill_lines(p_bill_id);
  perform public.rpc_issue_bill(v_kernel.tenant_id, p_bill_id);

  select * into v_bill from public.bills where id = p_bill_id;
  if found then
    perform public._kernel_freeze_bill_txn_face(p_bill_id);
    select * into v_bill from public.bills where id = p_bill_id;
    return v_bill;
  end if;

  select * into v_kernel from money_kernel.bills where id = p_bill_id;

  v_bill.id := v_kernel.id;
  v_bill.tenant_id := v_kernel.tenant_id;
  v_bill.issued_by_tenant_id := v_kernel.tenant_id;
  v_bill.invoice_type := coalesce(
    v_invoice_type::public.global_invoice_type,
    'wholesale'::public.global_invoice_type
  );
  v_bill.invoice_status := 'issued'::public.global_invoice_status;
  v_bill.payment_status := public._desk_kernel_status_payment(
    v_kernel.status,
    v_kernel.due_amount
  );
  v_bill.document_kind := 'standard'::public.bill_document_kind;
  v_bill.invoice_no := v_kernel.invoice_no;
  v_bill.invoice_date := v_kernel.invoice_date;
  v_bill.due_date := v_kernel.due_date;
  v_bill.total_amount := v_kernel.total_amount;
  v_bill.due_amount := v_kernel.due_amount;
  v_bill.paid_amount := coalesce(v_kernel.paid_amount, 0);
  v_bill.from_profile_id := v_kernel.from_profile_id;
  v_bill.to_profile_id := v_kernel.to_profile_id;
  v_bill.profile_id := v_kernel.counterparty_profile_id;
  v_bill.source_type := v_kernel.source_type;
  v_bill.source_id := v_kernel.source_id;
  v_bill.source_key := v_kernel.source_key;
  v_bill.currency_code := v_kernel.currency_code;
  v_bill.note := v_kernel.note;
  v_bill.ap_shipment_id := v_shipment_id;

  return v_bill;
end;
$$;

