-- Migration: 20270915000200_payment_allocation_rpcs.sql
-- Description: RPCs for Payment Reconciliation:
--              1. recompute_global_invoice_payment_status (handles write-offs and allocations)
--              2. list_customer_groups_payment_summary
--              3. list_open_invoices_for_payment
--              4. record_batch_customer_payment

-- 1. Updated recompute_global_invoice_payment_status
CREATE OR REPLACE FUNCTION public.recompute_global_invoice_payment_status(p_global_invoice_id bigint)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_total numeric(12,2);
  v_paid numeric(12,2);
  v_written_off numeric(12,2);
  v_due numeric(12,2);
begin
  select total_amount into v_total from public.sales_invoices where id = p_global_invoice_id for update;
  if not found then return; end if;

  select coalesce(sum(amount), 0.00) into v_paid
  from public.invoice_payments where global_invoice_id = p_global_invoice_id;

  select coalesce(sum(amount), 0.00) into v_written_off
  from public.invoice_write_offs where invoice_id = p_global_invoice_id;

  v_due := greatest(coalesce(v_total, 0.00) - v_paid - v_written_off, 0.00);

  update public.sales_invoices
  set
    paid_amount = v_paid,
    written_off_amount = v_written_off,
    due_amount = v_due,
    payment_status = case
      when v_due = 0.00 and v_written_off > 0.00 then 'settled_with_write_off'
      when v_due = 0.00 and v_paid > 0.00 then 'paid'
      when v_paid > 0.00 or v_written_off > 0.00 then 'partially_paid'
      else 'due'
    end,
    updated_at = now()
  where id = p_global_invoice_id;
end;
$$;

ALTER FUNCTION public.recompute_global_invoice_payment_status(bigint) OWNER TO postgres;

