-- SI2: New invoices are in the parent's name.
-- create_global_invoice writes tenant_id = parent, issued_by_tenant_id = caller (child).
-- Profiles must belong to issued_by. invoice_no unique per parent tenant_id.
-- add_global_invoice_item snapshots shipments.assigned_child_tenant_id.
-- create_dual_invoice_from_dropship_order uses the create RPC.

begin;

-- ---------------------------------------------------------------------------
-- Profile trigger: match issued_by (seller), not books owner
-- ---------------------------------------------------------------------------
create or replace function public.trg_validate_global_invoice_profiles()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.billing_profile_id is not null then
    if not exists (
      select 1 from public.billing_profiles bp
      where bp.id = new.billing_profile_id
        and bp.tenant_id = new.issued_by_tenant_id
    ) then
      raise exception 'Billing profile tenant_id must match invoice issued_by_tenant_id';
    end if;
  end if;

  if new.recipient_profile_id is not null then
    if not exists (
      select 1 from public.recipient_profiles rp
      where rp.id = new.recipient_profile_id
        and rp.tenant_id = new.issued_by_tenant_id
    ) then
      raise exception 'Recipient profile tenant_id must match invoice issued_by_tenant_id';
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Desk / shop create (frontend + fulfill_shop_order_to_invoice)
-- ---------------------------------------------------------------------------
create or replace function public.create_global_invoice(
  p_tenant_id bigint,
  p_invoice_no text,
  p_invoice_type public.global_invoice_type,
  p_billing_profile_id bigint default null,
  p_recipient_profile_id bigint default null,
  p_recipient_name text default null,
  p_recipient_phone text default null,
  p_recipient_address text default null,
  p_retail_billing_mode public.retail_billing_mode default null,
  p_due_date date default null,
  p_note text default null,
  p_invoice_date date default null
)
returns public.global_invoices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.global_invoices;
  v_parent_id bigint;
  v_issued_by bigint;
  v_rec_name text;
  v_rec_phone text;
  v_rec_address text;
  v_recipient_name text;
  v_recipient_phone text;
  v_recipient_address text;
  v_bill_name text;
  v_bill_phone text;
  v_bill_address text;
  v_collection_source public.collection_source_type;
