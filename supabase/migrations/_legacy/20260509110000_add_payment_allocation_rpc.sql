create or replace function public.add_payment_allocation(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_invoice_id bigint,
  p_amount numeric
)
returns public.payment_allocations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.payments;
  v_invoice public.invoices;
  v_allocated_total numeric(12,2);
  v_remaining numeric(12,2);
  v_due numeric(12,2);
  v_row public.payment_allocations;
begin
  if p_tenant_id is null or p_payment_id is null or p_invoice_id is null then
    raise exception 'Tenant, payment and invoice are required.';
  end if;

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Allocation amount must be greater than zero.';
  end if;

  select *
  into v_payment
  from public.payments
  where id = p_payment_id
  for update;

  if not found then
    raise exception 'Payment not found.';
  end if;

  if v_payment.tenant_id <> p_tenant_id then
    raise exception 'Payment does not belong to tenant.';
  end if;

  select *
  into v_invoice
  from public.invoices
  where id = p_invoice_id
  for update;

  if not found then
    raise exception 'Invoice not found.';
  end if;

  if v_invoice.tenant_id <> p_tenant_id then
    raise exception 'Invoice does not belong to tenant.';
  end if;

  if coalesce(v_invoice.billing_profile_id, 0) <> coalesce(v_payment.billing_profile_id, 0) then
    raise exception 'Invoice and payment billing profile mismatch.';
  end if;

  select coalesce(sum(amount), 0)
  into v_allocated_total
  from public.payment_allocations
  where payment_id = p_payment_id;

  v_remaining := coalesce(v_payment.amount, 0) - coalesce(v_allocated_total, 0);
  if p_amount > v_remaining then
    raise exception 'Allocation amount exceeds payment remaining amount.';
  end if;

  v_due := coalesce(v_invoice.total_amount, 0) - coalesce(v_invoice.paid_amount, 0);
  if p_amount > v_due then
    raise exception 'Allocation amount exceeds invoice due amount.';
  end if;

  insert into public.payment_allocations (
    tenant_id,
    payment_id,
    invoice_id,
    amount
  )
  values (
    p_tenant_id,
    p_payment_id,
    p_invoice_id,
    p_amount
  )
  returning * into v_row;

  update public.invoices
  set paid_amount = coalesce(paid_amount, 0) + p_amount,
      updated_at = now()
  where id = p_invoice_id;

  perform public.recompute_invoice_payment_status(p_invoice_id);

  return v_row;
end;
$$;

grant execute on function public.add_payment_allocation(bigint, bigint, bigint, numeric) to authenticated;
