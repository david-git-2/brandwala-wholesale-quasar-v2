-- Migration: Add function to convert draft wholesale invoice to retail account mode

create or replace function public.convert_wholesale_draft_to_retail(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
begin
  -- Fetch the invoice
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
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
  update public.global_invoices
  set
    invoice_type = 'retail'::public.global_invoice_type,
    retail_billing_mode = 'account'::public.retail_billing_mode,
    updated_at = now()
  where id = p_invoice_id;
end;
$$;

grant execute on function public.convert_wholesale_draft_to_retail(bigint) to authenticated;
