-- BP17: wholesale stock commit before kernel issue (warehouse orchestration).

CREATE OR REPLACE FUNCTION public._bill_line_global_stock_id(p_line public.bill_lines)
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(
    nullif(p_line.line_meta->'stock_ref'->>'global_stock_id', '')::bigint,
    p_line.global_stock_id
  );
$$;

CREATE OR REPLACE FUNCTION public.commit_wholesale_bill_stock(p_bill_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_invoice public.bills;
  v_db_item public.bill_lines%rowtype;
  v_stock_id bigint;
  v_qty integer;
  v_stock record;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_has_stock boolean := false;
begin
  select * into v_invoice from public.bills where id = p_bill_id for update;
  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'Only draft or proforma invoices can commit stock';
  end if;

  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

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

  select exists (
    select 1
    from public.bill_lines bl
    where bl.invoice_id = p_bill_id
      and public._bill_line_global_stock_id(bl) is not null
  ) into v_has_stock;

  if not v_has_stock then
    return null;
  end if;

  v_mov_no := 'MOV-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

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
    'Issued Wholesale Invoice #' || coalesce(v_invoice.invoice_no, p_bill_id::text),
    public.current_user_email(),
    true,
    now()
  ) returning id into v_mov_id;

  for v_db_item in select * from public.bill_lines where invoice_id = p_bill_id loop
    v_stock_id := public._bill_line_global_stock_id(v_db_item);
    if v_stock_id is null then
      continue;
    end if;

    v_qty := ceil(v_db_item.quantity)::integer;

    select * into v_stock from public.global_stocks where id = v_stock_id for update;
    if v_stock.id is null then
      raise exception 'Stock % not found for line %', v_stock_id, v_db_item.name_snapshot;
    end if;
    if v_stock.quantity < v_qty then
      raise exception 'Insufficient stock for % (requested %, available %)', v_db_item.name_snapshot, v_qty, v_stock.quantity;
    end if;

    update public.global_stocks
    set quantity = quantity - v_qty
    where id = v_stock_id;

    insert into public.stock_movement_lines (
      movement_id,
      stock_id,
      quantity,
      from_location_id,
      to_location_id,
      from_availability,
      to_availability
    ) values (
      v_mov_id,
      v_stock_id,
      v_qty,
      v_stock.location_id,
      v_stock.location_id,
      v_stock.availability,
      v_stock.availability
    );
  end loop;

  return v_mov_id;
end;
$$;

GRANT EXECUTE ON FUNCTION public.commit_wholesale_bill_stock(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._bill_line_global_stock_id(public.bill_lines) TO authenticated, service_role;
