begin;

-- =========================================================
-- 1. recompute_global_invoice_payment_status
-- =========================================================
create or replace function public.recompute_global_invoice_payment_status(p_global_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total numeric(12,2);
  v_paid numeric(12,2);
begin
  select total_amount, coalesce(paid_amount, 0.00)
  into v_total, v_paid
  from public.global_invoices
  where id = p_global_invoice_id;

  if not found then return; end if;

  update public.global_invoices
  set
    payment_status = case
      when coalesce(v_paid, 0.00) <= 0.00 then 'due'
      when v_paid >= coalesce(v_total, 0.00) then 'paid'
      else 'partially_paid'
    end,
    due_amount = greatest(coalesce(v_total, 0.00) - coalesce(v_paid, 0.00), 0.00),
    updated_at = now()
  where id = p_global_invoice_id;
end;
$$;

-- =========================================================
-- 2. Overload / Update recompute_global_invoice_totals to handle returns & payment status
-- =========================================================
create or replace function public.recompute_global_invoice_totals(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subtotal numeric(12,2);
  v_face_subtotal numeric(12,2);
  v_returned_subtotal numeric(12,2);
  v_returned_face_subtotal numeric(12,2);
  v_returned_charge numeric(12,2);
  v_invoice public.global_invoices;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then return; end if;

  -- Sum items
  select
    coalesce(sum(line_total_amount), 0.00),
    coalesce(sum(line_face_total_amount), 0.00)
  into v_subtotal, v_face_subtotal
  from public.global_invoice_items
  where invoice_id = p_invoice_id;

  -- Sum returns
  select
    coalesce(sum(return_accounting_amount), 0.00),
    coalesce(sum(return_face_amount), 0.00),
    coalesce(sum(return_charge_amount), 0.00)
  into v_returned_subtotal, v_returned_face_subtotal, v_returned_charge
  from public.global_return_items
  where invoice_id = p_invoice_id;

  -- Apply returns
  v_subtotal := greatest(v_subtotal - v_returned_subtotal, 0.00);
  v_face_subtotal := greatest(v_face_subtotal - greatest(v_returned_face_subtotal - v_returned_charge, 0.00), 0.00);

  update public.global_invoices
  set
    subtotal_amount = v_subtotal,
    face_subtotal_amount = v_face_subtotal,
    accounting_subtotal_amount = v_subtotal,
    middle_man_payout_amount = case
      when invoice_type = 'dropship'::public.global_invoice_type then greatest(v_face_subtotal - v_subtotal, 0.00)
      else 0.00
    end,
    total_amount = greatest(case
      when invoice_type = 'dropship'::public.global_invoice_type then v_face_subtotal + shipping_charge + cod_charge + wrapping_charge + print_charge - discount_amount
      else v_subtotal + shipping_charge + cod_charge + wrapping_charge + print_charge - discount_amount
    end, 0.00),
    due_amount = greatest(case
      when invoice_type = 'dropship'::public.global_invoice_type then v_face_subtotal + shipping_charge + cod_charge + wrapping_charge + print_charge - discount_amount
      else v_subtotal + shipping_charge + cod_charge + wrapping_charge + print_charge - discount_amount
    end - paid_amount, 0.00)
  where id = p_invoice_id;
  
  -- Recompute payment status
  perform public.recompute_global_invoice_payment_status(p_invoice_id);
end;
$$;

-- =========================================================
-- 3. add_global_return_item
-- =========================================================
create or replace function public.add_global_return_item(
  p_invoice_id bigint,
  p_invoice_item_id bigint,
  p_quantity numeric,
  p_return_face_amount numeric,
  p_return_accounting_amount numeric,
  p_return_charge_amount numeric default 0,
  p_note text default null
)
returns public.global_return_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items;
  v_row public.global_return_items;
  v_qty_to_restore integer;
begin
  -- Load and lock invoice
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'cannot return items on a non-posted invoice';
  end if;

  -- Load and lock invoice item
  select * into v_item from public.global_invoice_items where id = p_invoice_item_id for update;
  if v_item.id is null then raise exception 'invoice item not found'; end if;
  if v_item.invoice_id <> p_invoice_id then
    raise exception 'invoice item does not belong to the selected invoice';
  end if;

  -- Check quantity limit
  if v_item.return_quantity + p_quantity > v_item.quantity then
    raise exception 'return quantity exceeds available item quantity';
  end if;

  -- Insert return record
  insert into public.global_return_items (
    tenant_id,
    parent_tenant_id,
    invoice_id,
    invoice_item_id,
    global_stock_id,
    quantity,
    return_face_amount,
    return_accounting_amount,
    return_charge_amount,
    note
  )
  values (
    v_invoice.tenant_id,
    v_invoice.parent_tenant_id,
    p_invoice_id,
    p_invoice_item_id,
    v_item.global_stock_id,
    p_quantity,
    p_return_face_amount,
    p_return_accounting_amount,
    coalesce(p_return_charge_amount, 0.00),
    nullif(trim(p_note), '')
  )
  returning * into v_row;

  -- Update snapshot return_quantity on invoice item
  update public.global_invoice_items
  set return_quantity = return_quantity + p_quantity
  where id = p_invoice_item_id;

  -- Restore stock
  v_qty_to_restore := ceil(p_quantity)::integer;
  
  update public.global_stocks
  set quantity = quantity + v_qty_to_restore
  where id = v_item.global_stock_id;
  
  if exists (
    select 1 from public.global_stock_allocations
    where child_tenant_id = v_invoice.tenant_id and stock_id = v_item.global_stock_id
  ) then
    update public.global_stock_allocations
    set quantity = quantity + v_qty_to_restore
    where child_tenant_id = v_invoice.tenant_id and stock_id = v_item.global_stock_id;
  end if;

  -- Recompute totals
  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$$;

-- =========================================================
-- 4. create_billing_profile_payment_with_allocations
-- =========================================================
create or replace function public.create_billing_profile_payment_with_allocations(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_amount numeric,
  p_payment_date date,
  p_method text,
  p_reference text,
  p_note text,
  p_allocations jsonb
)
returns public.payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.payments;
  v_alloc jsonb;
  v_global_invoice_id bigint;
  v_commerce_invoice_id bigint;
  v_legacy_invoice_id bigint;
  v_alloc_amount numeric(12,2);
  v_total_alloc numeric(12,2) := 0;
  v_invoice record;
begin
  if p_tenant_id is null or p_billing_profile_id is null then
    raise exception 'Tenant and billing profile are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Payment amount must be greater than zero.';
  end if;

  insert into public.payments (
    tenant_id,
    billing_profile_id,
    amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    p_tenant_id,
    p_billing_profile_id,
    p_amount,
    coalesce(p_payment_date, current_date),
    p_method,
    p_reference,
    p_note
  )
  returning * into v_payment;

  if jsonb_typeof(coalesce(p_allocations, '[]'::jsonb)) <> 'array' then
    raise exception 'Allocations must be an array.';
  end if;

  for v_alloc in select * from jsonb_array_elements(coalesce(p_allocations, '[]'::jsonb))
  loop
    v_global_invoice_id := nullif(v_alloc->>'global_invoice_id', '')::bigint;
    v_commerce_invoice_id := nullif(v_alloc->>'commerce_invoice_id', '')::bigint;
    v_legacy_invoice_id := nullif(v_alloc->>'invoice_id', '')::bigint;
    v_alloc_amount := coalesce((v_alloc->>'amount')::numeric, 0.00);

    if v_alloc_amount <= 0.00 then continue; end if;

    if v_global_invoice_id is not null then
      select id, tenant_id, billing_profile_id, total_amount, paid_amount, collection_source
      into v_invoice
      from public.global_invoices where id = v_global_invoice_id for update;

      if not found then raise exception 'Global invoice % not found.', v_global_invoice_id; end if;
      if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
      if coalesce(v_invoice.billing_profile_id, 0) <> p_billing_profile_id then
        raise exception 'Invoice does not belong to billing profile.';
      end if;
      if v_invoice.collection_source = 'recipient'::public.collection_source_type then
        raise exception 'Dropship/Retail Direct invoices use recipient collection, not billing profile payment.';
      end if;

      insert into public.payment_allocations (tenant_id, payment_id, global_invoice_id, amount)
      values (p_tenant_id, v_payment.id, v_global_invoice_id, v_alloc_amount);

      update public.global_invoices
      set paid_amount = coalesce(paid_amount, 0.00) + v_alloc_amount, updated_at = now()
      where id = v_global_invoice_id;

      perform public.recompute_global_invoice_payment_status(v_global_invoice_id);

    elsif v_commerce_invoice_id is not null then
      select id, tenant_id, billing_profile_id, total_amount, amount_paid as paid_amount
      into v_invoice
      from public.commerce_invoices where id = v_commerce_invoice_id for update;

      if not found then raise exception 'Commerce invoice % not found.', v_commerce_invoice_id; end if;
      if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
      if coalesce(v_invoice.billing_profile_id, 0) <> p_billing_profile_id then
        raise exception 'Invoice does not belong to billing profile.';
      end if;

      insert into public.payment_allocations (tenant_id, payment_id, commerce_invoice_id, amount)
      values (p_tenant_id, v_payment.id, v_commerce_invoice_id, v_alloc_amount);

      update public.commerce_invoices
      set amount_paid = coalesce(amount_paid, 0.00) + v_alloc_amount, updated_at = now()
      where id = v_commerce_invoice_id;

    elsif v_legacy_invoice_id is not null then
      select id, tenant_id, billing_profile_id, total_amount, paid_amount
      into v_invoice
      from public.invoices where id = v_legacy_invoice_id for update;

      if not found then raise exception 'Legacy invoice % not found.', v_legacy_invoice_id; end if;
      if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
      if coalesce(v_invoice.billing_profile_id, 0) <> p_billing_profile_id then
        raise exception 'Invoice does not belong to billing profile.';
      end if;

      insert into public.payment_allocations (tenant_id, payment_id, invoice_id, amount)
      values (p_tenant_id, v_payment.id, v_legacy_invoice_id, v_alloc_amount);

      update public.invoices
      set paid_amount = coalesce(paid_amount, 0.00) + v_alloc_amount, updated_at = now()
      where id = v_legacy_invoice_id;

      perform public.recompute_invoice_payment_status(v_legacy_invoice_id);
    end if;

    v_total_alloc := v_total_alloc + v_alloc_amount;
  end loop;

  if v_total_alloc > p_amount then
    raise exception 'Total allocation exceeds payment amount.';
  end if;

  return v_payment;
end;
$$;

-- =========================================================
-- 5. record_recipient_invoice_collection
-- =========================================================
create or replace function public.record_recipient_invoice_collection(
  p_global_invoice_id bigint,
  p_amount numeric,
  p_note text default null
)
returns public.global_invoices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
begin
  select * into v_invoice from public.global_invoices where id = p_global_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.collection_source <> 'recipient'::public.collection_source_type then
    raise exception 'This invoice does not collect from recipient.';
  end if;
  if coalesce(p_amount, 0.00) <= 0.00 then raise exception 'Amount must be positive.'; end if;

  update public.global_invoices
  set
    paid_amount = coalesce(paid_amount, 0.00) + p_amount,
    note = coalesce(nullif(trim(p_note), ''), note),
    updated_at = now()
  where id = p_global_invoice_id
  returning * into v_invoice;

  perform public.recompute_global_invoice_payment_status(p_global_invoice_id);
  
  return v_invoice;
end;
$$;

-- =========================================================
-- 6. create_middle_man_payout
-- =========================================================
create or replace function public.create_middle_man_payout(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_global_invoice_id bigint,
  p_amount numeric,
  p_note text default null
)
returns public.global_invoices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_paid numeric(12,2) := 0.00;
  v_outstanding numeric(12,2);
begin
  select * into v_invoice from public.global_invoices where id = p_global_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_type <> 'dropship'::public.global_invoice_type then
    raise exception 'Not a dropship invoice.';
  end if;
  if v_invoice.billing_profile_id <> p_billing_profile_id then
    raise exception 'Billing profile mismatch.';
  end if;
  if coalesce(p_amount, 0.00) <= 0.00 then raise exception 'Amount must be positive.'; end if;

  select coalesce(sum(amount), 0.00) into v_paid
  from public.payments
  where tenant_id = p_tenant_id
    and billing_profile_id = p_billing_profile_id
    and note like ('middle_man_payout:' || p_global_invoice_id::text || '%');

  v_outstanding := greatest(coalesce(v_invoice.middle_man_payout_amount, 0.00) - v_paid, 0.00);
  if p_amount > v_outstanding then
    raise exception 'Payout exceeds outstanding middle-man amount.';
  end if;

  insert into public.payments (tenant_id, billing_profile_id, amount, payment_date, method, note)
  values (
    p_tenant_id,
    p_billing_profile_id,
    p_amount,
    current_date,
    'payout',
    'middle_man_payout:' || p_global_invoice_id::text || coalesce(' ' || nullif(trim(p_note), ''), '')
  );

  update public.global_invoices
  set
    middle_man_payout_status = case
      when (v_paid + p_amount) >= coalesce(middle_man_payout_amount, 0.00) then 'paid'
      else 'pending'
    end,
    updated_at = now()
  where id = p_global_invoice_id
  returning * into v_invoice;

  return v_invoice;
end;
$$;

-- =========================================================
-- 7. Grants
-- =========================================================
grant execute on function public.recompute_global_invoice_payment_status(bigint) to authenticated;
grant execute on function public.add_global_return_item(bigint, bigint, numeric, numeric, numeric, numeric, text) to authenticated;
grant execute on function public.create_billing_profile_payment_with_allocations(bigint, bigint, numeric, date, text, text, text, jsonb) to authenticated;
grant execute on function public.record_recipient_invoice_collection(bigint, numeric, text) to authenticated;
grant execute on function public.create_middle_man_payout(bigint, bigint, bigint, numeric, text) to authenticated;

commit;