begin
  v_issued_by := p_tenant_id;
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'not allowed';
  end if;

  if p_billing_profile_id is not null then
    if not exists (
      select 1 from public.billing_profiles
      where id = p_billing_profile_id and tenant_id = v_issued_by
    ) then
      raise exception 'billing profile must belong to the issuing tenant';
    end if;
  end if;

  if p_recipient_profile_id is not null then
    if not exists (
      select 1 from public.recipient_profiles
      where id = p_recipient_profile_id and tenant_id = v_issued_by
    ) then
      raise exception 'recipient profile must belong to the issuing tenant';
    end if;
  end if;

  if p_invoice_type = 'wholesale'::public.global_invoice_type then
    if p_billing_profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for wholesale invoices';
    end if;
    v_collection_source := 'billing_profile'::public.collection_source_type;

  elsif p_invoice_type = 'retail'::public.global_invoice_type then
    if p_retail_billing_mode is null then
      raise exception 'retail billing mode (account or direct) is required for retail invoices';
    end if;

    if p_retail_billing_mode = 'account'::public.retail_billing_mode then
      if p_billing_profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
      v_collection_source := 'billing_profile'::public.collection_source_type;
    else
      if p_billing_profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
      v_collection_source := 'recipient'::public.collection_source_type;
    end if;

  elsif p_invoice_type = 'dropship'::public.global_invoice_type then
    if p_billing_profile_id is null then
      raise exception 'billing profile (middle man) is required for dropship invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for dropship invoices';
    end if;
    v_collection_source := 'recipient'::public.collection_source_type;
  end if;

  if p_recipient_profile_id is not null then
    select name, phone, address
    into v_rec_name, v_rec_phone, v_rec_address
    from public.recipient_profiles
    where id = p_recipient_profile_id;
  end if;

  v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_rec_name);
  v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_rec_phone);
  v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_rec_address);

  if p_invoice_type = 'wholesale'::public.global_invoice_type and p_billing_profile_id is not null then
    select name, phone, address
    into v_bill_name, v_bill_phone, v_bill_address
    from public.billing_profiles
    where id = p_billing_profile_id;

    v_recipient_name := coalesce(v_recipient_name, v_bill_name);
    v_recipient_phone := coalesce(v_recipient_phone, v_bill_phone);
    v_recipient_address := coalesce(v_recipient_address, v_bill_address);
  end if;

  insert into public.global_invoices (
    tenant_id,
    parent_tenant_id,
    issued_by_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    retail_billing_mode,
    invoice_status,
    fulfillment_status,
    billing_profile_id,
    recipient_profile_id,
    recipient_name,
    recipient_phone,
    recipient_address,
    collection_source,
    due_date,
    payment_status,
    note
  )
  values (
    v_parent_id,
    v_parent_id,
    v_issued_by,
    trim(p_invoice_no),
    p_invoice_type,
    coalesce(p_invoice_date, current_date),
    p_retail_billing_mode,
    'draft'::public.global_invoice_status,
    'pending'::public.global_fulfillment_status,
    p_billing_profile_id,
    p_recipient_profile_id,
    v_recipient_name,
    v_recipient_phone,
    v_recipient_address,
    v_collection_source,
    p_due_date,
    'due',
    nullif(trim(coalesce(p_note, '')), '')
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.create_global_invoice(
  bigint, text, public.global_invoice_type, bigint, bigint, text, text, text, public.retail_billing_mode, date, text, date
) to authenticated;

-- ---------------------------------------------------------------------------
-- Dropship-style overload (p_source_module)
-- ---------------------------------------------------------------------------
create or replace function public.create_global_invoice(
  p_tenant_id bigint,
  p_invoice_no text,
  p_billing_profile_id bigint,
  p_invoice_type public.global_invoice_type default 'wholesale',
  p_source_module public.global_source_module default 'wholesale',
  p_recipient_name text default null,
  p_recipient_phone text default null,
  p_recipient_address text default null,
  p_recipient_party_id bigint default null,
  p_middle_man_payout_amount numeric default null,
  p_note text default null
)
returns public.global_invoices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.global_invoices;
  v_parent_id bigint;
  v_issued_by bigint;
  v_profile public.billing_profiles;
  v_invoice_type public.global_invoice_type;
  v_recipient_name text;
  v_recipient_phone text;
  v_recipient_address text;
  v_collection_source text;
begin
  if p_billing_profile_id is null then
    raise exception 'Billing profile is required.';
  end if;

  v_invoice_type := coalesce(p_invoice_type, 'wholesale');
  v_issued_by := p_tenant_id;
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'not allowed';
  end if;

  select * into v_profile from public.billing_profiles where id = p_billing_profile_id;
  if v_profile.id is null then raise exception 'Billing profile not found.'; end if;
  if v_profile.tenant_id <> v_issued_by then
    raise exception 'Billing profile does not belong to issuing tenant.';
  end if;

  if v_invoice_type = 'wholesale' then
    v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_profile.name);
    v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_profile.phone);
    v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_profile.address);
    v_collection_source := 'billing_profile';
  elsif v_invoice_type = 'retail' then
    v_recipient_name := nullif(trim(coalesce(p_recipient_name, '')), '');
    v_recipient_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
    v_recipient_address := nullif(trim(coalesce(p_recipient_address, '')), '');
    if v_recipient_name is null then raise exception 'Recipient name is required for retail.'; end if;
    v_collection_source := 'billing_profile';
  elsif v_invoice_type = 'dropship' then
    v_recipient_name := nullif(trim(coalesce(p_recipient_name, '')), '');
    v_recipient_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
    v_recipient_address := nullif(trim(coalesce(p_recipient_address, '')), '');
    if v_recipient_name is null then raise exception 'Recipient name is required for dropship.'; end if;
    v_collection_source := 'billing_profile';
  else
    raise exception 'Invalid invoice type.';
  end if;

  insert into public.global_invoices (
    tenant_id, parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type,
    billing_profile_id,
    recipient_name, recipient_phone, recipient_address,
    collection_source, note, due_amount
  )
  values (
    v_parent_id, v_parent_id, v_issued_by, trim(p_invoice_no), v_invoice_type,
    p_billing_profile_id,
    v_recipient_name, v_recipient_phone, v_recipient_address,
    v_collection_source, nullif(trim(coalesce(p_note, '')), ''), 0
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.create_global_invoice(
  bigint, text, bigint, public.global_invoice_type, public.global_source_module,
  text, text, text, bigint, numeric, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- Add item: snapshot assigned_child from shipment
-- ---------------------------------------------------------------------------
create or replace function public.add_global_invoice_item(
  p_invoice_id bigint,
  p_global_stock_id bigint,
  p_quantity numeric,
  p_sell_price_amount numeric,
  p_line_discount_amount numeric default 0,
  p_recipient_price_amount numeric default null
)
returns public.global_invoice_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_stock public.global_stocks;
  v_row public.global_invoice_items;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_line_total numeric;
  v_product_id bigint;
  v_unit_cost numeric;
  v_qty_remaining numeric;
  v_avail integer;
  v_take numeric;
  v_existing_qty numeric;
  v_curr_stock_id bigint;
  v_shipment_item_id bigint;
  v_assigned_child bigint;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot add items to a non-draft invoice';
  end if;

  select * into v_stock from public.global_stocks where id = p_global_stock_id;
  if v_stock.id is null then raise exception 'stock not found'; end if;
  if v_stock.parent_tenant_id <> v_invoice.parent_tenant_id then
    raise exception 'stock must belong to the same parent tenant group';
  end if;

  select product_id into v_product_id
  from public.global_shipment_items
  where id = v_stock.shipment_item_id;

  v_qty_remaining := p_quantity;
  v_curr_stock_id := p_global_stock_id;

  v_avail := public.get_available_stock(v_curr_stock_id, v_invoice.tenant_id);
  select coalesce(sum(quantity), 0) into v_existing_qty
  from public.global_invoice_items
  where invoice_id = p_invoice_id and global_stock_id = v_curr_stock_id;

  v_avail := greatest(v_avail - v_existing_qty, 0);

  if v_avail > 0 then
    v_take := least(v_qty_remaining, v_avail);

    select gsi.name, gsi.barcode, gsi.product_code, gsi.id, sh.assigned_child_tenant_id
    into v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot, v_shipment_item_id, v_assigned_child
    from public.global_shipment_items gsi
    join public.global_shipments sh on sh.id = gsi.shipment_id
    where gsi.id = (select shipment_item_id from public.global_stocks where id = v_curr_stock_id);

    v_line_total := greatest((v_take * p_sell_price_amount) - coalesce(p_line_discount_amount, 0.00), 0.00);
    v_unit_cost := coalesce(public.calculate_landed_unit_cost(v_shipment_item_id), 0.00);

    insert into public.global_invoice_items (
      tenant_id, parent_tenant_id, invoice_id, global_stock_id, shipment_item_id, product_id,
      name_snapshot, barcode_snapshot, product_code_snapshot, quantity, unit_cost_price,
      sell_price_amount, line_discount_amount, line_total_amount, return_quantity,
      assigned_child_tenant_id
    )
    values (
      v_invoice.tenant_id, v_invoice.parent_tenant_id, p_invoice_id, v_curr_stock_id,
      v_shipment_item_id, v_product_id,
      v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot, v_take, v_unit_cost,
      p_sell_price_amount, coalesce(p_line_discount_amount, 0.00), v_line_total, 0.00,
      v_assigned_child
    )
    returning * into v_row;

    v_qty_remaining := v_qty_remaining - v_take;
  end if;

  if v_qty_remaining > 0 then
    raise exception 'insufficient stock: requested %, available %', p_quantity, (p_quantity - v_qty_remaining);
  end if;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$$;

grant execute on function public.add_global_invoice_item(bigint, bigint, numeric, numeric, numeric, numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- Dropship dual invoice: create RPC (parent books + child issued_by)
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
  v_item record;
  v_subtotal numeric(12,2) := 0;
  v_charges_total numeric(12,2) := 0;
  v_item_sell_price numeric(12,2);
  v_item_line_total numeric(12,2);
  v_assigned_child bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order is not a dropship order';
  end if;

  if v_order.status not in ('ready_for_pickup', 'shipped', 'delivered', 'payment_received') then
    raise exception 'Invoice can only be created for orders ready for pickup or later (current status: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is not null then
    raise exception 'Invoice already created for this order (invoice_id: %)', v_order.global_invoice_id;
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

    update public.shop_order_items
    set delivered_quantity = quantity,
        updated_at = now()
    where id = v_item.id;
  end loop;

  v_charges_total := coalesce(v_order.print_charge_amount, 0) + coalesce(v_order.packing_charge_amount, 0);

  update public.global_invoices
  set
    subtotal_amount = v_subtotal,
    shipping_charge = 0,
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    total_amount = greatest(v_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0), 0),
    due_amount = greatest(v_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0), 0),
    collection_source = case
      when coalesce(v_order.is_prepaid_snapshot, false) then 'billing_profile'::public.collection_source_type
      else 'recipient'::public.collection_source_type
    end,
    invoice_status = 'posted'::public.global_invoice_status,
    updated_at = now()
  where id = v_invoice.id;

  update public.shop_orders
  set
    global_invoice_id = v_invoice.id,
    updated_at = now()
  where id = v_order.id;

  perform public.ensure_dropship_invoice_billed_entry(v_invoice.id);

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice_no,
    'subtotal_amount', v_subtotal,
    'total_amount', v_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0)
  );
