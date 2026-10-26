-- Step 6: global return items with face/accounting split
begin;

alter table public.global_return_items
  add column if not exists return_face_amount numeric(12,2) not null default 0 check (return_face_amount >= 0),
  add column if not exists return_accounting_amount numeric(12,2) not null default 0 check (return_accounting_amount >= 0),
  add column if not exists return_charge_amount numeric(12,2) not null default 0 check (return_charge_amount >= 0);

create or replace function public.add_global_return_item(
  p_invoice_id bigint,
  p_invoice_item_id bigint,
  p_quantity numeric,
  p_return_charge_amount numeric default 0,
  p_note text default null
)
returns public.global_return_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items;
  v_row public.global_return_items;
  v_unit_face numeric(12,2);
  v_unit_accounting numeric(12,2);
  v_return_face numeric(12,2);
  v_return_accounting numeric(12,2);
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;

  select * into v_item from public.global_invoice_items where id = p_invoice_item_id and invoice_id = p_invoice_id;
  if v_item.id is null then raise exception 'invoice item not found'; end if;
  if p_quantity <= 0 or p_quantity > v_item.quantity then
    raise exception 'invalid return quantity';
  end if;

  v_unit_accounting := case when v_item.quantity > 0 then v_item.line_total_amount / v_item.quantity else 0 end;
  v_unit_face := case
    when v_item.quantity > 0 then coalesce(v_item.line_face_total_amount, v_item.line_total_amount) / v_item.quantity
    else 0
  end;

  v_return_accounting := round(v_unit_accounting * p_quantity, 2);
  v_return_face := round(v_unit_face * p_quantity, 2);

  insert into public.global_return_items (
    tenant_id, parent_tenant_id, invoice_id, invoice_item_id, global_stock_id,
    quantity, return_amount, return_face_amount, return_accounting_amount, return_charge_amount, note
  )
  values (
    v_invoice.tenant_id, v_invoice.parent_tenant_id, p_invoice_id, p_invoice_item_id, v_item.global_stock_id,
    p_quantity, v_return_face, v_return_face, v_return_accounting,
    greatest(coalesce(p_return_charge_amount, 0), 0), nullif(trim(coalesce(p_note, '')), '')
  )
  returning * into v_row;

  update public.global_stock_quantities
  set quantity = quantity + ceil(p_quantity)::integer
  where stock_id = v_item.global_stock_id and status = 'excellent';

  update public.global_invoices
  set
    subtotal_amount = greatest(subtotal_amount - v_return_accounting, 0),
    total_amount = greatest(total_amount - v_return_face - greatest(coalesce(p_return_charge_amount, 0), 0), 0),
    due_amount = greatest(total_amount - paid_amount, 0),
    updated_at = now()
  where id = p_invoice_id;

  perform public.recompute_global_invoice_totals(p_invoice_id);
  perform public.recompute_global_invoice_payment_status(p_invoice_id);

  return v_row;
end;
$$;

grant execute on function public.add_global_return_item(bigint, bigint, numeric, numeric, text) to authenticated;

commit;
