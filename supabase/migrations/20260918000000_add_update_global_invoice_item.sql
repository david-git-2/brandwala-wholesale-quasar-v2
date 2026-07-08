begin;

create or replace function public.update_global_invoice_item(
  p_item_id bigint,
  p_quantity numeric,
  p_sell_price_amount numeric,
  p_recipient_price_amount numeric default null
)
returns public.global_invoice_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.global_invoice_items;
  v_invoice public.global_invoices;
  v_recipient_price numeric;
  v_line_total numeric;
  v_line_face_total numeric;
begin
  select * into v_item from public.global_invoice_items where id = p_item_id;
  if v_item.id is null then raise exception 'Invoice item not found'; end if;

  select * into v_invoice from public.global_invoices where id = v_item.invoice_id;
  if v_invoice.id is null then raise exception 'Invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'Cannot edit items on a non-draft invoice';
  end if;

  if p_quantity <= 0 then
    raise exception 'Quantity must be greater than 0';
  end if;

  if p_sell_price_amount < 0 then
    raise exception 'Sell price cannot be negative';
  end if;

  -- Resolve recipient price
  if v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
    v_recipient_price := coalesce(p_recipient_price_amount, p_sell_price_amount);
  else
    v_recipient_price := p_sell_price_amount;
  end if;

  if v_recipient_price < 0 then
    raise exception 'Recipient price cannot be negative';
  end if;

  v_line_total := greatest((p_quantity * p_sell_price_amount) - coalesce(v_item.line_discount_amount, 0.00), 0.00);
  v_line_face_total := greatest((p_quantity * v_recipient_price) - coalesce(v_item.line_discount_amount, 0.00), 0.00);

  update public.global_invoice_items
  set
    quantity = p_quantity,
    sell_price_amount = p_sell_price_amount,
    recipient_price_amount = v_recipient_price,
    line_total_amount = v_line_total,
    line_face_total_amount = v_line_face_total
  where id = p_item_id
  returning * into v_item;

  perform public.recompute_global_invoice_totals(v_item.invoice_id);

  return v_item;
end;
$$;

grant execute on function public.update_global_invoice_item(bigint, numeric, numeric, numeric) to authenticated;

commit;
