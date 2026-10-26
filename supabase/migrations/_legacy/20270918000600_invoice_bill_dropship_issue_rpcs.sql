-- Invoice bill redesign: one dropship issue path at ship; bill meta + internal cost snapshot.

begin;

-- ---------------------------------------------------------------------------
-- Helpers: item cost snapshot + header charges mirror
-- ---------------------------------------------------------------------------
create or replace function public.snapshot_sales_invoice_item_costs(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.sales_invoice_item_costs (invoice_item_id, unit_cost_price, costing_locked_at)
  select sii.id, sii.unit_cost_price, now()
  from public.sales_invoice_items sii
  where sii.invoice_id = p_invoice_id
  on conflict (invoice_item_id) do nothing;
end;
$$;

create or replace function public.sync_sales_invoice_charges_from_header(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv public.sales_invoices;
  v_total numeric(12,2) := 0;
begin
  select * into v_inv from public.sales_invoices where id = p_invoice_id;
  if not found then
    return;
  end if;

  delete from public.sales_invoice_charges where invoice_id = p_invoice_id;

  if coalesce(v_inv.shipping_charge, 0) > 0 then
    insert into public.sales_invoice_charges (invoice_id, parent_tenant_id, charge_type, amount)
    values (p_invoice_id, v_inv.parent_tenant_id, 'delivery', v_inv.shipping_charge);
    v_total := v_total + v_inv.shipping_charge;
  end if;

  if coalesce(v_inv.print_charge, 0) > 0 then
    insert into public.sales_invoice_charges (invoice_id, parent_tenant_id, charge_type, amount)
    values (p_invoice_id, v_inv.parent_tenant_id, 'print', v_inv.print_charge);
    v_total := v_total + v_inv.print_charge;
  end if;

  if coalesce(v_inv.wrapping_charge, 0) > 0 then
    insert into public.sales_invoice_charges (invoice_id, parent_tenant_id, charge_type, amount)
    values (p_invoice_id, v_inv.parent_tenant_id, 'packing', v_inv.wrapping_charge);
    v_total := v_total + v_inv.wrapping_charge;
  end if;

  if coalesce(v_inv.cod_charge_amount, 0) > 0 then
    insert into public.sales_invoice_charges (invoice_id, parent_tenant_id, charge_type, amount)
    values (p_invoice_id, v_inv.parent_tenant_id, 'cod', v_inv.cod_charge_amount);
    v_total := v_total + v_inv.cod_charge_amount;
  end if;

  update public.sales_invoices
  set charges_amount = v_total,
      updated_at = now()
  where id = p_invoice_id;
end;
$$;

grant execute on function public.snapshot_sales_invoice_item_costs(bigint) to authenticated;
grant execute on function public.sync_sales_invoice_charges_from_header(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- build_dropship_tenant_b2b_invoice_payload — issue at ready/shipped; channel/line meta
-- ---------------------------------------------------------------------------
create or replace function public.build_dropship_tenant_b2b_invoice_payload(
  p_order_id bigint,
  p_invoice_id bigint default null,
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
  v_order public.shop_orders;
  v_billing_profile_id bigint;
  v_invoice_no text;
  v_item record;
  v_items jsonb := '[]'::jsonb;
  v_item_json jsonb;
  v_item_sell_price numeric(12,2);
  v_resell_price numeric(12,2);
  v_unit_cost numeric(12,2);
  v_line_id bigint;
  v_collection_source public.collection_source_type;
  v_charges record;
  v_channel_meta jsonb;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.status not in (
    'ready_for_pickup'::public.shop_order_status,
    'shipped'::public.shop_order_status,
    'delivered'::public.shop_order_status,
    'payment_received'::public.shop_order_status
  ) then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'tenant B2B invoice requires ready_for_pickup, shipped, or delivered (current: %s)',
        v_order.status
      )
    );
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
    return jsonb_build_object('success', false, 'error', 'billing profile is required for creating invoice');
  end if;

  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := 'INV-DS-' || v_order.order_no;
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  v_collection_source := case
    when coalesce(v_order.is_prepaid_snapshot, false) then 'billing_profile'::public.collection_source_type
    else 'recipient'::public.collection_source_type
  end;

  v_channel_meta := jsonb_strip_nulls(jsonb_build_object(
    'cod_collect_amount', v_order.cod_collect_amount,
    'collection_source', v_collection_source::text,
    'recipient_name', coalesce(v_order.recipient_name, v_order.name),
    'recipient_phone', v_order.recipient_phone,
    'recipient_address', v_order.shipping_address
  ));

  select * into v_charges
  from public.get_dropship_merchant_billable_charges(p_order_id);

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
    v_resell_price := coalesce(
      v_item.customer_sell_price_amount,
      v_item.final_price_amount,
      v_item.unit_sell_price_amount,
      0
    );
    v_unit_cost := coalesce(v_item.stock_cost, 0);
    v_line_id := null;

    if p_invoice_id is not null then
      select sii.id into v_line_id
      from public.sales_invoice_items sii
      where sii.invoice_id = p_invoice_id
        and (
          (sii.global_stock_id is not null and sii.global_stock_id = v_item.global_stock_id)
          or (sii.global_stock_id is null and sii.product_id = v_item.product_id)
        )
      order by sii.id
      limit 1;
    end if;

    v_item_json := jsonb_strip_nulls(jsonb_build_object(
      'id', v_line_id,
      'global_stock_id', v_item.global_stock_id,
      'product_id', v_item.product_id,
      'shipment_item_id', v_item.stock_shipment_item_id,
      'name_snapshot', coalesce(v_item.stock_name, v_item.name),
      'barcode_snapshot', v_item.stock_barcode,
      'product_code_snapshot', v_item.stock_product_code,
      'quantity', v_item.quantity,
      'unit_cost_price', v_unit_cost,
      'sell_price_amount', v_item_sell_price,
      'line_discount_amount', 0,
      'assigned_child_tenant_id', v_item.stock_assigned_child,
      'line_meta', jsonb_build_object('resell_price_amount', v_resell_price)
    ));

    if v_line_id is null then
      v_item_json := v_item_json - 'id';
    end if;

    v_items := v_items || jsonb_build_array(v_item_json);
  end loop;

  return jsonb_build_object(
    'success', true,
    'payload', jsonb_build_object(
      'invoice', jsonb_strip_nulls(jsonb_build_object(
        'invoice_type', 'dropship',
        'invoice_no', v_invoice_no,
        'billing_profile_id', v_billing_profile_id,
        'recipient_profile_id', v_order.recipient_profile_id,
        'recipient_name', coalesce(v_order.recipient_name, v_order.name),
        'recipient_phone', v_order.recipient_phone,
        'recipient_address', v_order.shipping_address,
        'note', coalesce(p_note, 'Merchant bill from dropship order #' || v_order.order_no),
        'discount_amount', coalesce(v_order.discount_amount, 0),
        'shipping_charge', coalesce(v_charges.delivery, 0),
        'cod_charge_amount', coalesce(v_charges.cod, 0),
        'print_charge', coalesce(v_charges.print, 0),
        'wrapping_charge', coalesce(v_charges.packing, 0),
        'collection_source', v_collection_source,
        'channel_meta', v_channel_meta
      )),
      'items', v_items,
      'shop_order_id', p_order_id
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Thin wrappers → issue_dropship_tenant_b2b_invoice
-- ---------------------------------------------------------------------------
create or replace function public.create_dropship_invoice(
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
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shop_orders where id = p_order_id;
  if v_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;
  return public.issue_dropship_tenant_b2b_invoice(v_tenant_id, p_order_id);
end;
$$;

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
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shop_orders where id = p_order_id;
  if v_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;
  return public.issue_dropship_tenant_b2b_invoice(v_tenant_id, p_order_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- issue_dropship_tenant_b2b_invoice — idempotent; issue at ship
-- ---------------------------------------------------------------------------
create or replace function public.issue_dropship_tenant_b2b_invoice(
  p_tenant_id bigint,
  p_order_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_build jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_created boolean := false;
  v_courier_cod_booked boolean := false;
  v_orphan_invoice_id bigint;
  v_parent_tenant_id bigint;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.status not in (
    'ready_for_pickup'::public.shop_order_status,
    'shipped'::public.shop_order_status,
    'delivered'::public.shop_order_status,
    'payment_received'::public.shop_order_status
  ) then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'tenant B2B invoice requires ready_for_pickup, shipped, or delivered (current: %s)',
        v_order.status
      )
    );
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);
  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
    return jsonb_build_object(
      'success', true,
      'already_issued', true,
      'created', false,
      'order_id', p_order_id,
      'invoice', jsonb_build_object(
        'id', v_invoice.id,
        'invoice_no', v_invoice.invoice_no,
        'invoice_type', v_invoice.invoice_type,
        'invoice_status', v_invoice.invoice_status,
        'payment_status', v_invoice.payment_status,
        'subtotal_amount', v_invoice.subtotal_amount,
        'print_charge', v_invoice.print_charge,
        'wrapping_charge', v_invoice.wrapping_charge,
        'discount_amount', v_invoice.discount_amount,
        'total_amount', v_invoice.total_amount,
        'paid_amount', v_invoice.paid_amount,
        'due_amount', v_invoice.due_amount,
        'billing_profile_id', v_invoice.billing_profile_id,
        'collection_source', v_invoice.collection_source
      )
    );
  end if;

  v_build := public.build_dropship_tenant_b2b_invoice_payload(p_order_id);
  if coalesce(v_build->>'success', 'false') <> 'true' then
    return v_build;
  end if;

  v_payload := v_build->'payload';
  v_payload := v_payload || jsonb_build_object(
    'issue', true,
    'shop_order_id', p_order_id
  );

  select i.id into v_orphan_invoice_id
  from public.global_invoices i
  where i.invoice_no = v_payload->'invoice'->>'invoice_no'
    and i.invoice_type = 'dropship'::public.global_invoice_type
    and (
      i.issued_by_tenant_id = v_order.tenant_id
      or i.parent_tenant_id = v_parent_tenant_id
    )
    and not exists (
      select 1 from public.shop_orders o2 where o2.global_invoice_id = i.id
    )
  limit 1;

  if v_orphan_invoice_id is not null then
    delete from public.global_return_items where invoice_id = v_orphan_invoice_id;
    delete from public.sales_invoice_item_costs
    where invoice_item_id in (
      select id from public.sales_invoice_items where invoice_id = v_orphan_invoice_id
    );
    delete from public.sales_invoice_charges where invoice_id = v_orphan_invoice_id;
    delete from public.sales_invoice_items where invoice_id = v_orphan_invoice_id;
    delete from public.sales_invoices where id = v_orphan_invoice_id;
  end if;

  v_result := public.create_sales_invoice_from_payload(p_tenant_id, v_payload);
  v_created := true;

  if coalesce(v_result->>'success', 'false') <> 'true' then
    return coalesce(
      v_result,
      jsonb_build_object('success', false, 'error', 'failed to upsert tenant B2B invoice')
    );
  end if;

  update public.shop_orders
  set
    global_invoice_id = (v_result->>'invoice_id')::bigint,
    updated_at = now()
  where id = p_order_id
    and global_invoice_id is null;

  select * into v_order from public.shop_orders where id = p_order_id;
  select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'invoice was not created');
  end if;

  perform public.snapshot_sales_invoice_item_costs(v_invoice.id);
  perform public.sync_sales_invoice_charges_from_header(v_invoice.id);

  update public.sales_invoices
  set
    shop_order_id = p_order_id,
    channel_meta = coalesce(v_payload->'invoice'->'channel_meta', '{}'::jsonb),
    updated_at = now()
  where id = v_invoice.id;

  perform public.ensure_dropship_invoice_billed_entry(v_invoice.id);

  v_courier_cod_booked := exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = p_tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'delivered_costing'
  );

  return jsonb_build_object(
    'success', true,
    'created', v_created,
    'already_issued', false,
    'order_id', p_order_id,
    'invoice', jsonb_build_object(
      'id', v_invoice.id,
      'invoice_no', v_invoice.invoice_no,
      'invoice_type', v_invoice.invoice_type,
      'invoice_status', v_invoice.invoice_status,
      'payment_status', v_invoice.payment_status,
      'subtotal_amount', v_invoice.subtotal_amount,
      'print_charge', v_invoice.print_charge,
      'wrapping_charge', v_invoice.wrapping_charge,
      'discount_amount', v_invoice.discount_amount,
      'total_amount', v_invoice.total_amount,
      'paid_amount', v_invoice.paid_amount,
      'due_amount', v_invoice.due_amount,
      'billing_profile_id', v_invoice.billing_profile_id,
      'collection_source', v_invoice.collection_source
    ),
    'wallet', jsonb_build_object(
      'courier_cod_booked', v_courier_cod_booked,
      'source_type', 'shop_order',
      'source_id', p_order_id::text
    )
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;

-- ---------------------------------------------------------------------------
-- list_global_invoice_items — resell price from line_meta, not sell alias
-- ---------------------------------------------------------------------------
create or replace function public.list_global_invoice_items(p_invoice_id bigint)
returns table (
  id bigint,
  invoice_id bigint,
  global_stock_id bigint,
  name_snapshot text,
  quantity numeric,
  sell_price_amount numeric,
  recipient_price_amount numeric,
  line_face_total_amount numeric,
  line_discount_amount numeric,
  line_total_amount numeric,
  return_quantity numeric,
  image_url text,
  shipment_id bigint,
  shipment_item_id bigint,
  purchase_price numeric,
  product_weight numeric,
  package_weight numeric,
  ordered_quantity integer,
  shipment_type text,
  product_conversion_rate numeric,
  cargo_conversion_rate numeric,
  cargo_rate numeric,
  received_weight numeric,
  transaction_rate numeric,
  available_atp numeric,
  unit_cost_price numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_parent_tenant_id bigint;
  v_issued_by bigint;
  v_invoice_status public.global_invoice_status;
begin
  select parent_tenant_id, issued_by_tenant_id, invoice_status
  into v_parent_tenant_id, v_issued_by, v_invoice_status
  from public.sales_invoices
  where public.sales_invoices.id = p_invoice_id;

  if not found then
    raise exception 'Invoice with ID % not found', p_invoice_id;
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or public.has_active_tenant_membership(v_issued_by)
    or public.membership_has_module_action(v_issued_by, 'global_invoice', 'view')
  ) then
    raise exception 'Access denied for invoice with ID %', p_invoice_id;
  end if;

  return query
  select
    gii.id,
    gii.invoice_id,
    gii.global_stock_id,
    gii.name_snapshot,
    gii.quantity,
    gii.sell_price_amount,
    nullif(gii.line_meta->>'resell_price_amount', '')::numeric as recipient_price_amount,
    (gii.quantity * nullif(gii.line_meta->>'resell_price_amount', '')::numeric) as line_face_total_amount,
    gii.line_discount_amount,
    gii.line_total_amount,
    gii.return_quantity,
    coalesce(gsi.image_url, p.image_url) as image_url,
    gsi.shipment_id,
    gsi.id as shipment_item_id,
    gsi.purchase_price,
    gsi.product_weight,
    gsi.package_weight,
    gsi.ordered_quantity,
    gship.type::text as shipment_type,
    null::numeric as product_conversion_rate,
    null::numeric as cargo_conversion_rate,
    null::numeric as cargo_rate,
    gship.received_weight,
    null::numeric as transaction_rate,
    case
      when gii.global_stock_id is null then 0::numeric
      when v_invoice_status in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status)
        then (coalesce(public.global_stock_atp_qty(gii.global_stock_id), gs.quantity, 0) + gii.quantity)::numeric
      else (coalesce(public.global_stock_atp_qty(gii.global_stock_id), gs.quantity, 0))::numeric
    end as available_atp,
    coalesce(gii.unit_cost_price, gsi.landed_cost_bdt, gsi.purchase_price, 0)::numeric as unit_cost_price
  from public.sales_invoice_items gii
  left join public.global_stocks gs on gs.id = gii.global_stock_id
  left join public.global_shipment_items gsi
    on gsi.id = coalesce(gii.shipment_item_id, gs.shipment_item_id)
  left join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.products p on p.id = gii.product_id
  where gii.invoice_id = p_invoice_id
  order by gii.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- create_sales_invoice_from_payload — persist line_meta; snapshot on issue
-- ---------------------------------------------------------------------------
create or replace function public.create_sales_invoice_from_payload(
  p_tenant_id bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv jsonb;
  v_item_elem jsonb;
  v_invoice public.sales_invoices;
  v_invoice_id bigint;
  v_parent_id bigint;
  v_invoice_type public.global_invoice_type;
  v_retail_mode public.retail_billing_mode;
  v_issue boolean;
  v_shop_order_id bigint;
  v_items jsonb;
  v_item_ids bigint[] := '{}';
  v_created_item_id bigint;
  v_global_stock_id bigint;
  v_quantity numeric;
  v_sell_price numeric;
  v_line_discount numeric;
  v_line_total numeric;
  v_unit_cost numeric;
  v_shipment_item_id bigint;
  v_product_id bigint;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_assigned_child bigint;
  v_stock_parent bigint;
  v_has_charges boolean;
  v_cod_charge numeric(12,2);
  v_line_meta jsonb;
  v_channel_meta jsonb;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return jsonb_build_object('success', false, 'error', 'payload must be a JSON object');
  end if;

  v_inv := coalesce(p_payload->'invoice', '{}'::jsonb);
  v_items := coalesce(p_payload->'items', '[]'::jsonb);
  v_issue := coalesce((p_payload->>'issue')::boolean, false);
  v_shop_order_id := nullif(p_payload->>'shop_order_id', '')::bigint;
  v_channel_meta := coalesce(v_inv->'channel_meta', '{}'::jsonb);

  if v_inv->>'invoice_type' is null or trim(v_inv->>'invoice_type') = '' then
    return jsonb_build_object('success', false, 'error', 'invoice.invoice_type is required');
  end if;

  v_invoice_type := (v_inv->>'invoice_type')::public.global_invoice_type;

  if jsonb_typeof(v_items) <> 'array' then
    return jsonb_build_object('success', false, 'error', 'items must be a JSON array');
  end if;

  if v_issue and jsonb_array_length(v_items) = 0 then
    return jsonb_build_object('success', false, 'error', 'at least one item is required when issue is true');
  end if;

  v_retail_mode := case
    when v_inv->>'retail_billing_mode' is null or trim(v_inv->>'retail_billing_mode') = '' then null
    else (v_inv->>'retail_billing_mode')::public.retail_billing_mode
  end;

  select * into v_invoice
  from public.create_sales_invoice(
    p_tenant_id => p_tenant_id,
    p_invoice_no => coalesce(nullif(trim(v_inv->>'invoice_no'), ''), ''),
    p_invoice_type => v_invoice_type,
    p_billing_profile_id => nullif(v_inv->>'billing_profile_id', '')::bigint,
    p_recipient_profile_id => nullif(v_inv->>'recipient_profile_id', '')::bigint,
    p_recipient_name => nullif(trim(v_inv->>'recipient_name'), ''),
    p_recipient_phone => nullif(trim(v_inv->>'recipient_phone'), ''),
    p_recipient_address => nullif(trim(v_inv->>'recipient_address'), ''),
    p_retail_billing_mode => v_retail_mode,
    p_due_date => nullif(v_inv->>'due_date', '')::date,
    p_note => nullif(trim(v_inv->>'note'), ''),
    p_invoice_date => nullif(v_inv->>'invoice_date', '')::date
  );

  v_invoice_id := v_invoice.id;
  v_parent_id := v_invoice.parent_tenant_id;

  update public.sales_invoices
  set
    shop_order_id = v_shop_order_id,
    channel_meta = v_channel_meta,
    updated_at = now()
  where id = v_invoice_id;

  for v_item_elem in select value from jsonb_array_elements(v_items) as t(value) loop
    v_global_stock_id := nullif(v_item_elem->>'global_stock_id', '')::bigint;
    v_quantity := nullif(v_item_elem->>'quantity', '')::numeric;
    v_sell_price := nullif(v_item_elem->>'sell_price_amount', '')::numeric;
    v_line_discount := coalesce(nullif(v_item_elem->>'line_discount_amount', '')::numeric, 0);
    v_line_meta := coalesce(v_item_elem->'line_meta', '{}'::jsonb);

    if v_global_stock_id is null then
      return jsonb_build_object('success', false, 'error', 'each item requires global_stock_id');
    end if;
    if v_quantity is null or v_quantity <= 0 then
      return jsonb_build_object('success', false, 'error', 'each item requires quantity > 0');
    end if;
    if v_sell_price is null or v_sell_price < 0 then
      return jsonb_build_object('success', false, 'error', 'each item requires sell_price_amount >= 0');
    end if;

    select
      gs.parent_tenant_id,
      gs.shipment_item_id,
      gsi.name,
      gsi.barcode,
      gsi.product_code,
      sh.assigned_child_tenant_id,
      p.id
    into
      v_stock_parent,
      v_shipment_item_id,
      v_name_snapshot,
      v_barcode_snapshot,
      v_product_code_snapshot,
      v_assigned_child,
      v_product_id
    from public.global_stocks gs
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    left join public.products p on p.id = gsi.product_id
    where gs.id = v_global_stock_id;

    if v_stock_parent is null then
      return jsonb_build_object('success', false, 'error', format('stock %s not found', v_global_stock_id));
    end if;

    if v_stock_parent <> v_parent_id then
      return jsonb_build_object('success', false, 'error', format('stock %s does not belong to invoice parent tenant', v_global_stock_id));
    end if;

    v_shipment_item_id := coalesce(nullif(v_item_elem->>'shipment_item_id', '')::bigint, v_shipment_item_id);
    v_product_id := coalesce(nullif(v_item_elem->>'product_id', '')::bigint, v_product_id);
    v_name_snapshot := coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), v_name_snapshot, 'Item');
    v_barcode_snapshot := coalesce(nullif(trim(v_item_elem->>'barcode_snapshot'), ''), v_barcode_snapshot);
    v_product_code_snapshot := coalesce(nullif(trim(v_item_elem->>'product_code_snapshot'), ''), v_product_code_snapshot);
    v_assigned_child := coalesce(nullif(v_item_elem->>'assigned_child_tenant_id', '')::bigint, v_assigned_child);

    v_unit_cost := coalesce(
      nullif(v_item_elem->>'unit_cost_price', '')::numeric,
      public.calculate_landed_unit_cost(v_shipment_item_id),
      0
    );
    v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);

    insert into public.sales_invoice_items (
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
      assigned_child_tenant_id,
      line_meta
    )
    values (
      v_parent_id,
      v_invoice_id,
      v_global_stock_id,
      v_shipment_item_id,
      v_product_id,
      v_name_snapshot,
      v_barcode_snapshot,
      v_product_code_snapshot,
      v_quantity,
      v_unit_cost,
      v_sell_price,
      v_line_discount,
      v_line_total,
      v_assigned_child,
      v_line_meta
    )
    returning id into v_created_item_id;

    v_item_ids := array_append(v_item_ids, v_created_item_id);
  end loop;

  v_cod_charge := case
    when v_inv ? 'cod_charge_amount' then nullif(v_inv->>'cod_charge_amount', '')::numeric
    when v_inv ? 'cod_charge' then nullif(v_inv->>'cod_charge', '')::numeric
    else null
  end;

  v_has_charges := (
    v_inv ? 'discount_amount'
    or v_inv ? 'shipping_charge'
    or v_inv ? 'print_charge'
    or v_inv ? 'wrapping_charge'
    or v_inv ? 'cod_charge_amount'
    or v_inv ? 'cod_charge'
  );

  if v_has_charges then
    perform public.update_global_invoice_header(
      p_invoice_id => v_invoice_id,
      p_discount_amount => case when v_inv ? 'discount_amount' then nullif(v_inv->>'discount_amount', '')::numeric else null end,
      p_shipping_charge => case when v_inv ? 'shipping_charge' then nullif(v_inv->>'shipping_charge', '')::numeric else null end,
      p_cod_charge => v_cod_charge,
      p_wrapping_charge => case when v_inv ? 'wrapping_charge' then nullif(v_inv->>'wrapping_charge', '')::numeric else null end,
      p_print_charge => case when v_inv ? 'print_charge' then nullif(v_inv->>'print_charge', '')::numeric else null end,
      p_recipient_name => null,
      p_recipient_phone => null,
      p_recipient_address => null,
      p_note => null,
      p_invoice_no => null,
      p_invoice_date => null
    );
  else
    perform public.recompute_global_invoice_totals(v_invoice_id);
  end if;

  if v_issue then
    perform public.post_sales_invoice(v_invoice_id);
    perform public.snapshot_sales_invoice_item_costs(v_invoice_id);
    perform public.sync_sales_invoice_charges_from_header(v_invoice_id);
  end if;

  if v_shop_order_id is not null then
    if not exists (
      select 1 from public.shop_orders o
      where o.id = v_shop_order_id
        and o.tenant_id = p_tenant_id
        and o.shop_type_snapshot = 'dropship'
    ) then
      return jsonb_build_object('success', false, 'error', 'shop_order_id must be a dropship order for this tenant');
    end if;

    update public.shop_orders
    set
      global_invoice_id = v_invoice_id,
      updated_at = now()
    where id = v_shop_order_id
      and tenant_id = p_tenant_id
      and global_invoice_id is null;
  end if;

  select * into v_invoice from public.sales_invoices where id = v_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'invoice_type', v_invoice.invoice_type,
    'invoice_status', v_invoice.invoice_status,
    'payment_status', v_invoice.payment_status,
    'subtotal_amount', v_invoice.subtotal_amount,
    'discount_amount', v_invoice.discount_amount,
    'shipping_charge', v_invoice.shipping_charge,
    'cod_charge_amount', v_invoice.cod_charge_amount,
    'print_charge', v_invoice.print_charge,
    'wrapping_charge', v_invoice.wrapping_charge,
    'total_amount', v_invoice.total_amount,
    'paid_amount', v_invoice.paid_amount,
    'due_amount', v_invoice.due_amount,
    'billing_profile_id', v_invoice.billing_profile_id,
    'collection_source', v_invoice.collection_source,
    'item_ids', to_jsonb(v_item_ids),
    'issued', v_issue,
    'shop_order_id', v_shop_order_id
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;