-- 2. list_customer_groups_payment_summary
CREATE OR REPLACE FUNCTION public.list_customer_groups_payment_summary(
  p_tenant_id bigint,
  p_search text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      cg.id,
      cg.name,
      'CUST-GRP-' || lpad(cg.id::text, 4, '0') as account_code,
      coalesce(
        (select bp.phone from public.billing_profiles bp where bp.customer_group_id = cg.id and bp.phone is not null limit 1),
        '—'
      ) as phone,
      coalesce(
        (select array_agg(bp.name order by bp.name) from public.billing_profiles bp where bp.customer_group_id = cg.id),
        array[]::text[]
      ) as branches,
      coalesce(
        count(distinct si.id) filter (where si.invoice_status = 'issued' and si.due_amount > 0),
        0
      )::int as open_invoice_count,
      coalesce(
        sum(si.total_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_invoiced,
      coalesce(
        sum(si.due_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_due,
      (
        select max(gp.payment_date)
        from public.global_payments gp
        where gp.customer_group_id = cg.id
           or gp.billing_profile_id in (select id from public.billing_profiles where customer_group_id = cg.id)
      ) as last_payment_date
    from public.customer_groups cg
    left join public.billing_profiles bp on bp.customer_group_id = cg.id
    left join public.sales_invoices si on si.billing_profile_id = bp.id
    where (cg.parent_tenant_id = v_parent_id or cg.tenant_id = p_tenant_id)
      and (
        p_search is null
        or trim(p_search) = ''
        or cg.name ilike '%' || trim(p_search) || '%'
        or bp.name ilike '%' || trim(p_search) || '%'
        or bp.phone ilike '%' || trim(p_search) || '%'
      )
    group by cg.id, cg.name
    order by total_due desc, cg.name asc
    limit coalesce(p_limit, 50)
    offset coalesce(p_offset, 0)
  ) r;

  return v_result;
end;
$$;

ALTER FUNCTION public.list_customer_groups_payment_summary(bigint, text, int, int) OWNER TO postgres;

-- 3. list_open_invoices_for_payment
CREATE OR REPLACE FUNCTION public.list_open_invoices_for_payment(
  p_tenant_id bigint,
  p_customer_group_id bigint DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      si.id,
      si.invoice_no,
      si.invoice_type::text as invoice_type,
      cg.id as customer_group_id,
      coalesce(cg.name, bp.name, si.recipient_name, 'Direct Customer') as customer_group_name,
      coalesce(bp.name, 'Main Outlet') as branch_name,
      si.invoice_date,
      si.due_date,
      si.total_amount,
      si.paid_amount,
      si.written_off_amount,
      si.due_amount,
      si.payment_status
    from public.sales_invoices si
    left join public.billing_profiles bp on bp.id = si.billing_profile_id
    left join public.customer_groups cg on cg.id = bp.customer_group_id
    where (si.parent_tenant_id = v_parent_id or si.issued_by_tenant_id = p_tenant_id)
      and si.invoice_status = 'issued'
      and si.due_amount > 0
      and (p_customer_group_id is null or cg.id = p_customer_group_id)
      and (
        p_search is null
        or trim(p_search) = ''
        or si.invoice_no ilike '%' || trim(p_search) || '%'
        or cg.name ilike '%' || trim(p_search) || '%'
        or bp.name ilike '%' || trim(p_search) || '%'
        or si.recipient_name ilike '%' || trim(p_search) || '%'
      )
    order by si.invoice_date asc, si.id asc
    limit coalesce(p_limit, 50)
    offset coalesce(p_offset, 0)
  ) r;

  return v_result;
end;
$$;

ALTER FUNCTION public.list_open_invoices_for_payment(bigint, bigint, text, int, int) OWNER TO postgres;

-- 4. record_batch_customer_payment
CREATE OR REPLACE FUNCTION public.record_batch_customer_payment(
  p_tenant_id bigint,
  p_customer_group_id bigint DEFAULT NULL,
  p_billing_profile_id bigint DEFAULT NULL,
  p_amount numeric DEFAULT 0,
  p_payment_date date DEFAULT CURRENT_DATE,
  p_method text DEFAULT 'bank_transfer',
  p_reference text DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_write_offs jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_parent_id bigint;
  v_payment public.global_payments;
  v_alloc jsonb;
  v_wo jsonb;
  v_invoice_id bigint;
  v_alloc_amount numeric(12,2);
  v_wo_amount numeric(12,2);
  v_wo_reason text;
  v_wo_note text;
  v_total_alloc numeric(12,2) := 0.00;
  v_total_wo numeric(12,2) := 0.00;
  v_primary_bp_id bigint := p_billing_profile_id;
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required.';
  end if;
  if coalesce(p_amount, 0) < 0 then
    raise exception 'Payment amount cannot be negative.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  -- If customer group provided but no billing profile, resolve first billing profile
  if v_primary_bp_id is null and p_customer_group_id is not null then
    select id into v_primary_bp_id
    from public.billing_profiles
    where customer_group_id = p_customer_group_id
    limit 1;
  end if;

  -- Create Payment record
  insert into public.global_payments (
    tenant_id,
    customer_group_id,
    billing_profile_id,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    p_tenant_id,
    p_customer_group_id,
    v_primary_bp_id,
    coalesce(p_amount, 0.00),
    coalesce(p_amount, 0.00),
    coalesce(p_payment_date, current_date),
    coalesce(p_method, 'bank_transfer'),
    p_reference,
    p_note
  )
  returning * into v_payment;

  -- Process Allocations
  if jsonb_typeof(coalesce(p_allocations, '[]'::jsonb)) = 'array' then
    for v_alloc in select * from jsonb_array_elements(p_allocations)
    loop
      v_invoice_id := (v_alloc->>'invoice_id')::bigint;
      v_alloc_amount := coalesce((v_alloc->>'amount')::numeric, 0.00);

      if v_invoice_id is not null and v_alloc_amount > 0.00 then
        insert into public.invoice_payments (
          tenant_id,
          payment_id,
          global_invoice_id,
          amount
        )
        values (
          p_tenant_id,
          v_payment.id,
          v_invoice_id,
          v_alloc_amount
        );

        perform public.recompute_global_invoice_payment_status(v_invoice_id);
        v_total_alloc := v_total_alloc + v_alloc_amount;
      end if;
    end loop;
  end if;

  -- Process Write-Offs
  if jsonb_typeof(coalesce(p_write_offs, '[]'::jsonb)) = 'array' then
    for v_wo in select * from jsonb_array_elements(p_write_offs)
    loop
      v_invoice_id := (v_wo->>'invoice_id')::bigint;
      v_wo_amount := coalesce((v_wo->>'amount')::numeric, 0.00);
      v_wo_reason := coalesce(v_wo->>'reason', 'dispute_settlement');
      v_wo_note := v_wo->>'note';

      if v_invoice_id is not null and v_wo_amount > 0.00 then
        insert into public.invoice_write_offs (
          tenant_id,
          parent_tenant_id,
          invoice_id,
          payment_id,
          amount,
          reason,
          note,
          approved_by
        )
        values (
          p_tenant_id,
          v_parent_id,
          v_invoice_id,
          v_payment.id,
          v_wo_amount,
          v_wo_reason,
          v_wo_note,
          auth.uid()
        );

        perform public.recompute_global_invoice_payment_status(v_invoice_id);
        v_total_wo := v_total_wo + v_wo_amount;
      end if;
    end loop;
  end if;

  if v_total_alloc > coalesce(p_amount, 0.00) then
    raise exception 'Total allocations (% BDT) exceed payment received (% BDT).', v_total_alloc, p_amount;
  end if;

  -- Update unallocated amount
  update public.global_payments
  set unallocated_amount = coalesce(p_amount, 0.00) - v_total_alloc
  where id = v_payment.id;

  -- Universal Wallet Entries (if amount > 0)
  if coalesce(p_amount, 0.00) > 0.00 then
    -- 1. Tenant Cash Receipt
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => p_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_payment.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'batch_payment_received',
        'payment_id', v_payment.id,
        'customer_group_id', p_customer_group_id,
        'reference', p_reference
      )
    );

    -- 2. Customer AR Reduction (if billing profile linked)
    if v_primary_bp_id is not null then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_primary_bp_id,
        p_type => 'credit',
        p_amount => p_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => v_payment.id::text,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'customer_ar_reduction',
          'payment_id', v_payment.id,
          'reference', p_reference
        )
      );
    end if;
  end if;

  return jsonb_build_object(
    'payment_id', v_payment.id,
    'total_amount', p_amount,
    'total_allocated', v_total_alloc,
    'total_written_off', v_total_wo,
    'unallocated_amount', coalesce(p_amount, 0.00) - v_total_alloc,
    'payment_date', v_payment.payment_date,
    'reference', v_payment.reference
  );
end;
$$;

ALTER FUNCTION public.record_batch_customer_payment(bigint, bigint, bigint, numeric, date, text, text, text, jsonb, jsonb) OWNER TO postgres;
