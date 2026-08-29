-- Migration: 20270832000100_fix_purge_archived_shipment.sql
-- Description: Fixes purge_archived_shipment failing with 'column shipment_id does not exist' by removing explicit child deletes and relying on native ON DELETE CASCADE constraints.

begin;

CREATE OR REPLACE FUNCTION public.purge_archived_shipment(p_id bigint) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.is_archived is not true then
    raise exception 'shipment must be archived before it can be permanently deleted';
  end if;

  -- Only draft and cancelled shipments can be permanently deleted
  if v_ship.status not in ('draft', 'cancelled') then
    raise exception 'shipment in status % cannot be deleted; only archived draft or cancelled shipments may be purged', v_ship.status;
  end if;

  -- Verify no physical stock was ever created for this shipment
  if exists (
    select 1
    from public.global_stocks gs
    where gs.shipment_item_id in (
      select id from public.global_shipment_items where shipment_id = p_id
    )
  ) or v_ship.stock_ready = true then
    raise exception 'cannot delete shipment: physical inventory records exist for this shipment';
  end if;

  -- Delete the global shipment record.
  -- Child records (items, sections, boxes, cost entries, investments) will be deleted
  -- automatically via ON DELETE CASCADE constraints on their foreign keys.
  delete from public.global_shipments where id = p_id;
end;
$$;

ALTER FUNCTION public.purge_archived_shipment(bigint) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.purge_archived_shipment(bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.purge_archived_shipment(bigint) TO authenticated;

commit;
