-- ============================================================================
-- Dropship Wallet Phase B: Courier wallet_entity_id + COD remittance allocation
-- Cap remittance vs COD collect; allocate net to invoice clear + merchant_funds_held;
-- post tenant delivery_fee for courier charge; use real courier wallet ids.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. courier_services.wallet_entity_id
-- ---------------------------------------------------------------------------
create sequence if not exists public.courier_wallet_entity_id_seq;

alter table public.courier_services
  add column if not exists wallet_entity_id bigint;

update public.courier_services
set wallet_entity_id = nextval('public.courier_wallet_entity_id_seq')
where wallet_entity_id is null;

alter table public.courier_services
  alter column wallet_entity_id set not null;

alter table public.courier_services
  alter column wallet_entity_id set default nextval('public.courier_wallet_entity_id_seq');

create unique index if not exists uq_courier_services_wallet_entity_id
  on public.courier_services (wallet_entity_id);

-- Backfill historic courier ledger rows (entity_id 0) when metadata has courier_service_id
update public.universal_wallet_ledger u
set entity_id = cs.wallet_entity_id
from public.courier_services cs
where u.entity_type = 'courier'
  and u.entity_id = 0
  and u.metadata->>'courier_service_id' is not null
  and cs.id::text = u.metadata->>'courier_service_id';

-- ---------------------------------------------------------------------------
-- 2. process_dropship_courier_remittance_uwl
-- ---------------------------------------------------------------------------
create or replace function public.process_dropship_courier_remittance_uwl(
  p_order_id bigint,
  p_net_amount numeric,
  p_courier_charge numeric default 0.00,
  p_remittance_ref text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_courier_id bigint := 0;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_gross numeric(12,2) := 0.00;
  v_currency text;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  v_currency := 'BDT';
  v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);
  v_gross := greatest(v_cod, coalesce(p_net_amount, 0) + v_charge);

  if v_order.courier_service_id is not null then
    select wallet_entity_id into v_courier_id
    from public.courier_services
    where id = v_order.courier_service_id;
  end if;
  v_courier_id := coalesce(v_courier_id, 0);

  -- Leg 1: Courier Debit (clears COD held)
  if not exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'courier_remittance'
  ) then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'debit',
      p_amount => v_gross,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'cod_pending',
        'purpose', 'courier_remittance',
        'transaction_type', 'courier_remittance',
        'label', 'COD Remittance Settled',
        'order_no', v_order.order_no,
        'courier_charge', v_charge,
        'net_remitted', p_net_amount,
        'gross_cod', v_cod,
        'remittance_ref', p_remittance_ref,
        'courier_service_id', v_order.courier_service_id
      )
    );
  end if;

  -- Leg 2: Tenant Credit (net cash received)
  if not exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and entity_type = 'tenant'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_order.tenant_id,
      p_type => 'credit',
      p_amount => p_net_amount,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payment_received',
        'purpose', 'tenant_remittance_received',
        'transaction_type', 'courier_remittance_received',
        'label', 'Courier Remittance Received',
        'order_no', v_order.order_no,
        'gross_cod', v_cod,
        'courier_charge', v_charge,
        'remittance_ref', p_remittance_ref
      )
    );
  end if;

  -- Leg 3: Tenant Debit courier costs (feeds Total Courier Costs KPI)
  if v_charge > 0 and not exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and entity_type = 'tenant'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_courier_charge'
  ) then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_order.tenant_id,
      p_type => 'debit',
      p_amount => v_charge,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'delivery_fee',
        'purpose', 'tenant_courier_charge',
        'transaction_type', 'courier_charge',
        'label', 'Courier Delivery / COD Fee',
        'order_no', v_order.order_no,
        'courier_charge', v_charge,
        'remittance_ref', p_remittance_ref
      )
    );
  end if;
end;
$$;

grant execute on function public.process_dropship_courier_remittance_uwl(bigint, numeric, numeric, text) to authenticated;
grant execute on function public.process_dropship_courier_remittance_uwl(bigint, numeric, numeric, text) to service_role;

