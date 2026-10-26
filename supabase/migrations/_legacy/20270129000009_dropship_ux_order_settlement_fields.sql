-- Dropship UX: denormalize collection_source + payout_settlement_status onto shop_orders
-- so desk/hub/detail badges and prepaid remittance gates read real columns.

begin;

-- 1. Columns
alter table public.shop_orders
  add column if not exists collection_source public.collection_source_type null;

alter table public.shop_orders
  add column if not exists payout_settlement_status text null
    check (
      payout_settlement_status is null
      or payout_settlement_status in ('unpaid', 'partial', 'paid')
    );

comment on column public.shop_orders.collection_source is
  'Copied from linked global_invoices.collection_source for dropship COD vs prepaid gates';
comment on column public.shop_orders.payout_settlement_status is
  'Merchant profit settlement: unpaid | partial | paid (order-level)';

-- 2. Backfill collection_source from invoice
update public.shop_orders o
set collection_source = i.collection_source
from public.global_invoices i
where o.global_invoice_id = i.id
  and o.collection_source is distinct from i.collection_source;

-- Prepaid without invoice yet: hint from snapshot
update public.shop_orders
set collection_source = 'billing_profile'::public.collection_source_type
where shop_type_snapshot = 'dropship'
  and global_invoice_id is null
  and is_prepaid_snapshot = true
  and collection_source is null;

update public.shop_orders
set collection_source = 'recipient'::public.collection_source_type
where shop_type_snapshot = 'dropship'
  and global_invoice_id is null
  and coalesce(is_prepaid_snapshot, false) = false
  and collection_source is null
  and status::text in (
    'processing', 'ready_for_pickup', 'shipped', 'delivered', 'payment_received', 'returned'
  );

-- 3. Backfill settlement: invoiced dropship with profit credit → unpaid; else leave null
update public.shop_orders o
set payout_settlement_status = 'unpaid'
where o.shop_type_snapshot = 'dropship'
  and o.global_invoice_id is not null
  and o.payout_settlement_status is null
  and exists (
    select 1
    from public.universal_wallet_ledger u
    where u.tenant_id = o.tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = o.id::text
      and u.entity_type in ('middleman', 'customer')
      and u.type = 'credit'
      and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit'
  );

-- 4. Keep collection_source in sync when invoice is linked on the order
create or replace function public.sync_shop_order_collection_source_from_invoice()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_src public.collection_source_type;
begin
  if new.global_invoice_id is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.global_invoice_id is not distinct from new.global_invoice_id
     and new.collection_source is not null then
    return new;
  end if;

  select collection_source into v_src
  from public.global_invoices
  where id = new.global_invoice_id;

  if v_src is not null then
    new.collection_source := v_src;
    if new.payout_settlement_status is null
       and new.shop_type_snapshot = 'dropship' then
      new.payout_settlement_status := 'unpaid';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_shop_orders_sync_collection_source on public.shop_orders;
create trigger trg_shop_orders_sync_collection_source
  before insert or update of global_invoice_id
  on public.shop_orders
  for each row
  execute function public.sync_shop_order_collection_source_from_invoice();

