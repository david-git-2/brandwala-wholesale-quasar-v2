-- Migration: D6 ledger settlement wire-up
-- 1) create_middle_man_payout posts payout_paid to middle_man_payout_ledger
-- 2) record_dropship_courier_remittance: atomic collection + payment_received refs
begin;

-- ---------------------------------------------------------------------------
-- A. create_middle_man_payout — also insert payout_paid ledger entry
-- ---------------------------------------------------------------------------
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
  v_payment_id bigint;
  v_payment_note text;
  v_shop_order_id bigint;
  v_customer_group_id bigint;
  v_member_id bigint;
  v_prev_bal numeric(12,2) := 0.00;
  v_ref_notes text;
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
  from public.global_payments
  where tenant_id = p_tenant_id
    and billing_profile_id = p_billing_profile_id
    and note like ('middle_man_payout:' || p_global_invoice_id::text || '%');

  v_outstanding := greatest(coalesce(v_invoice.middle_man_payout_amount, 0.00) - v_paid, 0.00);
  if p_amount > v_outstanding then
    raise exception 'Payout exceeds outstanding middle-man amount.';
  end if;

  v_payment_note := 'middle_man_payout:' || p_global_invoice_id::text
    || coalesce(' ' || nullif(trim(p_note), ''), '');

  insert into public.global_payments (
    tenant_id, billing_profile_id, amount, unallocated_amount, payment_date, method, note
  )
  values (
    p_tenant_id,
    p_billing_profile_id,
    p_amount,
    0.00,
    current_date,
    'payout',
    v_payment_note
  )
  returning id into v_payment_id;

  update public.global_invoices
  set
    middle_man_payout_status = case
      when (v_paid + p_amount) >= coalesce(middle_man_payout_amount, 0.00) then 'paid'
      else 'pending'
    end,
    updated_at = now()
  where id = p_global_invoice_id
  returning * into v_invoice;

  -- Resolve linked shop order + customer group for ledger member
  select so.id, so.customer_group_id
    into v_shop_order_id, v_customer_group_id
  from public.shop_orders so
  where so.global_invoice_id = p_global_invoice_id
  order by so.id asc
  limit 1;

  if v_customer_group_id is null then
    select bp.customer_group_id into v_customer_group_id
    from public.billing_profiles bp
    where bp.id = p_billing_profile_id;
  end if;

  if v_customer_group_id is not null then
    select id into v_member_id
    from public.customer_group_members
    where customer_group_id = v_customer_group_id
      and is_active = true
    order by created_at asc
    limit 1;
  end if;

  if v_member_id is not null then
    v_ref_notes := 'Middle-man payout payment_id:' || v_payment_id::text
      || coalesce(' ' || nullif(trim(p_note), ''), '');

    -- Idempotency: skip if this payment already posted payout_paid
    if not exists (
      select 1
      from public.middle_man_payout_ledger
      where entry_type = 'payout_paid'
        and reference_notes like ('%payment_id:' || v_payment_id::text || '%')
    ) then
      v_prev_bal := coalesce((
        select balance_after
        from public.middle_man_payout_ledger
        where tenant_id = p_tenant_id
          and customer_group_member_id = v_member_id
        order by created_at desc
        limit 1
      ), 0.00);

      insert into public.middle_man_payout_ledger (
        tenant_id,
        customer_group_member_id,
        shop_order_id,
        global_invoice_id,
        entry_type,
        amount,
        balance_after,
        reference_notes
      )
      values (
        p_tenant_id,
        v_member_id,
        v_shop_order_id,
        p_global_invoice_id,
        'payout_paid',
        -p_amount,
        coalesce(v_prev_bal, 0.00) - p_amount,
        v_ref_notes
      );
    end if;
  end if;

  return v_invoice;
end;
$$;

grant execute on function public.create_middle_man_payout(bigint, bigint, bigint, numeric, text) to authenticated;

-- ---------------------------------------------------------------------------
-- B. record_dropship_courier_remittance — collection + payment_received (atomic)
-- ---------------------------------------------------------------------------
create or replace function public.record_dropship_courier_remittance(
  p_order_id bigint,
  p_net_amount numeric,
  p_remittance_ref text,
  p_bank_trx_id text default null,
  p_payment_date date default null,
  p_method text default 'cash',
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_invoice public.global_invoices;
  v_parent_tenant_id bigint;
  v_payment_id bigint;
  v_ref text;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order is not a dropship order';
  end if;

  if v_order.status <> 'delivered' then
    raise exception 'Courier remittance requires order status delivered (current: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is null then
    raise exception 'Accounting invoice is required before recording courier remittance';
  end if;

  v_ref := nullif(trim(coalesce(p_remittance_ref, '')), '');
  if v_ref is null then
    raise exception 'Remittance reference is required';
  end if;

  if coalesce(p_net_amount, 0.00) <= 0.00 then
    raise exception 'Net remittance amount must be positive';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);
  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required';
  end if;

  select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id for update;
  if v_invoice.id is null then
    raise exception 'invoice not found';
  end if;
  if v_invoice.collection_source <> 'recipient'::public.collection_source_type then
    raise exception 'This invoice does not collect from recipient.';
  end if;

  -- Same money-in path as record_recipient_invoice_collection
  insert into public.global_payments (
    tenant_id,
    billing_profile_id,
    collection_source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    v_invoice.tenant_id,
    null,
    'recipient'::public.collection_source_type,
    p_net_amount,
    0.00,
    coalesce(p_payment_date, current_date),
    coalesce(nullif(trim(p_method), ''), 'cash'),
    v_ref,
    coalesce(
      nullif(trim(p_note), ''),
      'Courier remittance order #' || v_order.order_no
        || coalesce(' bank:' || nullif(trim(p_bank_trx_id), ''), '')
    )
  )
  returning id into v_payment_id;

  insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
  values (v_invoice.tenant_id, v_payment_id, v_order.global_invoice_id, p_net_amount);

  update public.global_invoices
  set
    paid_amount = coalesce(paid_amount, 0.00) + p_net_amount,
    note = coalesce(nullif(trim(p_note), ''), note),
    updated_at = now()
  where id = v_order.global_invoice_id;

  perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);

  update public.shop_orders
  set
    status = 'payment_received'::public.shop_order_status,
    courier_remittance_ref = v_ref,
    courier_bank_trx_id = coalesce(nullif(trim(p_bank_trx_id), ''), courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_order.global_invoice_id,
    'payment_id', v_payment_id,
    'order_id', p_order_id,
    'status', 'payment_received'
  );
end;
$$;

grant execute on function public.record_dropship_courier_remittance(
  bigint, numeric, text, text, date, text, text
) to authenticated;

commit;
