begin;

create or replace function public.create_commerce_invoice(
  p_tenant_id bigint,
  p_order_id bigint,
  p_delivery_charge numeric,
  p_wrapping_charge numeric,
  p_cod numeric,
  p_total_amount numeric,
  p_amount_paid numeric,
  p_delivered_by text
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice_id bigint;
  v_cust_group_id bigint;
  v_item record;
  v_is_paid boolean;
begin
  select tenant_id, customer_group_id into p_tenant_id, v_cust_group_id
  from public.commerce_orders
  where id = p_order_id;

  if p_tenant_id is null then
    raise exception 'Commerce order % not found.', p_order_id;
  end if;

  v_is_paid := coalesce(p_amount_paid, 0) >= coalesce(p_total_amount, 0);

  insert into public.commerce_invoices (
    order_id,
    delivery_charge,
    wrapping_charge,
    cod,
    total_amount,
    amount_paid,
    amount_due,
    is_customer_group_paid,
    delivered_by,
    tenant_id
  )
  values (
    p_order_id,
    coalesce(p_delivery_charge, 0),
    coalesce(p_wrapping_charge, 0),
    coalesce(p_cod, 0),
    coalesce(p_total_amount, 0),
    coalesce(p_amount_paid, 0),
    greatest(coalesce(p_total_amount, 0) - coalesce(p_amount_paid, 0), 0),
    v_is_paid,
    p_delivered_by,
    p_tenant_id
  )
  returning id into v_invoice_id;

  update public.commerce_orders
  set
    status = 'reviewing'::public.commerce_order_status,
    invoice_ids = array_append(coalesce(invoice_ids, '{}'::bigint[]), v_invoice_id)
  where id = p_order_id;

  update public.commerce_order_items
  set invoice_id = v_invoice_id
  where order_id = p_order_id
    and invoice_id is null;

  for v_item in (
    select
      id,
      cost_bdt,
      sell_price_bdt,
      recipient_price_bdt,
      inventory_item_id,
      shipment_item_id
    from public.commerce_order_items
    where order_id = p_order_id
      and invoice_id = v_invoice_id
  ) loop
    insert into public.commerce_accounting (
      order_item_id,
      cost_bdt,
      inventory_item_id,
      shipment_item_id,
      sell_price_bdt,
      recipient_sell_price_bdt,
      customer_group_id,
      is_customer_group_paid,
      tenant_id
    )
    values (
      v_item.id,
      coalesce(v_item.cost_bdt, 0),
      v_item.inventory_item_id,
      v_item.shipment_item_id,
      coalesce(v_item.sell_price_bdt, 0),
      coalesce(v_item.recipient_price_bdt, 0),
      coalesce(v_cust_group_id, 0),
      v_is_paid,
      p_tenant_id
    )
    on conflict (order_item_id)
    do update set
      cost_bdt = excluded.cost_bdt,
      inventory_item_id = excluded.inventory_item_id,
      shipment_item_id = excluded.shipment_item_id,
      sell_price_bdt = excluded.sell_price_bdt,
      recipient_sell_price_bdt = excluded.recipient_sell_price_bdt,
      customer_group_id = excluded.customer_group_id,
      is_customer_group_paid = excluded.is_customer_group_paid,
      tenant_id = excluded.tenant_id,
      updated_at = now();
  end loop;

  return v_invoice_id;
end;
$$;

grant execute on function public.create_commerce_invoice(bigint, bigint, numeric, numeric, numeric, numeric, numeric, text) to authenticated;

commit;
