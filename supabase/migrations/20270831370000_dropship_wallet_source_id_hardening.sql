-- Harden dropship invoice_billed wallet rows: source_id must be shop_orders.id (text), never invoice_no.
-- Prevents 22P02 when legacy rows used INV-DS-* in universal_wallet_ledger.source_id.

begin;

-- ---------------------------------------------------------------------------
-- 1. Backfill legacy rows (broader than 20270831360000)
-- ---------------------------------------------------------------------------

-- 1a. Rows joined via global_invoice_id on shop_orders
update public.universal_wallet_ledger u
set
  source_id = o.id::text,
  metadata = coalesce(u.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'order_id', o.id,
      'invoice_id', i.id,
      'invoice_no', i.invoice_no
    )
from public.shop_orders o
join public.global_invoices i on i.id = o.global_invoice_id
where u.source_type = 'shop_order'
  and u.source_id = i.invoice_no
  and o.shop_type_snapshot = 'dropship'
  and coalesce(u.metadata->>'transaction_type', '') = 'invoice_billed';

-- 1b. Rows where source_id matches INV-DS-{order_no} without invoice join
update public.universal_wallet_ledger u
set
  source_id = o.id::text,
  metadata = coalesce(u.metadata, '{}'::jsonb) || jsonb_build_object('order_id', o.id)
from public.shop_orders o
where u.source_type = 'shop_order'
  and u.source_id = 'INV-DS-' || o.order_no
  and o.shop_type_snapshot = 'dropship'
  and coalesce(u.metadata->>'transaction_type', '') = 'invoice_billed';

-- 1c. Rows where metadata invoice_id links to a dropship order
update public.universal_wallet_ledger u
set
  source_id = o.id::text,
  metadata = coalesce(u.metadata, '{}'::jsonb) || jsonb_build_object('order_id', o.id)
from public.shop_orders o
join public.global_invoices i on i.id = o.global_invoice_id
where u.source_type = 'shop_order'
  and u.source_id = i.invoice_no
  and o.shop_type_snapshot = 'dropship'
  and coalesce(u.metadata->>'transaction_type', '') = 'invoice_billed'
  and coalesce(u.metadata->>'invoice_id', '') = i.id::text;

-- 1d. Link orphan dropship invoices back to their shop order (failed partial creates)
update public.shop_orders o
set
  global_invoice_id = i.id,
  updated_at = now()
from public.global_invoices i
where o.global_invoice_id is null
  and o.shop_type_snapshot = 'dropship'
  and i.invoice_type = 'dropship'::public.global_invoice_type
  and i.tenant_id = o.tenant_id
  and i.invoice_no = 'INV-DS-' || o.order_no
  and not exists (
    select 1
    from public.shop_orders o2
    where o2.global_invoice_id = i.id
      and o2.id <> o.id
  );

-- ---------------------------------------------------------------------------
-- 2. ensure_dropship_invoice_billed_entry — canonical order id only
-- ---------------------------------------------------------------------------
create or replace function public.ensure_dropship_invoice_billed_entry(
  p_invoice_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_order_id bigint;
begin
  select * into v_invoice
  from public.global_invoices
  where id = p_invoice_id;

  if v_invoice.id is null then
    return;
  end if;

  select o.id into v_order_id
  from public.shop_orders o
  where o.global_invoice_id = p_invoice_id
  order by o.id
  limit 1;

  if v_order_id is null and v_invoice.invoice_no like 'INV-DS-%' then
    select o.id into v_order_id
    from public.shop_orders o
    where o.tenant_id = v_invoice.tenant_id
      and o.shop_type_snapshot = 'dropship'
      and o.order_no = replace(v_invoice.invoice_no, 'INV-DS-', '')
    order by o.id desc
    limit 1;
  end if;

  if v_order_id is null then
    return;
  end if;

  -- Rewrite any legacy invoice_no source_id before idempotency check / insert
  update public.universal_wallet_ledger u
  set
    source_id = v_order_id::text,
    metadata = coalesce(u.metadata, '{}'::jsonb)
      || jsonb_build_object(
        'order_id', v_order_id,
        'invoice_id', p_invoice_id,
        'invoice_no', v_invoice.invoice_no
      )
  where u.source_type = 'shop_order'
    and u.entity_type = 'customer'
    and u.entity_id = v_invoice.billing_profile_id
    and coalesce(u.metadata->>'transaction_type', '') = 'invoice_billed'
    and u.source_id = v_invoice.invoice_no;

  if v_invoice.invoice_type = 'dropship'::public.global_invoice_type
     and v_invoice.invoice_status in (
       'issued'::public.global_invoice_status,
       'posted'::public.global_invoice_status
     )
     and v_invoice.billing_profile_id is not null
     and v_invoice.total_amount > 0
  then
    if not exists (
      select 1
      from public.universal_wallet_ledger
      where source_type = 'shop_order'
        and entity_type = 'customer'
        and entity_id = v_invoice.billing_profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
        and (
          metadata->>'invoice_id' = p_invoice_id::text
          or source_id = v_order_id::text
        )
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_invoice.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.billing_profile_id,
        p_type => 'debit',
        p_amount => v_invoice.total_amount,
        p_source_type => 'shop_order',
        p_source_id => v_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'invoice_billed',
          'label', 'Invoice Billed',
          'invoice_no', v_invoice.invoice_no,
          'invoice_id', p_invoice_id,
          'order_id', v_order_id
        )
      );
    end if;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. advance_dropship_order_status — delete wallet rows keyed by invoice_no too
-- ---------------------------------------------------------------------------
create or replace function public.advance_dropship_order_status(
  p_order_id bigint,
  p_target_status public.shop_order_status,
  p_remittance_ref text default null,
  p_bank_trx_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_current_status public.shop_order_status;
  v_is_valid boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  end if;

  v_current_status := v_order.status;

  if v_current_status = p_target_status then
    return jsonb_build_object('success', true, 'message', 'Status unchanged', 'new_status', p_target_status);
  end if;

  if v_current_status in ('submitted', 'draft', 'placed', 'confirmed')
     and p_target_status in ('processing', 'cancelled') then
    v_is_valid := true;
  elsif v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
    if p_target_status in (
      'processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received', 'cancelled'
    ) then
      v_is_valid := true;
    end if;
  end if;

  if not v_is_valid then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'Invalid status transition for dropship order from %s to %s',
        v_current_status,
        p_target_status
      )
    );
  end if;

  update public.shop_orders
  set
    status = p_target_status,
    delivered_at = case when p_target_status = 'delivered' then now() else delivered_at end,
    courier_remittance_ref = coalesce(p_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(p_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  select * into v_order from public.shop_orders where id = p_order_id;

  if p_target_status = 'processing' and v_order.global_invoice_id is not null then
    select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
    if v_invoice.invoice_status = 'issued'::public.global_invoice_status then
      perform public.unpost_global_invoice(v_order.global_invoice_id);
    end if;

    delete from public.universal_wallet_ledger
    where source_type = 'shop_order'
      and (
        source_id = p_order_id::text
        or source_id = v_order.order_no
        or source_id = v_invoice.invoice_no
      )
      and tenant_id = v_order.tenant_id;

    update public.shop_orders
    set global_invoice_id = null, updated_at = now()
    where id = p_order_id;

    delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
    delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
    delete from public.global_invoices where id = v_order.global_invoice_id;
  end if;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$$;

commit;
