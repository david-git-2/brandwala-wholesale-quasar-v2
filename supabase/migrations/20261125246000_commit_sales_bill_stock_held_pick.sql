-- Catalog issue: deduct held pick lot, not sellable line global_stock_id.

CREATE OR REPLACE FUNCTION public.commit_sales_bill_stock(p_bill_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, money_kernel
AS $$
declare
  v_invoice public.bills;
  v_kernel money_kernel.bills;
  v_db_item public.bill_lines%rowtype;
  v_kline money_kernel.bill_lines%rowtype;
  v_stock_id bigint;
  v_qty integer;
  v_stock record;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_has_stock boolean := false;
  v_line_label text;
  v_is_dropship boolean := false;
  v_use_kernel boolean := false;
  v_pick_id bigint;
  v_held_stock_id bigint;
begin
  select * into v_kernel from money_kernel.bills where id = p_bill_id for update;

  if found then
    v_use_kernel := true;
    if v_kernel.status not in ('draft') then
      raise exception 'Only draft bills can commit stock';
    end if;

    v_parent_id := v_kernel.tenant_id;
    v_is_dropship := v_kernel.kind = 'sales_invoice_dropship';
  else
    select * into v_invoice from public.bills where id = p_bill_id for update;
    if not found then
      raise exception 'Invoice not found';
    end if;

    if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
      raise exception 'Only draft or proforma invoices can commit stock';
    end if;

    v_parent_id := coalesce(v_invoice.tenant_id, v_invoice.issued_by_tenant_id);
    v_is_dropship := v_invoice.invoice_type = 'dropship'::public.global_invoice_type;
  end if;

  select sm.id
  into v_mov_id
  from public.stock_movements sm
  where sm.reference_type = 'sales_invoice'
    and sm.reference_id = p_bill_id::text
    and sm.is_posted = true
  order by sm.id desc
  limit 1;

  if v_mov_id is not null then
    return v_mov_id;
  end if;

  if not v_use_kernel then
    select exists (
      select 1
      from public.bill_lines bl
      where bl.invoice_id = p_bill_id
        and public._bill_line_global_stock_id(bl) is not null
    ) into v_has_stock;
  else
    select exists (
      select 1
      from money_kernel.bill_lines bl
      where bl.bill_id = p_bill_id
        and bl.global_stock_id is not null
    ) into v_has_stock;
  end if;

  if not v_has_stock then
    return null;
  end if;

  v_mov_no := public.next_stock_movement_number(v_parent_id, 'stock_movement');

  insert into public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) values (
    v_parent_id,
    v_mov_no,
    'adjustment'::public.stock_movement_type,
    'sales_invoice',
    p_bill_id::text,
    'Issued sales invoice #' || coalesce(
      case when v_use_kernel then v_kernel.invoice_no else v_invoice.invoice_no end,
      p_bill_id::text
    ),
    public.current_user_email(),
    true,
    now()
  ) returning id into v_mov_id;

  if not v_use_kernel then
    for v_db_item in select * from public.bill_lines where invoice_id = p_bill_id loop
      v_stock_id := public._bill_line_global_stock_id(v_db_item);
      if v_stock_id is null then
        continue;
      end if;

      v_qty := ceil(v_db_item.quantity)::integer;
      v_line_label := v_db_item.name_snapshot;

      select * into v_stock from public.global_stocks where id = v_stock_id for update;
      if v_stock.id is null then
        raise exception 'Stock % not found for line %', v_stock_id, v_line_label;
      end if;

      if v_is_dropship and v_stock.availability <> 'held'::public.stock_availability then
        raise exception 'dropship invoice stock % must be held before issue', v_stock_id;
      end if;

      if v_stock.quantity < v_qty then
        raise exception 'Insufficient stock for % (requested %, available %)', v_line_label, v_qty, v_stock.quantity;
      end if;

      update public.global_stocks
      set quantity = quantity - v_qty
      where id = v_stock_id;

      insert into public.stock_movement_lines (
        movement_id, stock_id, quantity,
        from_location_id, to_location_id, from_availability, to_availability
      ) values (
        v_mov_id, v_stock_id, v_qty,
        v_stock.location_id, v_stock.location_id,
        v_stock.availability, v_stock.availability
      );
    end loop;
  else
    for v_kline in
      select * from money_kernel.bill_lines
      where bill_id = p_bill_id and global_stock_id is not null
    loop
      v_qty := ceil(v_kline.quantity)::integer;
      v_line_label := coalesce(v_kline.description, 'Line');
      v_stock_id := v_kline.global_stock_id;
      v_pick_id := nullif(coalesce(v_kline.meta->>'shop_order_item_stock_pick_id', ''), '')::bigint;
      v_held_stock_id := null;

      if v_pick_id is not null then
        select sp.held_stock_id
        into v_held_stock_id
        from public.shop_order_item_stock_picks sp
        where sp.id = v_pick_id;

        if v_held_stock_id is not null then
          v_stock_id := v_held_stock_id;
        else
          raise exception 'Catalog pick % has no held stock for line %', v_pick_id, v_line_label;
        end if;
      end if;

      if v_stock_id is null then
        continue;
      end if;

      select * into v_stock from public.global_stocks where id = v_stock_id for update;
      if v_stock.id is null then
        raise exception 'Stock % not found for line %', v_stock_id, v_line_label;
      end if;

      if v_is_dropship and v_stock.availability <> 'held'::public.stock_availability then
        raise exception 'dropship invoice stock % must be held before issue', v_stock_id;
      end if;

      if v_stock.quantity < v_qty then
        raise exception 'Insufficient stock for % (requested %, available %)', v_line_label, v_qty, v_stock.quantity;
      end if;

      update public.global_stocks
      set quantity = quantity - v_qty
      where id = v_stock_id;

      insert into public.stock_movement_lines (
        movement_id, stock_id, quantity,
        from_location_id, to_location_id, from_availability, to_availability
      ) values (
        v_mov_id, v_stock_id, v_qty,
        v_stock.location_id, v_stock.location_id,
        v_stock.availability, v_stock.availability
      );
    end loop;
  end if;

  return v_mov_id;
end;
$$;
