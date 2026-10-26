-- Migration: Fix middle_man_payout_ledger balance_after null from SELECT INTO with 0 rows
-- PG9+: SELECT INTO with no matching rows assigns NULL (overwriting := 0).
-- Also fix advance re-post member id (uuid → bigint) and mark_dropship_order_returned member resolve.
begin;

-- ---------------------------------------------------------------------------
-- 1. create_dual_invoice_from_dropship_order — scalar subquery for prior balance
-- ---------------------------------------------------------------------------
create or replace function public.create_dual_invoice_from_dropship_order(
  p_order_id bigint,
  p_invoice_no text default null,
  p_billing_profile_id bigint default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_billing_profile_id bigint;
  v_profile record;
  v_parent_tenant_id bigint;
  v_invoice_no text;
  v_invoice record;
  v_item record;
  v_face_subtotal numeric(12,2) := 0;
  v_accounting_subtotal numeric(12,2) := 0;
  v_middle_man_payout numeric(12,2) := 0;
  v_charges_total numeric(12,2) := 0;
  v_item_recipient_price numeric(12,2);
  v_item_sell_price numeric(12,2);
  v_item_face_line numeric(12,2);
  v_item_acct_line numeric(12,2);
  v_courier_cod_fee numeric(12,2) := 0;
  v_courier record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order is not a dropship order';
  end if;

  if v_order.status not in ('ready_for_pickup', 'shipped', 'delivered', 'payment_received') then
    raise exception 'Dual invoice can only be created for orders ready for pickup or later (current status: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is not null then
    raise exception 'Dual invoice already created for this order (invoice_id: %)', v_order.global_invoice_id;
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

  v_billing_profile_id := coalesce(p_billing_profile_id, v_order.billing_profile_id);
  if v_billing_profile_id is null then
    select id into v_billing_profile_id
    from public.billing_profiles
    where tenant_id = v_order.tenant_id
      and (customer_group_id = v_order.customer_group_id or is_default = true)
    order by is_default desc, created_at asc
    limit 1;
  end if;

  if v_billing_profile_id is null then
    raise exception 'Billing profile is required for creating dual invoice';
  end if;

  select * into v_profile from public.billing_profiles where id = v_billing_profile_id;
  if v_profile.id is null then
    raise exception 'Billing profile not found';
  end if;

  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := 'INV-DS-' || v_order.order_no;
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  insert into public.global_invoices (
    tenant_id,
    parent_tenant_id,
    invoice_no,
    invoice_type,
    billing_profile_id,
    recipient_profile_id,
    recipient_name,
    recipient_phone,
    recipient_address,
    collection_source,
    note,
    due_amount,
    invoice_status
  )
  values (
    v_order.tenant_id,
    v_parent_tenant_id,
    v_invoice_no,
    'dropship',
    v_billing_profile_id,
    v_order.recipient_profile_id,
    coalesce(v_order.recipient_name, v_order.name),
    v_order.recipient_phone,
    v_order.shipping_address,
    case when v_order.is_prepaid_snapshot then 'billing_profile'::public.collection_source_type else 'recipient'::public.collection_source_type end,
    coalesce(p_note, 'Dual invoice created from dropship order #' || v_order.order_no),
    0,
    'posted'::public.global_invoice_status
  )
  returning * into v_invoice;

  for v_item in (
    select
      soi.*,
      gs.shipment_item_id as stock_shipment_item_id,
      coalesce(public.calculate_landed_unit_cost(gs.shipment_item_id), 0) as stock_cost,
      gsi.name as stock_name,
      gsi.barcode as stock_barcode,
      gsi.product_code as stock_product_code
    from public.shop_order_items soi
    left join public.global_stocks gs on gs.id = soi.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where soi.order_id = v_order.id
  ) loop
    v_item_recipient_price := coalesce(v_item.customer_sell_price_amount, v_item.final_price_amount, v_item.unit_sell_price_amount, 0);
    v_item_sell_price := coalesce(v_item.unit_sell_price_amount, v_item.final_price_amount, 0);

    v_item_face_line := v_item.quantity * v_item_recipient_price;
    v_item_acct_line := v_item.quantity * v_item_sell_price;

    insert into public.global_invoice_items (
      tenant_id,
      parent_tenant_id,
      invoice_id,
      global_stock_id,
      shipment_item_id,
      product_id,
      name_snapshot,
      barcode_snapshot,
      product_code_snapshot,
      quantity,
      unit_cost_price,
      sell_price_amount,
      recipient_price_amount,
      line_discount_amount,
      line_total_amount,
      line_face_total_amount
    )
    values (
      v_invoice.tenant_id,
      v_invoice.parent_tenant_id,
      v_invoice.id,
      v_item.global_stock_id,
      v_item.stock_shipment_item_id,
      v_item.product_id,
      coalesce(v_item.stock_name, v_item.name),
      v_item.stock_barcode,
      v_item.stock_product_code,
      v_item.quantity,
      coalesce(v_item.stock_cost, 0),
      v_item_sell_price,
      v_item_recipient_price,
      0,
      v_item_acct_line,
      v_item_face_line
    );

    v_face_subtotal := v_face_subtotal + v_item_face_line;
    v_accounting_subtotal := v_accounting_subtotal + v_item_acct_line;

    update public.shop_order_items
    set delivered_quantity = quantity,
        updated_at = now()
    where id = v_item.id;
  end loop;

  if coalesce(v_order.cod_collect_amount, 0) > 0 and v_order.courier_service_id is not null then
    select * into v_courier from public.courier_services where id = v_order.courier_service_id;
    if v_courier.id is not null then
      if v_courier.cod_fee_mode = 'percent_of_collect' then
        v_courier_cod_fee := round((coalesce(v_order.cod_collect_amount, 0) * coalesce(v_courier.cod_fee_percent, 0.00) / 100.00), 2);
      elsif v_courier.cod_fee_mode = 'flat' then
        v_courier_cod_fee := coalesce(v_courier.cod_fee_flat_amount, 0.00);
      end if;
    end if;
  end if;

  v_charges_total := coalesce(v_order.delivery_charge_amount, 0) +
                     coalesce(v_order.cod_charge_amount, 0) +
                     coalesce(v_order.print_charge_amount, 0) +
                     coalesce(v_order.packing_charge_amount, 0) +
                     coalesce(v_courier_cod_fee, 0);

  v_middle_man_payout := greatest(v_face_subtotal - v_accounting_subtotal, 0);

  update public.global_invoices
  set
    subtotal_amount = v_accounting_subtotal,
    accounting_subtotal_amount = v_accounting_subtotal,
    face_subtotal_amount = v_face_subtotal,
    shipping_charge = coalesce(v_order.delivery_charge_amount, 0),
    cod_charge = coalesce(v_order.cod_charge_amount, 0) + coalesce(v_courier_cod_fee, 0),
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    total_amount = v_face_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0),
    due_amount = v_face_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0),
    middle_man_payout_amount = v_middle_man_payout,
    updated_at = now()
  where id = v_invoice.id;

  update public.shop_orders
  set
    global_invoice_id = v_invoice.id,
    updated_at = now()
  where id = v_order.id;

  if v_order.customer_group_id is not null and v_middle_man_payout > 0 then
    declare
      v_member_id bigint;
      v_prev_bal numeric := 0;
    begin
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
          v_order.tenant_id,
          v_member_id,
          v_order.id,
          v_invoice.id,
          'profit_credit',
          v_middle_man_payout,
          coalesce(v_prev_bal, 0.00) + coalesce(v_middle_man_payout, 0.00),
          'Profit credit from dual invoice #' || v_invoice_no
        );
      end if;
    end;
  end if;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice_no,
    'face_subtotal', v_face_subtotal,
    'accounting_subtotal', v_accounting_subtotal,
    'middle_man_payout_amount', v_middle_man_payout
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. advance_dropship_order_status — bigint member + balance subquery
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
  v_current_status public.shop_order_status;
  v_shop_type public.shop_type_enum;
  v_is_valid boolean := false;
  v_global_invoice_id bigint;
  v_invoice record;
  v_order record;
