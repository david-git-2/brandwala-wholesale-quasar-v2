CREATE FUNCTION public.add_global_return_item (
  p_invoice_id               bigint,
  p_invoice_item_id          bigint,
  p_quantity                 numeric,
  p_return_face_amount       numeric,
  p_return_accounting_amount numeric,
  p_return_charge_amount     numeric                   DEFAULT 0,
  p_note                     text                      DEFAULT NULL::text,
  p_to_grade_tag_id          bigint                    DEFAULT NULL::bigint,
  p_to_availability          public.stock_availability DEFAULT 'held'::public.stock_availability
)
  RETURNS public.sales_return_items
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_invoice public.bills;
  v_item public.global_invoice_items;
  v_row public.global_return_items;
  v_parent bigint;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'cannot return items on a non-posted invoice';
  end if;

  select * into v_item from public.global_invoice_items where id = p_invoice_item_id for update;
  if v_item.id is null then raise exception 'invoice item not found'; end if;
  if v_item.invoice_id <> p_invoice_id then
    raise exception 'invoice item does not belong to the selected invoice';
  end if;

  if v_item.return_quantity + p_quantity > v_item.quantity then
    raise exception 'return quantity exceeds available item quantity';
  end if;

  insert into public.global_return_items (
    tenant_id,
    parent_tenant_id,
    invoice_id,
    invoice_item_id,
    global_stock_id,
    quantity,
    return_charge_amount,
    note
  )
  values (
    v_invoice.parent_tenant_id,
    v_invoice.parent_tenant_id,
    p_invoice_id,
    p_invoice_item_id,
    v_item.global_stock_id,
    p_quantity,
    coalesce(p_return_charge_amount, 0.00),
    nullif(trim(p_note), '')
  )
  returning * into v_row;

  update public.global_invoice_items
  set return_quantity = return_quantity + p_quantity
  where id = p_invoice_item_id;

  v_parent := coalesce(v_invoice.parent_tenant_id, public.resolve_parent_tenant_id(v_invoice.parent_tenant_id));

  if v_item.global_stock_id is not null then
    perform public.create_and_post_stock_movement(
      v_parent,
      v_item.global_stock_id,
      ceil(p_quantity)::integer,
      public.default_returns_stock_location_id(v_parent),
      coalesce(p_to_availability, 'held'::public.stock_availability),
      coalesce(p_to_grade_tag_id, public.default_stock_grade_tag_id()),
      'return_inbound'::public.stock_movement_type,
      coalesce(nullif(trim(p_note), ''), 'Invoice return'),
      'sales_invoice',
      p_invoice_id::text
    );
  end if;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$function$;

CREATE FUNCTION public.add_global_return_item (
  p_invoice_id           bigint,
  p_invoice_item_id      bigint,
  p_quantity             numeric,
  p_return_charge_amount numeric DEFAULT 0,
  p_note                 text    DEFAULT NULL::text
)
  RETURNS public.sales_return_items
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return public.add_global_return_item(
    p_invoice_id,
    p_invoice_item_id,
    p_quantity,
    0::numeric,
    0::numeric,
    p_return_charge_amount,
    p_note,
    null::bigint,
    'held'::public.stock_availability
  );
end;
$function$;

GRANT ALL ON FUNCTION public.add_global_return_item(bigint, bigint, numeric, numeric, numeric, numeric, text, bigint, public.stock_availability) TO anon;

GRANT ALL ON FUNCTION public.add_global_return_item(bigint, bigint, numeric, numeric, numeric, numeric, text, bigint, public.stock_availability) TO authenticated;

GRANT ALL ON FUNCTION public.add_global_return_item(bigint, bigint, numeric, numeric, numeric, numeric, text, bigint, public.stock_availability) TO service_role;

GRANT ALL ON FUNCTION public.add_global_return_item(bigint, bigint, numeric, numeric, text) TO anon;

GRANT ALL ON FUNCTION public.add_global_return_item(bigint, bigint, numeric, numeric, text) TO authenticated;

GRANT ALL ON FUNCTION public.add_global_return_item(bigint, bigint, numeric, numeric, text) TO service_role;