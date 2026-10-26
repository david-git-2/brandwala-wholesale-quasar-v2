create or replace function public.recompute_invoice_payment_status(p_invoice_id bigint)
returns void
language plpgsql
as $$
declare
  v_total numeric(12,2);
  v_paid numeric(12,2);
  v_is_paid boolean;
begin
  select total_amount, coalesce(paid_amount, 0)
  into v_total, v_paid
  from public.invoices
  where id = p_invoice_id;

  if not found then
    return;
  end if;

  v_is_paid := coalesce(v_paid, 0) >= coalesce(v_total, 0);

  update public.invoices
  set payment_status =
    case
      when coalesce(v_paid, 0) <= 0 then 'due'
      when v_is_paid then 'paid'
      else 'partially_paid'
    end,
    status =
    case
      when coalesce(v_paid, 0) <= 0 then status
      when v_is_paid then 'paid'
      else 'partially_paid'
    end,
    updated_at = now()
  where id = p_invoice_id;

  update public.inventory_accounting_entries
  set status = case when v_is_paid then 'paid' else 'due' end,
      updated_at = now()
  where invoice_id = p_invoice_id;
end;
$$;
