CREATE FUNCTION public.convert_wholesale_draft_to_retail (
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
  -- Fetch the invoice
  select * into v_invoice from public.bills where id = p_invoice_id;
  if v_invoice.id is null then 
    raise exception 'Invoice not found'; 
  end if;

  -- Verify it is a wholesale invoice and in draft status
  if v_invoice.invoice_type <> 'wholesale'::public.global_invoice_type then
    raise exception 'Only wholesale invoices can be converted to retail';
  end if;
  
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'Only draft invoices can be converted to retail';
  end if;

  -- Update invoice type to retail and mode to account
  update public.bills
  set
    invoice_type = 'retail'::public.global_invoice_type,
    retail_billing_mode = 'account'::public.retail_billing_mode,
    updated_at = now()
  where id = p_invoice_id;
end;
$function$;

GRANT ALL ON FUNCTION public.convert_wholesale_draft_to_retail(bigint) TO anon;

GRANT ALL ON FUNCTION public.convert_wholesale_draft_to_retail(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.convert_wholesale_draft_to_retail(bigint) TO service_role;