begin
  select status, shop_type_snapshot, global_invoice_id into v_current_status, v_shop_type, v_global_invoice_id
  from public.shop_orders where id = p_order_id;

  if not found then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
    if p_target_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received', 'cancelled') then
      v_is_valid := true;
    end if;
  end if;

  if not v_is_valid then
    return jsonb_build_object(
      'success', false,
      'error', format('Invalid status transition for dropship order from %s to %s', v_current_status, p_target_status)
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

  if p_target_status in ('ready_for_pickup', 'shipped', 'delivered', 'payment_received') then
    if v_order.global_invoice_id is null then
      perform public.create_dual_invoice_from_dropship_order(p_order_id);
    else
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'draft'::public.global_invoice_status then
        perform public.post_global_invoice(v_order.global_invoice_id);

        if v_order.customer_group_id is not null and v_invoice.middle_man_payout_amount > 0 then
          declare
            v_member_id bigint;
            v_prev_bal numeric := 0;
          begin
            select id into v_member_id
            from public.customer_group_members
            where customer_group_id = v_order.customer_group_id
              and is_active = true
            order by created_at asc
            limit 1;

            if v_member_id is not null then
              if not exists (
                select 1 from public.middle_man_payout_ledger
                where global_invoice_id = v_order.global_invoice_id and entry_type = 'profit_credit'
              ) then
                v_prev_bal := coalesce((
                  select balance_after
                  from public.middle_man_payout_ledger
                  where tenant_id = v_order.tenant_id
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
                  v_order.tenant_id,
                  v_member_id,
                  v_order.id,
                  v_order.global_invoice_id,
                  'profit_credit',
                  v_invoice.middle_man_payout_amount,
                  coalesce(v_prev_bal, 0.00) + coalesce(v_invoice.middle_man_payout_amount, 0.00),
                  'Profit credit from dual invoice #' || v_invoice.invoice_no
                );
              end if;
            end if;
          end;
        end if;
      end if;
    end if;
  elsif p_target_status = 'processing' then
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'posted'::public.global_invoice_status then
        perform public.unpost_global_invoice(v_order.global_invoice_id);
      end if;

      delete from public.middle_man_payout_ledger
      where global_invoice_id = v_order.global_invoice_id
        and entry_type = 'profit_credit';
    end if;
  end if;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. mark_dropship_order_returned — resolve member via customer_group_id
-- ---------------------------------------------------------------------------
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
  v_tenant_id bigint;
  v_customer_group_id bigint;
  v_customer_group_member_id bigint;
  v_global_invoice_id bigint;
  v_prev_balance numeric := 0.00;
  v_new_balance numeric;
begin
  select tenant_id, customer_group_id, global_invoice_id
  into v_tenant_id, v_customer_group_id, v_global_invoice_id
  from public.shop_orders where id = p_order_id;

  if not found then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  update public.shop_orders
  set
    status = 'returned',
    returned_at = now(),
    return_charge_amount = p_actual_return_charge,
    deduct_return_charge_from_middle_man = p_deduct_from_middle_man
  where id = p_order_id;

  if v_global_invoice_id is null and p_deduct_from_middle_man and p_actual_return_charge > 0 then
    select id into v_customer_group_member_id
    from public.customer_group_members
    where customer_group_id = v_customer_group_id
      and is_active = true
    order by created_at asc
    limit 1;

    if v_customer_group_member_id is not null then
      v_prev_balance := coalesce((
        select balance_after
        from public.middle_man_payout_ledger
        where tenant_id = v_tenant_id
          and customer_group_member_id = v_customer_group_member_id
        order by created_at desc
        limit 1
      ), 0.00);

      v_new_balance := coalesce(v_prev_balance, 0.00) - coalesce(p_actual_return_charge, 0.00);

      insert into public.middle_man_payout_ledger (
        tenant_id, customer_group_member_id, shop_order_id, entry_type, amount, balance_after, reference_notes
      ) values (
        v_tenant_id,
        v_customer_group_member_id,
        p_order_id,
        'return_fee_uninvoiced',
        -p_actual_return_charge,
        v_new_balance,
        coalesce(p_reason, 'Failed delivery return fee')
      );
    end if;
  end if;

  return jsonb_build_object('success', true);
end;
$$;

commit;
