CREATE FUNCTION public.void_sales_invoice (
  p_invoice_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_invoice public.bills;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'only issued invoices can be voided';
  end if;
  if v_invoice.paid_amount > 0 then
    raise exception 'cannot void a paid or partially paid invoice; reverse collections/payments first';
  end if;

  if v_invoice.document_kind = 'standard'::public.bill_document_kind
     and exists (
       select 1 from public.bills n
       where n.parent_bill_id = p_invoice_id
         and n.invoice_status <> 'voided'::public.global_invoice_status
     ) then
    raise exception 'void or issue credit on child notes before voiding this bill';
  end if;

  update public.bills
  set
    invoice_status = 'voided'::public.global_invoice_status,
    due_amount = 0.00
  where id = p_invoice_id;

  if v_invoice.parent_bill_id is not null then
    perform public.recompute_global_invoice_payment_status(v_invoice.parent_bill_id);
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.void_sales_invoice(bigint) TO anon;

GRANT ALL ON FUNCTION public.void_sales_invoice(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.void_sales_invoice(bigint) TO service_role;