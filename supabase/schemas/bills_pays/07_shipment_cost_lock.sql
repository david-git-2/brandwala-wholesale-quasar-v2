-- Procurement: lock shipment costs → sync AP → issue AP (calls bills_pays adapters).

CREATE OR REPLACE FUNCTION public.lock_global_shipment_costs(p_shipment_id bigint)
RETURNS public.global_shipments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_books_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.status not in ('in_transit', 'received') then
    raise exception 'Set shipment to in transit or received before locking costs';
  end if;

  if not public.global_shipment_stock_is_posted(v_ship) then
    raise exception 'shipment stock is not posted; receive before locking costs';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are already locked';
  end if;

  perform set_config('app.allow_costs_lock', '1', true);

  update public.global_shipments
  set costs_locked = true,
      costs_locked_at = now(),
      costs_locked_by = auth.uid(),
      updated_at = now()
  where id = p_shipment_id
  returning * into v_ship;

  perform public.issue_shipment_ap_drafts_v2(p_shipment_id);

  return v_ship;
end;
$$;