-- ---------------------------------------------------------------------------
-- Block legacy dropship fulfill → invoice path
-- ---------------------------------------------------------------------------
create or replace function public.fulfill_shop_order_to_invoice(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_invoice_type public.global_invoice_type;
  v_retail_billing_mode public.retail_billing_mode;
  v_invoice_no text;
  v_item record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;

  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'confirmed' then
    raise exception 'only confirmed orders can be fulfilled to an invoice';
  end if;

  if v_order.shop_type_snapshot = 'vendor_catalog' then
    raise exception 'vendor catalog orders cannot be fulfilled to an invoice directly';
  end if;

  if v_order.shop_type_snapshot = 'dropship' then
    raise exception 'dropship orders must use issue_dropship_tenant_b2b_invoice at ready_for_pickup or shipped';
  end if;

  if v_order.order_mode_snapshot = 'checkout_wholesale' then
    v_invoice_type := 'wholesale'::public.global_invoice_type;
    v_retail_billing_mode := null;
  else
    v_invoice_type := 'retail'::public.global_invoice_type;
    if v_order.billing_profile_id is not null then
      v_retail_billing_mode := 'account'::public.retail_billing_mode;
    else
      v_retail_billing_mode := 'direct'::public.retail_billing_mode;
    end if;
  end if;

  v_invoice_no := 'INV-SO-' || v_order.order_no;

  select * into v_invoice from public.create_global_invoice(
    p_tenant_id => v_order.tenant_id,
    p_invoice_no => v_invoice_no,
    p_invoice_type => v_invoice_type,
    p_billing_profile_id => v_order.billing_profile_id,
    p_recipient_profile_id => null,
    p_recipient_name => v_order.recipient_name,
    p_recipient_phone => v_order.recipient_phone,
    p_recipient_address => v_order.shipping_address,
    p_retail_billing_mode => v_retail_billing_mode,
    p_due_date => null,
    p_note => coalesce(v_order.delivery_instructions, 'Fulfillment of Shop Order: ' || v_order.order_no)
  );

  update public.global_invoices
  set
    shipping_charge = coalesce(v_order.delivery_charge_amount, 0),
    cod_charge = coalesce(v_order.cod_charge_amount, 0),
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    collection_source = case
      when v_order.is_prepaid_snapshot then 'billing_profile'::public.collection_source_type
      else 'recipient'::public.collection_source_type
    end
  where id = v_invoice.id;

  for v_item in select * from public.shop_order_items where order_id = p_order_id loop
    if v_item.global_stock_id is null then
      raise exception 'item % is missing global_stock_id association', v_item.name;
    end if;

    perform public.add_global_invoice_item(
      p_invoice_id => v_invoice.id,
      p_global_stock_id => v_item.global_stock_id,
      p_quantity => v_item.quantity::numeric,
      p_sell_price_amount => coalesce(v_item.final_price_amount, v_item.unit_sell_price_amount, v_item.unit_list_price_amount),
      p_recipient_price_amount => coalesce(v_item.customer_sell_price_amount, v_item.final_price_amount, v_item.unit_sell_price_amount, v_item.unit_list_price_amount),
      p_line_discount_amount => 0.00
    );
  end loop;

  perform public.recompute_global_invoice_totals(v_invoice.id);
  perform public.post_global_invoice(v_invoice.id);

  update public.shop_orders
  set status = 'fulfilled',
      global_invoice_id = v_invoice.id,
      fulfilled_at = now(),
      updated_at = now()
  where id = p_order_id;
end;
$$;

grant execute on function public.build_dropship_tenant_b2b_invoice_payload(bigint, bigint, text, bigint, text) to authenticated;
grant execute on function public.create_dropship_invoice(bigint, text, bigint, text) to authenticated;
grant execute on function public.create_dual_invoice_from_dropship_order(bigint, text, bigint, text) to authenticated;
grant execute on function public.issue_dropship_tenant_b2b_invoice(bigint, bigint) to authenticated;
grant execute on function public.list_global_invoice_items(bigint) to authenticated;
grant execute on function public.list_global_invoice_items(bigint) to service_role;
grant execute on function public.create_sales_invoice_from_payload(bigint, jsonb) to authenticated;
grant execute on function public.fulfill_shop_order_to_invoice(bigint) to authenticated;

commit;