end;
$$;

grant execute on function public.create_dual_invoice_from_dropship_order(bigint, text, bigint, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Audit (rolled back via savepoint; no leftover prod rows)
-- ---------------------------------------------------------------------------
savepoint si2_audit;

do $$
declare
  v_suffix text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 12);
  v_email text := 'si2-audit-' || v_suffix || '@invalid.local';
  v_parent bigint;
  v_child_a bigint;
  v_child_b bigint;
  v_profile_a bigint;
  v_profile_b bigint;
  v_inv public.global_invoices;
  v_inv_b public.global_invoices;
  v_rejected boolean := false;
  v_dup_rejected boolean := false;
begin
  perform set_config('request.jwt.claims', json_build_object('email', v_email)::text, true);

  insert into public.tenants (name, slug, is_active)
  values ('SI2 Audit Parent ' || v_suffix, 'si2-audit-p-' || v_suffix, true)
  returning id into v_parent;

  insert into public.tenants (name, slug, parent_id, is_active)
  values ('SI2 Audit Child A ' || v_suffix, 'si2-audit-a-' || v_suffix, v_parent, true)
  returning id into v_child_a;

  insert into public.tenants (name, slug, parent_id, is_active)
  values ('SI2 Audit Child B ' || v_suffix, 'si2-audit-b-' || v_suffix, v_parent, true)
  returning id into v_child_b;

  insert into public.memberships (email, tenant_id, role, is_active)
  values
    (v_email, v_child_a, 'admin', true),
    (v_email, v_child_b, 'admin', true);

  insert into public.billing_profiles (tenant_id, name)
  values (v_child_a, 'SI2 Audit Profile A')
  returning id into v_profile_a;

  insert into public.billing_profiles (tenant_id, name)
  values (v_child_b, 'SI2 Audit Profile B')
  returning id into v_profile_b;

  select * into v_inv from public.create_global_invoice(
    p_tenant_id => v_child_a,
    p_invoice_no => 'SI2-AUDIT-' || v_suffix,
    p_invoice_type => 'wholesale'::public.global_invoice_type,
    p_billing_profile_id => v_profile_a,
    p_recipient_profile_id => null
  );

  assert v_inv.tenant_id = v_parent, 'SI2: tenant_id must be parent';
  assert v_inv.issued_by_tenant_id = v_child_a, 'SI2: issued_by_tenant_id must be child A';

  begin
    select * into v_inv_b from public.create_global_invoice(
      p_tenant_id => v_child_a,
      p_invoice_no => 'SI2-AUDIT-BAD-' || v_suffix,
      p_invoice_type => 'wholesale'::public.global_invoice_type,
      p_billing_profile_id => v_profile_b,
      p_recipient_profile_id => null
    );
  exception
    when others then
      v_rejected := true;
  end;
  assert v_rejected, 'SI2: must reject billing profile owned by child B';

  begin
    select * into v_inv_b from public.create_global_invoice(
      p_tenant_id => v_child_b,
      p_invoice_no => 'SI2-AUDIT-' || v_suffix,
      p_invoice_type => 'wholesale'::public.global_invoice_type,
      p_billing_profile_id => v_profile_b,
      p_recipient_profile_id => null
    );
  exception
    when unique_violation then
      v_dup_rejected := true;
    when others then
      if sqlerrm ilike '%invoice_no%' or sqlerrm ilike '%unique%' or sqlerrm ilike '%duplicate%' then
        v_dup_rejected := true;
      else
        raise;
      end if;
  end;
  assert v_dup_rejected, 'SI2: two children cannot reuse the same invoice_no under one parent';
end;
$$;

rollback to savepoint si2_audit;

commit;
