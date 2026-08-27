-- Cascade shop order delete: wallet ledger, invoice, payments, courier remittance lines.

begin;

create or replace function public._undo_wallet_ledger_row_before_delete(p_row public.universal_wallet_ledger)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bucket text;
begin
  v_bucket := coalesce(p_row.metadata->>'target_bucket', 'available');

  update public.wallet_accounts wa
  set
    available_balance = case
      when v_bucket = 'available' and p_row.type = 'credit' then wa.available_balance - p_row.amount
      when v_bucket = 'available' and p_row.type = 'debit' then wa.available_balance + p_row.amount
      else wa.available_balance
    end,
    pending_balance = case
      when v_bucket = 'pending' and p_row.type = 'credit' then wa.pending_balance - p_row.amount
      when v_bucket = 'pending' and p_row.type = 'debit' then wa.pending_balance + p_row.amount
      else wa.pending_balance
    end,
    locked_balance = case
      when v_bucket = 'locked' and p_row.type = 'credit' then wa.locked_balance - p_row.amount
      when v_bucket = 'locked' and p_row.type = 'debit' then wa.locked_balance + p_row.amount
      else wa.locked_balance
    end,
    updated_at = now()
  where wa.parent_tenant_id = p_row.parent_tenant_id
    and wa.entity_type = p_row.entity_type
    and wa.entity_id = p_row.entity_id
    and wa.currency_code = p_row.currency_code;
end;
$$;

create or replace function public.purge_shop_order_wallet_ledger(
  p_order_id bigint,
  p_tenant_id bigint,
  p_order_no text,
  p_invoice_id bigint default null,
  p_invoice_no text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.universal_wallet_ledger;
begin
  for v_row in
    select *
    from public.universal_wallet_ledger u
    where (
      u.source_type = 'shop_order'
      and (
        u.source_id = p_order_id::text
        or (p_order_no is not null and u.source_id = p_order_no)
        or (p_invoice_no is not null and u.source_id = p_invoice_no)
      )
    )
    or u.metadata->>'order_id' = p_order_id::text
    or (p_invoice_id is not null and u.metadata->>'invoice_id' = p_invoice_id::text)
  loop
    perform public._undo_wallet_ledger_row_before_delete(v_row);
  end loop;

  delete from public.universal_wallet_ledger u
  where (
    u.source_type = 'shop_order'
    and (
      u.source_id = p_order_id::text
      or (p_order_no is not null and u.source_id = p_order_no)
      or (p_invoice_no is not null and u.source_id = p_invoice_no)
    )
  )
  or u.metadata->>'order_id' = p_order_id::text
  or (p_invoice_id is not null and u.metadata->>'invoice_id' = p_invoice_id::text);
end;
$$;

create or replace function public.purge_shop_order_invoice(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_payment_ids bigint[];
begin
  if p_invoice_id is null then
    return;
  end if;

  select * into v_invoice
  from public.global_invoices
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    return;
  end if;

  select coalesce(array_agg(distinct ip.payment_id), '{}'::bigint[])
  into v_payment_ids
  from public.invoice_payments ip
  where ip.global_invoice_id = p_invoice_id;

  delete from public.invoice_payments
  where global_invoice_id = p_invoice_id;

  delete from public.global_payments gp
  where gp.id = any (v_payment_ids)
    and not exists (
      select 1
      from public.invoice_payments ip
      where ip.payment_id = gp.id
    );

  update public.sales_invoices
  set
    paid_amount = 0.00,
    payment_status = 'due',
    due_amount = coalesce(total_amount, 0.00),
    updated_at = now()
  where id = p_invoice_id;

  if v_invoice.invoice_status = 'issued'::public.global_invoice_status then
    perform public.unpost_global_invoice(p_invoice_id);
  end if;

  delete from public.global_return_items where invoice_id = p_invoice_id;
  delete from public.global_invoice_items where invoice_id = p_invoice_id;
  delete from public.sales_invoices where id = p_invoice_id;
end;
$$;

create or replace function public.purge_shop_order_financial_artifacts(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_invoice_id bigint;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id;

  if v_order.id is null then
    return;
  end if;

  v_invoice_id := v_order.global_invoice_id;

  if v_invoice_id is null and v_order.shop_type_snapshot = 'dropship' then
    select i.id into v_invoice_id
    from public.global_invoices i
    where i.tenant_id = v_order.tenant_id
      and i.invoice_no = 'INV-DS-' || v_order.order_no
      and not exists (
        select 1
        from public.shop_orders o2
        where o2.global_invoice_id = i.id
          and o2.id <> v_order.id
      )
    order by i.id desc
    limit 1;
  end if;

  if v_invoice_id is not null then
    select * into v_invoice from public.global_invoices where id = v_invoice_id;
  end if;

  delete from public.courier_remittance_items
  where shop_order_id = p_order_id;

  perform public.purge_shop_order_wallet_ledger(
    p_order_id => p_order_id,
    p_tenant_id => v_order.tenant_id,
    p_order_no => v_order.order_no,
    p_invoice_id => v_invoice_id,
    p_invoice_no => v_invoice.invoice_no
  );

  if v_invoice_id is not null then
    perform public.purge_shop_order_invoice(v_invoice_id);
  end if;
end;
$$;

create or replace function public.delete_shop_order(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_item record;
  v_allocation_id bigint;
  v_stock_id bigint;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'Access denied';
  end if;

  if v_order.status = 'fulfilled' then
    raise exception 'Cannot delete a fulfilled order';
  end if;

  if exists (
    select 1
    from public.shop_orders o
    where o.replacement_of_order_id = p_order_id
  ) then
    raise exception 'Cannot delete order: a replacement order references it';
  end if;

  perform public.purge_shop_order_financial_artifacts(p_order_id);

  for v_item in select * from public.shop_order_items where order_id = p_order_id loop
    v_allocation_id := v_item.global_stock_allocation_id;
    v_stock_id := v_item.global_stock_id;

    if v_item.product_id is not null then
      update public.shop_product_listings
      set display_quantity_override = display_quantity_override + v_item.quantity
      where shop_id = v_order.shop_id
        and product_id = v_item.product_id
        and (v_allocation_id is null or global_stock_allocation_id = v_allocation_id)
        and display_quantity_override is not null;
    end if;

    if v_allocation_id is not null then
      update public.global_stock_allocations
      set quantity = quantity + v_item.quantity
      where id = v_allocation_id;
    end if;

    if v_stock_id is not null then
      update public.global_stocks
      set quantity = quantity + v_item.quantity
      where id = v_stock_id;
    end if;
  end loop;

  delete from public.shop_orders where id = p_order_id;
end;
$$;

grant execute on function public.delete_shop_order(bigint) to authenticated;

commit;
