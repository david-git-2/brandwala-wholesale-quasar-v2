-- Fix 22P02 on mark_dropship_order_delivered: wallet source_id must be shop_orders.id (text), never invoice_no.
-- Frontend sends p_order_id correctly; legacy ensure/post paths stored INV-DS-* in universal_wallet_ledger.source_id.

begin;

-- ---------------------------------------------------------------------------
-- 1. Backfill all legacy INV-DS-* / invoice_no wallet source_ids
-- ---------------------------------------------------------------------------

update public.universal_wallet_ledger u
set
  source_id = o.id::text,
  metadata = coalesce(u.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'order_id', o.id,
      'invoice_no', u.source_id
    )
from public.shop_orders o
where u.source_type = 'shop_order'
  and u.source_id = 'INV-DS-' || o.order_no
  and o.shop_type_snapshot = 'dropship';

update public.universal_wallet_ledger u
set
  source_id = o.id::text,
  metadata = coalesce(u.metadata, '{}'::jsonb)
    || jsonb_build_object('order_id', o.id, 'invoice_id', i.id, 'invoice_no', i.invoice_no)
from public.shop_orders o
join public.global_invoices i on i.id = o.global_invoice_id
where u.source_type = 'shop_order'
  and u.source_id = i.invoice_no
  and o.shop_type_snapshot = 'dropship';

update public.universal_wallet_ledger u
set
  source_id = o.id::text,
  metadata = coalesce(u.metadata, '{}'::jsonb) || jsonb_build_object('order_id', o.id)
from public.shop_orders o
join public.global_invoices i on i.invoice_no = 'INV-DS-' || o.order_no and i.tenant_id = o.tenant_id
where u.source_type = 'shop_order'
  and u.source_id = i.invoice_no
  and o.shop_type_snapshot = 'dropship'
  and i.invoice_type = 'dropship'::public.global_invoice_type;

-- Link orphan dropship invoices from failed partial deliver attempts
update public.shop_orders o
set global_invoice_id = i.id, updated_at = now()
from public.global_invoices i
where o.global_invoice_id is null
  and o.shop_type_snapshot = 'dropship'
  and i.invoice_type = 'dropship'::public.global_invoice_type
  and i.tenant_id = o.tenant_id
  and i.invoice_no = 'INV-DS-' || o.order_no
  and not exists (
    select 1 from public.shop_orders o2
    where o2.global_invoice_id = i.id and o2.id <> o.id
  );

