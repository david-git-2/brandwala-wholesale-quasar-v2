-- Migration: Add invoice_date to commerce_invoices and update create_commerce_invoice RPC
begin;

-- 1. Add invoice_date column to commerce_invoices if it does not exist
alter table public.commerce_invoices
  add column if not exists invoice_date date;

-- 2. Backfill existing records with their creation date (or current_date if missing)
update public.commerce_invoices
set invoice_date = coalesce(created_at::date, current_date)
where invoice_date is null;

-- 3. Enforce not null and set default value to current_date
alter table public.commerce_invoices
  alter column invoice_date set not null,
  alter column invoice_date set default current_date;

-- 4. Redefine create_commerce_invoice RPC function to accept an optional p_invoice_date parameter
create or replace function public.create_commerce_invoice(
  p_tenant_id bigint,
  p_order_id bigint,
  p_delivery_charge numeric,
  p_wrapping_charge numeric,
  p_cod numeric,
  p_total_amount numeric,
  p_amount_paid numeric,
  p_delivered_by text,
  p_billing_profile_id bigint default null,
  p_invoice_date date default current_date
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
  v_product_id bigint;
  v_quantity integer;
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
    tenant_id,
    billing_profile_id,
    invoice_date
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
    p_tenant_id,
    p_billing_profile_id,
    coalesce(p_invoice_date, current_date)
  )
  returning id into v_invoice_id;

  update public.commerce_orders
  set
    status = 'reviewing'::public.commerce_order_status,
    invoice_ids = array_append(coalesce(invoice_ids, '{}'::bigint[]), v_invoice_id)
  where id = p_order_id;

  update public.commerce_order_items
  set invoice_id = v_invoice_id
  where order_id = p_order_id;

  for v_item in (
    select
      coi.id,
      coi.cost_bdt,
      coi.sell_price_bdt,
      coi.recipient_price_bdt,
      coi.inventory_item_id,
      coi.shipment_item_id,
      coi.quantity,
      ii.tenant_id as inventory_tenant_id
    from public.commerce_order_items coi
    left join public.inventory_items ii on ii.id = coi.inventory_item_id
    where coi.order_id = p_order_id
  ) loop
    select product_id into v_product_id
    from public.inventory_items
    where id = v_item.inventory_item_id;

    v_quantity := coalesce(v_item.quantity, 1);

    insert into public.inventory_accounting_entries (
      type,
      commerce_order_item_id,
      cost_amount,
      shipment_item_id,
      sell_price_amount,
      recipient_sell_price_amount,
      customer_group_id,
      billing_profile_id,
      status,
      tenant_id,
      inventory_item_id,
      product_id,
      quantity,
      total_cost_amount,
      total_sell_amount,
      gross_profit_amount
    )
    values (
      'commerce',
      v_item.id,
      coalesce(v_item.cost_bdt, 0),
      v_item.shipment_item_id,
      coalesce(v_item.sell_price_bdt, 0),
      coalesce(v_item.recipient_price_bdt, 0),
      v_cust_group_id,
      p_billing_profile_id,
      case when v_is_paid then 'paid'::text else 'due'::text end,
      coalesce(v_item.inventory_tenant_id, p_tenant_id),
      v_item.inventory_item_id,
      v_product_id,
      v_quantity,
      (coalesce(v_item.cost_bdt, 0) * v_quantity),
      (coalesce(v_item.sell_price_bdt, 0) * v_quantity),
      ((coalesce(v_item.sell_price_bdt, 0) - coalesce(v_item.cost_bdt, 0)) * v_quantity)
    )
    on conflict (commerce_order_item_id) where (type = 'commerce')
    do update set
      cost_amount = excluded.cost_amount,
      inventory_item_id = excluded.inventory_item_id,
      shipment_item_id = excluded.shipment_item_id,
      sell_price_amount = excluded.sell_price_amount,
      recipient_sell_price_amount = excluded.recipient_sell_price_amount,
      customer_group_id = excluded.customer_group_id,
      billing_profile_id = excluded.billing_profile_id,
      status = excluded.status,
      tenant_id = excluded.tenant_id,
      product_id = excluded.product_id,
      quantity = excluded.quantity,
      total_cost_amount = excluded.total_cost_amount,
      total_sell_amount = excluded.total_sell_amount,
      gross_profit_amount = excluded.gross_profit_amount,
      updated_at = now();
  end loop;

  return v_invoice_id;
end;
$$;

commit;
