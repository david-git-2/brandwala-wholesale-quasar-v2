-- Remove a vendor credit financial record (no stock / outcome changes).

create or replace function public.delete_shipment_outcome_vendor_credit(p_credit_id bigint)
returns void
language plpgsql
security definer
set search_path to public
as $$
declare
  v_credit public.global_shipment_outcome_vendor_credits%rowtype;
  v_ship public.global_shipments%rowtype;
begin
  if p_credit_id is null then
    raise exception 'credit id required';
  end if;

  select * into v_credit
  from public.global_shipment_outcome_vendor_credits
  where id = p_credit_id;

  if not found then
    raise exception 'vendor credit not found';
  end if;

  select * into v_ship
  from public.global_shipments
  where id = v_credit.shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.status = 'cancelled' then
    raise exception 'shipment is cancelled';
  end if;

  if coalesce(v_ship.is_closed, false) then
    raise exception 'shipment is closed';
  end if;

  if v_ship.status <> 'received' then
    raise exception 'shipment must be received to remove vendor credit';
  end if;

  delete from public.global_shipment_outcome_vendor_credits
  where id = p_credit_id;
end;
$$;

grant execute on function public.delete_shipment_outcome_vendor_credit(bigint) to authenticated;
