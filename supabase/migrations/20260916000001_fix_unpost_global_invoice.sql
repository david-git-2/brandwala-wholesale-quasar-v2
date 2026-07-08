begin;

create or replace function public.unpost_global_invoice(
  p_invoice_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items%rowtype;
  v_qty_to_restore integer;
begin
  -- Load and lock invoice
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'only posted invoices can be unposted';
  end if;
  
  if v_invoice.paid_amount > 0 then
    raise exception 'cannot unpost a paid or partially paid invoice; reverse collections/payments first';
  end if;

  if exists (select 1 from public.global_return_items where invoice_id = p_invoice_id) then
    raise exception 'cannot unpost an invoice with return items; remove return items first';
  end if;

  -- Restore stock quantities
  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_qty_to_restore := ceil(v_item.quantity)::integer;
    
    update public.global_stocks
    set quantity = quantity + v_qty_to_restore
    where id = v_item.global_stock_id;
    
    if exists (
      select 1 from public.global_stock_allocations
      where child_tenant_id = v_invoice.tenant_id and stock_id = v_item.global_stock_id
    ) then
      update public.global_stock_allocations
      set quantity = quantity + v_qty_to_restore
      where child_tenant_id = v_invoice.tenant_id and stock_id = v_item.global_stock_id;
    end if;

    -- Reset unit cost price snapshot to 0.00 since it is back to draft
    update public.global_invoice_items
    set unit_cost_price = 0.00
    where id = v_item.id;
  end loop;

  -- Mark invoice as draft
  update public.global_invoices
  set
    invoice_status = 'draft'::public.global_invoice_status
  where id = p_invoice_id;

  -- Recompute totals
  perform public.recompute_global_invoice_totals(p_invoice_id);
end;
$$;

commit;
