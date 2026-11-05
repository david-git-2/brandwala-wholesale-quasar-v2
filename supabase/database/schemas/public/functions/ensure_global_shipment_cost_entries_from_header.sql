CREATE FUNCTION public.ensure_global_shipment_cost_entries_from_header (
  p_shipment_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_goods numeric;
  v_cargo_amt numeric;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if exists (
    select 1 from public.global_shipment_cost_entries e where e.shipment_id = p_shipment_id
  ) then
    return;
  end if;

  select coalesce(sum(gsi.purchase_price * gsi.ordered_quantity), 0)
  into v_goods
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  if v_ship.purchase_invoice_total is not null and v_ship.purchase_invoice_total > 0 then
    v_goods := v_ship.purchase_invoice_total;
  end if;

  v_cargo_amt := coalesce(v_ship.cargo_invoice_total, 0);

  insert into public.global_shipment_cost_entries (
    parent_tenant_id,
    shipment_id,
    cost_bucket,
    cost_component,
    is_capitalizable,
    amount,
    currency_id,
    metadata
  ) values (
    v_ship.parent_tenant_id,
    p_shipment_id,
    'material',
    'subtotal',
    true,
    greatest(v_goods, 0),
    v_ship.shipment_purchase_currency_id,
    jsonb_build_object('source', 'header_backfill')
  );

  if v_cargo_amt > 0 then
    insert into public.global_shipment_cost_entries (
      parent_tenant_id,
      shipment_id,
      cost_bucket,
      cost_component,
      is_capitalizable,
      amount,
      currency_id,
      metadata
    ) values (
      v_ship.parent_tenant_id,
      p_shipment_id,
      'freight',
      'subtotal',
      true,
      v_cargo_amt,
      v_ship.shipment_cost_currency_id,
      jsonb_build_object('source', 'header_backfill')
    );
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.ensure_global_shipment_cost_entries_from_header(bigint) TO anon;

GRANT ALL ON FUNCTION public.ensure_global_shipment_cost_entries_from_header(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.ensure_global_shipment_cost_entries_from_header(bigint) TO service_role;