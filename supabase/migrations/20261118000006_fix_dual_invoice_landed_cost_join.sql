-- Migration: Fix create_dual_invoice_from_dropship_order to use landed cost + shipment item snapshots
-- global_stocks no longer has cost/name/barcode/product_code (see procurement stock rewrite).
-- invoice_charge_lines was dropped; fold courier COD fee into invoice cod_charge.
begin;

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

  -- Allow creation at ready_for_pickup, shipped, delivered, payment_received
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
      limit 1;

      if v_member_id is not null then
        select coalesce(balance_after, 0.00) into v_prev_bal
        from public.middle_man_payout_ledger
        where tenant_id = v_order.tenant_id and customer_group_member_id = v_member_id
        order by created_at desc limit 1;

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
          v_prev_bal + v_middle_man_payout,
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

commit;