-- ---------------------------------------------------------------------------
-- 2. Per-order canonicalization helper (called from mark / ensure / create_dual)
-- ---------------------------------------------------------------------------
create or replace function public.canonicalize_dropship_order_wallet_source_ids(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice_no text;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null or v_order.shop_type_snapshot <> 'dropship' then
    return;
  end if;

  v_invoice_no := 'INV-DS-' || v_order.order_no;

  update public.universal_wallet_ledger u
  set
    source_id = p_order_id::text,
    metadata = coalesce(u.metadata, '{}'::jsonb)
      || jsonb_build_object('order_id', p_order_id, 'invoice_no', v_invoice_no)
  where u.source_type = 'shop_order'
    and u.tenant_id = v_order.tenant_id
    and u.source_id in (v_invoice_no, v_order.order_no);

  if v_order.global_invoice_id is not null then
    update public.universal_wallet_ledger u
    set
      source_id = p_order_id::text,
      metadata = coalesce(u.metadata, '{}'::jsonb)
        || jsonb_build_object(
          'order_id', p_order_id,
          'invoice_id', v_order.global_invoice_id
        )
    from public.global_invoices i
    where i.id = v_order.global_invoice_id
      and u.source_type = 'shop_order'
      and u.tenant_id = v_order.tenant_id
      and u.source_id = i.invoice_no;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. ensure_dropship_invoice_billed_entry — order id only in source_id
-- ---------------------------------------------------------------------------
create or replace function public.ensure_dropship_invoice_billed_entry(p_invoice_id bigint)
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

  perform public.canonicalize_dropship_order_wallet_source_ids(v_order_id);

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
-- 4. create_dual_invoice_from_dropship_order — drop orphan invoice before recreate
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
  v_invoice public.global_invoices;
  v_orphan_invoice_id bigint;
  v_item record;
  v_subtotal numeric(12,2) := 0;
  v_charges_total numeric(12,2) := 0;
  v_item_sell_price numeric(12,2);
  v_item_line_total numeric(12,2);
  v_assigned_child bigint;
  v_total numeric(12,2);
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order is not a dropship order';
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    raise exception 'Tenant B2B invoice can only be created at delivered (current status: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is not null then
    raise exception 'Invoice already created for this order (invoice_id: %)', v_order.global_invoice_id;
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);

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
      and customer_group_id = v_order.customer_group_id
    order by created_at asc
    limit 1;
  end if;

  if v_billing_profile_id is null then
    raise exception 'Billing profile is required for creating invoice';
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

  -- Remove unlinked orphan invoice from a rolled-back deliver attempt
  select i.id into v_orphan_invoice_id
  from public.global_invoices i
  where i.tenant_id = v_order.tenant_id
    and i.invoice_no = v_invoice_no
    and i.invoice_type = 'dropship'::public.global_invoice_type
    and not exists (
      select 1 from public.shop_orders o2 where o2.global_invoice_id = i.id
    )
  limit 1;

  if v_orphan_invoice_id is not null then
    delete from public.global_return_items where invoice_id = v_orphan_invoice_id;
    delete from public.global_invoice_items where invoice_id = v_orphan_invoice_id;
    delete from public.global_invoices where id = v_orphan_invoice_id;
  end if;

  select * into v_invoice from public.create_global_invoice(
    p_tenant_id => v_order.tenant_id,
    p_invoice_no => v_invoice_no,
    p_invoice_type => 'dropship'::public.global_invoice_type,
    p_billing_profile_id => v_billing_profile_id,
    p_recipient_profile_id => v_order.recipient_profile_id,
    p_recipient_name => coalesce(v_order.recipient_name, v_order.name),
    p_recipient_phone => v_order.recipient_phone,
    p_recipient_address => v_order.shipping_address,
    p_note => coalesce(p_note, 'B2B Wholesale invoice created from dropship order #' || v_order.order_no)
  );

  for v_item in (
    select
      soi.*,
      gs.shipment_item_id as stock_shipment_item_id,
      coalesce(public.calculate_landed_unit_cost(gs.shipment_item_id), 0) as stock_cost,
      gsi.name as stock_name,
      gsi.barcode as stock_barcode,
      gsi.product_code as stock_product_code,
      sh.assigned_child_tenant_id as stock_assigned_child
    from public.shop_order_items soi
    left join public.global_stocks gs on gs.id = soi.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    where soi.order_id = v_order.id
  ) loop
    v_item_sell_price := coalesce(v_item.unit_sell_price_amount, v_item.final_price_amount, 0);
    v_item_line_total := v_item.quantity * v_item_sell_price;
    v_assigned_child := v_item.stock_assigned_child;

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
      line_discount_amount,
      line_total_amount,
      assigned_child_tenant_id
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
      0,
      v_item_line_total,
      v_assigned_child
    );

    v_subtotal := v_subtotal + v_item_line_total;
  end loop;

  v_charges_total := coalesce(v_order.print_charge_amount, 0) + coalesce(v_order.packing_charge_amount, 0);
  v_total := greatest(v_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0), 0);

  update public.global_invoices
  set
    subtotal_amount = v_subtotal,
    shipping_charge = 0,
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    total_amount = v_total,
    paid_amount = 0,
    due_amount = v_total,
    payment_status = 'due',
    collection_source = case
      when coalesce(v_order.is_prepaid_snapshot, false) then 'billing_profile'::public.collection_source_type
      else 'recipient'::public.collection_source_type
    end,
    invoice_status = 'issued'::public.global_invoice_status,
    updated_at = now()
  where id = v_invoice.id;

  update public.shop_orders
  set global_invoice_id = v_invoice.id, updated_at = now()
  where id = v_order.id;

  perform public.ensure_dropship_invoice_billed_entry(v_invoice.id);

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice_no,
    'invoice_status', 'issued',
    'payment_status', 'due',
    'subtotal_amount', v_subtotal,
    'total_amount', v_total
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. mark_dropship_order_delivered — canonicalize wallet source_ids before invoice step
-- ---------------------------------------------------------------------------
create or replace function public.mark_dropship_order_delivered(
  p_tenant_id bigint,
  p_order_id bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_save jsonb;
  v_advance jsonb;
  v_invoice jsonb;
  v_costing jsonb;
  v_delivery_amount numeric(15,2);
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id for update;

  if not found then raise exception 'order not found'; end if;
  if v_order.status <> 'shipped' then
    raise exception 'mark as delivered requires shipped status (current: %)', v_order.status;
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

  v_advance := public.advance_dropship_order_status(p_order_id, 'delivered'::public.shop_order_status);
  if coalesce(v_advance->>'success', 'false') <> 'true' then
    return v_advance;
  end if;

  v_invoice := public.ensure_dropship_tenant_b2b_invoice_at_delivered(p_order_id);
  if coalesce(v_invoice->>'success', 'false') <> 'true' then
    return v_invoice;
  end if;

  select coalesce(cl.amount, 0) into v_delivery_amount
  from public.dropship_order_settlements s
  join public.dropship_settlement_charge_lines cl
    on cl.settlement_id = s.id and cl.charge_type = 'delivery'
  where s.shop_order_id = p_order_id;

  v_costing := public.confirm_dropship_delivered_costing(
    p_order_id,
    coalesce((p_payload->>'collected_cod_amount')::numeric, 0),
    v_delivery_amount,
    null
  );

  if coalesce(v_costing->>'success', 'false') <> 'true' then
    return v_costing;
  end if;

  update public.dropship_order_settlements
  set courier_cod_booked_at = now(), updated_at = now()
  where shop_order_id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Order marked as delivered',
    'order_id', p_order_id,
    'invoice', v_invoice
  );
end;
$$;

grant execute on function public.canonicalize_dropship_order_wallet_source_ids(bigint) to authenticated;
grant execute on function public.mark_dropship_order_delivered(bigint, bigint, jsonb) to authenticated;

commit;
