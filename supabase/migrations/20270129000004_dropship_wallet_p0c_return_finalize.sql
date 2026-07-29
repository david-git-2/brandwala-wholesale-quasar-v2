-- Migration: Dropship Wallet P0C — Return Finalization + Stock Restock + UWL Reversals
-- Goal: One atomic return finalization with condition-based restock, idempotent return_ref, and desk mark_dropship_order_returned wrapper.

begin;

-- ============================================================================
-- 1. Extend shop_orders schema for return sub-state & audit tracking
-- ============================================================================
alter table public.shop_orders
  add column if not exists return_sub_state text check (return_sub_state in ('return_requested', 'return_finalized')),
  add column if not exists return_override_reason text,
  add column if not exists return_ref text;

create unique index if not exists idx_shop_orders_tenant_return_ref
  on public.shop_orders(tenant_id, return_ref)
  where return_ref is not null;

-- ============================================================================
-- 2. Core RPC: finalize_dropship_return
-- ============================================================================
create or replace function public.finalize_dropship_return(
  p_order_id bigint,
  p_items jsonb,
  p_actual_return_charge numeric default 0.00,
  p_deduct_from_middle_man boolean default true,
  p_override_reason text default null,
  p_return_ref text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_invoice record;
  v_parent_tenant_id bigint;
  v_ref text;
  v_item_elem jsonb;
  v_order_item_id bigint;
  v_returned_qty numeric;
  v_condition text;
  v_order_item record;
  v_invoice_item record;
  v_stock record;
  v_target_stock_type_id bigint;
  v_target_stock_id bigint;
  v_net_delivered numeric;
  v_unit_face numeric(12,2);
  v_unit_acct numeric(12,2);
  v_return_face numeric(12,2);
  v_return_acct numeric(12,2);
  v_currency text;
  v_billing_profile_id bigint;
  v_member_id bigint;
  v_prev_bal numeric(12,2);
  v_is_remitted boolean := false;
  v_existing_ref_order_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order #% is not a dropship order', p_order_id;
  end if;

  v_currency := 'BDT';
  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  -- Check permissions
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

  -- Idempotency check on p_return_ref
  v_ref := nullif(trim(coalesce(p_return_ref, '')), '');
  if v_ref is not null then
    select id into v_existing_ref_order_id
    from public.shop_orders
    where tenant_id = v_order.tenant_id
      and return_ref = v_ref;

    if v_existing_ref_order_id is not null then
      if v_existing_ref_order_id = p_order_id and v_order.return_sub_state = 'return_finalized' then
        return jsonb_build_object(
          'success', true,
          'idempotent', true,
          'message', 'Return already finalized with reference ' || v_ref,
          'order_id', p_order_id
        );
      else
        raise exception 'Duplicate return reference % already used for another return', v_ref;
      end if;
    end if;
  end if;

  if v_order.return_sub_state = 'return_finalized' then
    return jsonb_build_object(
      'success', true,
      'idempotent', true,
      'message', 'Order return is already finalized',
      'order_id', p_order_id
    );
  end if;

  -- Lock invoice if present
  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id for update;
  end if;

  -- Resolve billing profile
  v_billing_profile_id := v_order.billing_profile_id;
  if v_billing_profile_id is null and v_order.customer_group_id is not null then
    select id into v_billing_profile_id
    from public.billing_profiles
    where tenant_id = v_order.tenant_id
      and customer_group_id = v_order.customer_group_id
    order by is_default desc, created_at asc
    limit 1;
  end if;

  -- Process returned items JSON array
  if p_items is not null and jsonb_array_length(p_items) > 0 then
    for v_item_elem in select * from jsonb_array_elements(p_items) loop
      v_order_item_id := (v_item_elem->>'order_item_id')::bigint;
      v_returned_qty := coalesce((v_item_elem->>'returned_qty')::numeric, 0);
      v_condition := coalesce(lower(trim(v_item_elem->>'condition')), 'perfect');

      if v_returned_qty <= 0 then
        continue;
      end if;

      select * into v_order_item
      from public.shop_order_items
      where id = v_order_item_id and order_id = p_order_id for update;

      if v_order_item.id is null then
        raise exception 'Order item #% not found on order #%', v_order_item_id, p_order_id;
      end if;

      v_net_delivered := coalesce(v_order_item.delivered_quantity, v_order_item.quantity) - coalesce(v_order_item.returned_quantity, 0);
      if v_returned_qty > v_net_delivered then
        raise exception 'Returned quantity % exceeds net delivered quantity % for item #%', v_returned_qty, v_net_delivered, v_order_item_id;
      end if;

      -- Map condition to tenant stock_type_id
      select * into v_stock from public.global_stocks where id = v_order_item.global_stock_id;

      if v_stock.id is not null then
        if v_condition = 'open_box' then
          select id into v_target_stock_type_id
          from public.global_stock_types
          where (parent_tenant_id = v_parent_tenant_id or parent_tenant_id is null)
            and (description ilike '%Box Less%' or description ilike '%Boxless%')
          order by parent_tenant_id nulls last
          limit 1;
        elsif v_condition = 'damaged' then
          select id into v_target_stock_type_id
          from public.global_stock_types
          where (parent_tenant_id = v_parent_tenant_id or parent_tenant_id is null)
            and (description ilike '%Box Damage%' or description ilike '%Damage%')
          order by parent_tenant_id nulls last
          limit 1;
        end if;

        -- Fallback to sellable stock type
        if v_target_stock_type_id is null then
          select id into v_target_stock_type_id
          from public.global_stock_types
          where (parent_tenant_id = v_parent_tenant_id or parent_tenant_id is null)
            and (description ilike '%Standard%' or description ilike '%Sellable%')
          order by parent_tenant_id nulls last
          limit 1;
        end if;

        -- Find or create target global_stock record for condition stock type
        select id into v_target_stock_id
        from public.global_stocks
        where parent_tenant_id = v_stock.parent_tenant_id
          and shipment_item_id = v_stock.shipment_item_id
          and stock_type_id = v_target_stock_type_id
          and is_usable = true;

        if v_target_stock_id is null then
          insert into public.global_stocks (parent_tenant_id, shipment_item_id, stock_type_id, quantity, is_usable)
          values (v_stock.parent_tenant_id, v_stock.shipment_item_id, v_target_stock_type_id, 0, true)
          returning id into v_target_stock_id;
        end if;

        -- Restock target stock
        update public.global_stocks
        set quantity = quantity + ceil(v_returned_qty)::integer, updated_at = now()
        where id = v_target_stock_id;

        -- Bump stock allocation for child tenant if allocation exists
        if exists (
          select 1 from public.global_stock_allocations
          where child_tenant_id = v_order.tenant_id and stock_id = v_target_stock_id
        ) then
          update public.global_stock_allocations
          set quantity = quantity + ceil(v_returned_qty)::integer, updated_at = now()
          where child_tenant_id = v_order.tenant_id and stock_id = v_target_stock_id;
        elsif exists (
          select 1 from public.global_stock_allocations
          where child_tenant_id = v_order.tenant_id and stock_id = v_stock.id
        ) then
          -- Insert allocation row for target condition stock if primary stock allocation exists
          insert into public.global_stock_allocations (parent_tenant_id, child_tenant_id, stock_id, quantity)
          values (v_parent_tenant_id, v_order.tenant_id, v_target_stock_id, ceil(v_returned_qty)::integer)
          on conflict (child_tenant_id, stock_id)
          do update set quantity = public.global_stock_allocations.quantity + ceil(v_returned_qty)::integer, updated_at = now();
        end if;
      end if;

      -- Update shop_order_items returned quantity
      update public.shop_order_items
      set returned_quantity = coalesce(returned_quantity, 0) + v_returned_qty, updated_at = now()
      where id = v_order_item_id;

      -- If global_invoice exists, insert global_return_items row and update invoice_items
      if v_invoice.id is not null then
        select * into v_invoice_item
        from public.global_invoice_items
        where invoice_id = v_invoice.id
          and (global_stock_id = v_order_item.global_stock_id or product_id = v_order_item.product_id)
        limit 1;

        if v_invoice_item.id is not null then
          v_unit_acct := coalesce(v_invoice_item.sell_price_amount, 0.00);
          v_unit_face := coalesce(v_order_item.customer_sell_price_amount, v_unit_acct);

          v_return_acct := round(v_unit_acct * v_returned_qty, 2);
          v_return_face := round(v_unit_face * v_returned_qty, 2);

          insert into public.global_return_items (
            tenant_id, parent_tenant_id, invoice_id, invoice_item_id, global_stock_id,
            quantity, return_amount, return_face_amount, return_accounting_amount, return_charge_amount, note
          )
          values (
            v_invoice.tenant_id, v_invoice.parent_tenant_id, v_invoice.id, v_invoice_item.id, v_order_item.global_stock_id,
            v_returned_qty, v_return_face, v_return_face, v_return_acct, 0.00, coalesce(p_override_reason, 'Dropship return finalization')
          );

          update public.global_invoice_items
          set return_quantity = coalesce(return_quantity, 0) + v_returned_qty, updated_at = now()
          where id = v_invoice_item.id;
        end if;
      end if;
    end loop;
  end if;

  -- Recompute invoice totals if invoice exists
  if v_invoice.id is not null then
    perform public.recompute_global_invoice_totals(v_invoice.id);
  end if;

  -- UWL Compensating Reversals
  select exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) into v_is_remitted;

  -- Leg 1: Reverse invoice_billed debit if present
  if v_billing_profile_id is not null then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_billing_profile_id,
      p_type => 'credit',
      p_amount => coalesce(v_invoice.total_amount, 0.00),
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'receivable',
        'transaction_type', 'return_reversal',
        'label', 'Return Billed Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  end if;

  -- Leg 2: Reverse dropship_profit credit to middleman if present
  if v_billing_profile_id is not null then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'middleman',
      p_entity_id => v_billing_profile_id,
      p_type => 'debit',
      p_amount => coalesce(v_invoice.middle_man_payout_amount, 0.00),
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payout_earned',
        'transaction_type', 'return_profit_clawback',
        'label', 'Return Profit Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  end if;

  -- Leg 3: Reverse tenant revenue credit
  perform public.record_ledger_transaction(
    p_tenant_id => v_order.tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_order.tenant_id,
    p_type => 'debit',
    p_amount => coalesce(v_invoice.total_amount, 0.00) - coalesce(v_invoice.middle_man_payout_amount, 0.00),
    p_currency_code => v_currency,
    p_exchange_rate => 1.000000,
    p_source_type => 'shop_order',
    p_source_id => p_order_id::text,
    p_metadata => jsonb_build_object(
      'section', 'revenue',
      'transaction_type', 'return_revenue_reversal',
      'label', 'Return Revenue Reversal',
      'order_no', v_order.order_no,
      'return_ref', v_ref
    )
  );

  -- Leg 4: If remitted, reverse courier remittance legs
  if v_is_remitted then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_order.tenant_id,
      p_type => 'debit',
      p_amount => coalesce(v_order.cod_collect_amount, 0.00),
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'purpose', 'remittance_return_reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  end if;

  -- Handle actual return fee deduction from middleman in middle_man_payout_ledger if requested
  if p_deduct_from_middle_man and p_actual_return_charge > 0 and v_order.customer_group_id is not null then
    select id into v_member_id
    from public.customer_group_members
    where customer_group_id = v_order.customer_group_id
      and is_active = true
    order by created_at asc
    limit 1;

    if v_member_id is not null then
      v_prev_bal := coalesce((
        select balance_after
        from public.middle_man_payout_ledger
        where tenant_id = v_order.tenant_id
          and customer_group_member_id = v_member_id
        order by created_at desc
        limit 1
      ), 0.00);

      insert into public.middle_man_payout_ledger (
        tenant_id, customer_group_member_id, shop_order_id, global_invoice_id, entry_type, amount, balance_after, reference_notes
      ) values (
        v_order.tenant_id,
        v_member_id,
        p_order_id,
        v_order.global_invoice_id,
        case when v_order.global_invoice_id is not null then 'return_fee_invoiced' else 'return_fee_uninvoiced' end,
        -p_actual_return_charge,
        v_prev_bal - p_actual_return_charge,
        coalesce(p_override_reason, 'Return finalization charge')
      );
    end if;
  end if;

  -- Update order sub-state & status
  update public.shop_orders
  set
    status = 'returned'::public.shop_order_status,
    return_sub_state = 'return_finalized',
    returned_at = coalesce(returned_at, now()),
    return_charge_amount = p_actual_return_charge,
    deduct_return_charge_from_middle_man = p_deduct_from_middle_man,
    return_override_reason = coalesce(p_override_reason, return_override_reason),
    return_ref = v_ref,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'status', 'returned',
    'return_sub_state', 'return_finalized',
    'return_ref', v_ref
  );
