create or replace function public.update_payment_allocation_amount(
  p_tenant_id bigint,
  p_allocation_id bigint,
  p_amount numeric
)
returns public.payment_allocations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alloc public.payment_allocations;
  v_payment public.payments;
  v_invoice public.invoices;
  v_other_allocated numeric(12,2);
  v_remaining numeric(12,2);
  v_due_excluding_current numeric(12,2);
  v_delta numeric(12,2);
begin
  if p_tenant_id is null or p_allocation_id is null then
    raise exception 'Tenant and allocation are required.';
  end if;

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Allocation amount must be greater than zero.';
  end if;

  select *
  into v_alloc
  from public.payment_allocations
  where id = p_allocation_id
  for update;

  if not found then
    raise exception 'Allocation not found.';
  end if;

  if v_alloc.tenant_id <> p_tenant_id then
    raise exception 'Allocation does not belong to tenant.';
  end if;

  select *
  into v_payment
  from public.payments
  where id = v_alloc.payment_id
  for update;

  if not found then
    raise exception 'Payment not found.';
  end if;

  select *
  into v_invoice
  from public.invoices
  where id = v_alloc.invoice_id
  for update;

  if not found then
    raise exception 'Invoice not found.';
  end if;

  if coalesce(v_payment.billing_profile_id, 0) <> coalesce(v_invoice.billing_profile_id, 0) then
    raise exception 'Payment and invoice billing profile mismatch.';
  end if;

  select coalesce(sum(amount), 0)
  into v_other_allocated
  from public.payment_allocations
  where payment_id = v_alloc.payment_id
    and id <> v_alloc.id;

  v_remaining := coalesce(v_payment.amount, 0) - coalesce(v_other_allocated, 0);
  if p_amount > v_remaining then
    raise exception 'Allocation amount exceeds payment remaining amount.';
  end if;

  v_due_excluding_current :=
    coalesce(v_invoice.total_amount, 0) - (coalesce(v_invoice.paid_amount, 0) - coalesce(v_alloc.amount, 0));
  if p_amount > v_due_excluding_current then
    raise exception 'Allocation amount exceeds invoice due amount.';
  end if;

  v_delta := p_amount - coalesce(v_alloc.amount, 0);

  update public.payment_allocations
  set amount = p_amount
  where id = v_alloc.id
  returning * into v_alloc;

  update public.invoices
  set paid_amount = coalesce(paid_amount, 0) + v_delta,
      updated_at = now()
  where id = v_invoice.id;

  perform public.recompute_invoice_payment_status(v_invoice.id);

  return v_alloc;
end;
$$;

grant execute on function public.update_payment_allocation_amount(bigint, bigint, numeric) to authenticated;