-- 5. FIFO allocate merchant payout across unpaid dropship orders for that billing profile
create or replace function public.apply_dropship_payout_settlement_fifo(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_amount numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_remaining numeric := greatest(coalesce(p_amount, 0), 0);
  r record;
  v_profit numeric;
begin
  if v_remaining <= 0 then
    return;
  end if;

  -- Only fully unpaid orders (partial stays until a later settled_amount column exists)
  for r in
    select o.id
    from public.shop_orders o
    where o.tenant_id = p_tenant_id
      and o.billing_profile_id = p_billing_profile_id
      and o.shop_type_snapshot = 'dropship'
      and o.global_invoice_id is not null
      and coalesce(o.payout_settlement_status, 'unpaid') = 'unpaid'
    order by o.created_at asc, o.id asc
  loop
    exit when v_remaining <= 0;

    select coalesce(sum(u.amount), 0) into v_profit
    from public.universal_wallet_ledger u
    where u.tenant_id = p_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = r.id::text
      and u.entity_type in ('middleman', 'customer')
      and u.type = 'credit'
      and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit';

    if v_profit <= 0 then
      update public.shop_orders
      set payout_settlement_status = 'paid',
          updated_at = now()
      where id = r.id;
      continue;
    end if;

    if v_remaining >= v_profit then
      update public.shop_orders
      set payout_settlement_status = 'paid',
          updated_at = now()
      where id = r.id;
      v_remaining := v_remaining - v_profit;
    else
      update public.shop_orders
      set payout_settlement_status = 'partial',
          updated_at = now()
      where id = r.id;
      v_remaining := 0;
    end if;
  end loop;
end;
$$;

-- Wrap dispense to call FIFO settlement (replace body end — full function)
create or replace function public.dispense_middleman_payout_from_tenant(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_amount numeric,
  p_payout_method text default 'bank_transfer',
  p_reference_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.billing_profiles;
  v_payout_id text;
begin
  if p_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'Tenant ID is required');
  end if;

  if p_billing_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'Billing Profile ID is required');
  end if;

  if coalesce(p_amount, 0) <= 0 then
    return jsonb_build_object('success', false, 'error', 'Payout amount must be greater than 0');
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    return jsonb_build_object('success', false, 'error', format('Permission denied for tenant %s', p_tenant_id));
  end if;

  select * into v_profile
  from public.billing_profiles
  where id = p_billing_profile_id and tenant_id = p_tenant_id;

  if v_profile.id is null then
    return jsonb_build_object('success', false, 'error', format('Billing profile #%s not found for tenant %s', p_billing_profile_id, p_tenant_id));
  end if;

  v_payout_id := 'PO-' || gen_random_uuid()::text;

  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => p_tenant_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_payout_id,
    p_metadata => jsonb_build_object(
      'purpose', 'middleman_payout_tenant_debit',
      'billing_profile_id', p_billing_profile_id,
      'billing_profile_name', v_profile.name,
      'payout_method', p_payout_method,
      'notes', p_reference_notes
    )
  );

  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'middleman',
    p_entity_id => p_billing_profile_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_payout_id,
    p_metadata => jsonb_build_object(
      'purpose', 'middleman_payout_debit',
      'payout_method', p_payout_method,
      'notes', p_reference_notes
    )
  );

  perform public.apply_dropship_payout_settlement_fifo(
    p_tenant_id,
    p_billing_profile_id,
    p_amount
  );

  return jsonb_build_object(
    'success', true,
    'payout_id', v_payout_id,
    'billing_profile_id', p_billing_profile_id,
    'amount', p_amount
  );
end;
$$;

grant execute on function public.dispense_middleman_payout_from_tenant(bigint, bigint, numeric, text, text) to authenticated;
grant execute on function public.dispense_middleman_payout_from_tenant(bigint, bigint, numeric, text, text) to service_role;

-- 6. Desk list returns settlement fields
drop function if exists public.list_dropship_shop_orders_for_staff(bigint, integer, integer, text, text);

create or replace function public.list_dropship_shop_orders_for_staff(
  p_tenant_id bigint,
  p_limit integer default 20,
  p_offset integer default 0,
  p_status text default null,
  p_search text default null
)
returns table (
  id bigint,
  order_no text,
  status public.shop_order_status,
  created_at timestamptz,
  customer_group_name text,
  created_by_email text,
  recipient_name text,
  recipient_phone text,
  courier_name text,
  courier_awb_number text,
  cod_collect_amount numeric,
  total_amount numeric,
  global_invoice_id bigint,
  courier_remittance_ref text,
  collection_source public.collection_source_type,
  payout_settlement_status text
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  return query
  select
    o.id,
    o.order_no,
    o.status,
    o.created_at,
    cg.name as customer_group_name,
    o.created_by_email,
    o.recipient_name,
    o.recipient_phone,
    coalesce(cs.name, o.courier_name) as courier_name,
    o.courier_awb_number,
    o.cod_collect_amount,
    coalesce(
      (
        select sum(
          coalesce(
            final_price_amount,
            staff_offer_amount,
            customer_offer_amount,
            unit_sell_price_amount,
            unit_list_price_amount
          ) * quantity
        )
        from public.shop_order_items
        where order_id = o.id
      ),
      0
    )::numeric as total_amount,
    o.global_invoice_id,
    o.courier_remittance_ref,
    o.collection_source,
    o.payout_settlement_status
  from public.shop_orders o
  join public.customer_groups cg on cg.id = o.customer_group_id
  left join public.courier_services cs on cs.id::text = o.courier_service_id::text
  where o.tenant_id = p_tenant_id
    and o.shop_type_snapshot = 'dropship'
    and (
      case
        when p_status is null then o.status::text in (
          'submitted',
          'confirmed',
          'placed',
          'processing',
          'ready_for_pickup',
          'shipped',
          'delivered',
          'returned',
          'payment_received'
        )
        else o.status::text = p_status
      end
    )
    and (
      p_search is null
      or o.order_no ilike ('%' || p_search || '%')
      or o.recipient_name ilike ('%' || p_search || '%')
      or o.recipient_phone ilike ('%' || p_search || '%')
      or o.courier_awb_number ilike ('%' || p_search || '%')
      or o.courier_name ilike ('%' || p_search || '%')
      or cs.name ilike ('%' || p_search || '%')
      or cg.name ilike ('%' || p_search || '%')
      or o.created_by_email ilike ('%' || p_search || '%')
    )
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;

grant execute on function public.list_dropship_shop_orders_for_staff(bigint, integer, integer, text, text) to authenticated;

commit;