end;
$$;

grant execute on function public.finalize_dropship_return(bigint, jsonb, numeric, boolean, text, text) to authenticated;
grant execute on function public.finalize_dropship_return(bigint, jsonb, numeric, boolean, text, text) to service_role;


-- ============================================================================
-- 3. Wrapper RPC: mark_dropship_order_returned (Legacy Drop R2)
-- ============================================================================
create or replace function public.mark_dropship_order_returned(
  p_order_id bigint,
  p_actual_return_charge numeric,
  p_deduct_from_middle_man boolean,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_items jsonb;
begin
  -- Build default full return payload for all items in perfect condition
  select jsonb_agg(
    jsonb_build_object(
      'order_item_id', id,
      'returned_qty', greatest(coalesce(delivered_quantity, quantity) - coalesce(returned_quantity, 0), 0),
      'condition', 'perfect'
    )
  )
  into v_items
  from public.shop_order_items
  where order_id = p_order_id;

  return public.finalize_dropship_return(
    p_order_id => p_order_id,
    p_items => coalesce(v_items, '[]'::jsonb),
    p_actual_return_charge => coalesce(p_actual_return_charge, 0.00),
    p_deduct_from_middle_man => coalesce(p_deduct_from_middle_man, true),
    p_override_reason => p_reason,
    p_return_ref => 'AUTO-RET-' || p_order_id::text || '-' || extract(epoch from now())::bigint
  );
end;
$$;

grant execute on function public.mark_dropship_order_returned(bigint, numeric, boolean, text) to authenticated;
grant execute on function public.mark_dropship_order_returned(bigint, numeric, boolean, text) to service_role;

commit;
