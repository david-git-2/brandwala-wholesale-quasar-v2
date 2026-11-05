CREATE FUNCTION public.issue_bill (
  p_bill_id bigint
)
  RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_bill public.bills;
begin
  select * into v_bill from public.bills where id = p_bill_id for update;
  if v_bill.id is null then
    raise exception 'bill not found';
  end if;
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
end;
$function$;

GRANT ALL ON FUNCTION public.issue_bill(bigint) TO anon;

GRANT ALL ON FUNCTION public.issue_bill(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.issue_bill(bigint) TO service_role;