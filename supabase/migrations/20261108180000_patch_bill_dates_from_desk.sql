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