-- ---------------------------------------------------------------------------
-- 3. record_dropship_courier_remittance — COD cap + invoice allocation
-- ---------------------------------------------------------------------------
create or replace function public.record_dropship_courier_remittance(
  p_order_id bigint,
  p_net_amount numeric,
  p_remittance_ref text,
  p_bank_trx_id text default null,
  p_payment_date date default null,
  p_method text default 'cash',
  p_note text default null,
  p_courier_charge numeric default 0.00
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
  v_cod numeric(12,2);
  v_charge numeric(12,2);
  v_net numeric(12,2);
  v_invoice_due numeric(12,2);
  v_invoice_pay numeric(12,2);
  v_profit_hold numeric(12,2);
  v_currency text := 'BDT';
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

  v_net := coalesce(p_net_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);
  v_cod := coalesce(v_order.cod_collect_amount, 0.00);

  if v_net <= 0.00 then
    raise exception 'Net remittance amount must be positive';
  end if;

  if v_charge < 0.00 then
    raise exception 'Courier charge cannot be negative';
  end if;

  -- Cap: net + charge must not exceed COD collect (full economic remittance)
  if v_cod > 0 and (v_net + v_charge) > (v_cod + 0.01) then
    raise exception 'Remittance net (%) + charge (%) exceeds COD collect (%)', v_net, v_charge, v_cod;
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
    raise exception 'Invoice not found';
  end if;
  if v_invoice.collection_source <> 'recipient'::public.collection_source_type then
    raise exception 'This invoice does not collect from recipient.';
  end if;

  v_invoice_due := greatest(coalesce(v_invoice.total_amount, 0.00) - coalesce(v_invoice.paid_amount, 0.00), 0.00);
  v_invoice_pay := least(v_net, v_invoice_due);
  v_profit_hold := greatest(v_net - v_invoice_pay, 0.00);

  -- 1. UWL courier + tenant remittance + courier fee
  -- Allocation is returned to caller; held remainder stays as cash float until profit payout
  -- (dropship_profit already accrued on billing profile at accounting invoice).
  perform public.process_dropship_courier_remittance_uwl(
    p_order_id => p_order_id,
    p_net_amount => v_net,
    p_courier_charge => v_charge,
    p_remittance_ref => v_ref
  );

  -- Annotate remittance credit with allocation breakdown
  update public.universal_wallet_ledger
  set metadata = metadata || jsonb_build_object(
    'invoice_allocated', v_invoice_pay,
    'merchant_funds_held', v_profit_hold
  )
  where tenant_id = v_order.tenant_id
    and entity_type = 'tenant'
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received';

  -- 2. Clear B2B invoice up to due (do not over-pay invoice)
  if v_invoice_pay > 0 then
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
      v_invoice_pay,
      0.00,
      coalesce(p_payment_date, current_date),
      coalesce(nullif(trim(p_method), ''), 'cash'),
      v_ref,
      coalesce(
        nullif(trim(p_note), ''),
        'Courier remittance order #' || v_order.order_no
          || coalesce(' bank:' || nullif(trim(p_bank_trx_id), ''), '')
          || ' (invoice ' || v_invoice_pay::text || ' / held ' || v_profit_hold::text || ')'
      )
    )
    returning id into v_payment_id;

    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_invoice.tenant_id, v_payment_id, v_order.global_invoice_id, v_invoice_pay);

    update public.global_invoices
    set
      paid_amount = coalesce(paid_amount, 0.00) + v_invoice_pay,
      note = coalesce(nullif(trim(p_note), ''), note),
      updated_at = now()
    where id = v_order.global_invoice_id;

    perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);

    -- Clear customer AR for the invoice portion (idempotent)
    if v_invoice.billing_profile_id is not null and not exists (
      select 1 from public.universal_wallet_ledger
      where tenant_id = v_order.tenant_id
        and entity_type = 'customer'
        and entity_id = v_invoice.billing_profile_id
        and source_type = 'shop_order'
        and source_id = p_order_id::text
        and metadata->>'transaction_type' = 'invoice_collection'
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.billing_profile_id,
        p_type => 'credit',
        p_amount => v_invoice_pay,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'invoice_collection',
          'label', 'Invoice Cleared via COD Remittance',
          'order_no', v_order.order_no,
          'invoice_id', v_order.global_invoice_id,
          'invoice_no', v_invoice.invoice_no,
          'remittance_ref', v_ref
        )
      );
    end if;
  end if;

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
    'status', 'payment_received',
    'net_amount', v_net,
    'courier_charge', v_charge,
    'invoice_allocated', v_invoice_pay,
    'merchant_funds_held', v_profit_hold
  );
end;
$$;

grant execute on function public.record_dropship_courier_remittance(
  bigint, numeric, text, text, date, text, text, numeric
) to authenticated;

commit;
