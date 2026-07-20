-- Migration: Deduct reservations/orders from display quantity override for dropshop
begin;

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
  v_invoice_row record;
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

  -- 1. Determine invoice type & retail billing mode
  if v_order.shop_type_snapshot = 'dropship' then
    v_invoice_type := 'dropship'::public.global_invoice_type;
    v_retail_billing_mode := null;
  else
    -- fixed_price
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
  end if;

  -- Generate invoice number
  v_invoice_no := 'INV-SO-' || v_order.order_no;

  -- 2. Create the global invoice
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

  -- Update invoice charges and collection source
  update public.global_invoices
  set
    shipping_charge = coalesce(v_order.delivery_charge_amount, 0),
    cod_charge = coalesce(v_order.cod_charge_amount, 0),
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    collection_source = case when v_order.is_prepaid_snapshot then 'billing_profile'::public.collection_source_type else 'recipient'::public.collection_source_type end
  where id = v_invoice.id;

  -- 3. Add lines to invoice
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

    -- Deduct from display quantity override for dropshop
    if v_order.shop_type_snapshot = 'dropship' then
      update public.shop_product_listings
      set display_quantity_override = greatest(0, display_quantity_override - v_item.quantity)
      where shop_id = v_order.shop_id
        and product_id = v_item.product_id
        and global_stock_allocation_id = v_item.global_stock_allocation_id
        and display_quantity_override is not null;
    end if;

    -- Update delivered quantities on order item
    update public.shop_order_items
    set delivered_quantity = quantity,
        updated_at = now()
    where id = v_item.id;
  end loop;

  -- Recompute totals with charges set
  perform public.recompute_global_invoice_totals(v_invoice.id);

  -- 4. Post the invoice to book ledger entries and deduct quantities
  perform public.post_global_invoice(v_invoice.id);

  -- 5. Complete the shop order
  update public.shop_orders
  set status = 'fulfilled',
      global_invoice_id = v_invoice.id,
      fulfilled_at = now(),
      updated_at = now()
  where id = p_order_id;
end;
$$;

commit;
