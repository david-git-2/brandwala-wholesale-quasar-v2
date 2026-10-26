-- bill_lines.global_stock_id was NOT NULL; ON DELETE SET NULL on purge failed (23502).

alter table public.bill_lines
  alter column global_stock_id drop not null;

alter table public.sales_return_items
  alter column global_stock_id drop not null;

CREATE OR REPLACE FUNCTION "public"."purge_archived_shipment"("p_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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

  delete from public.shop_order_item_stock_picks sp
  where sp.shipment_id = p_id
     or sp.shipment_item_id in (
       select id from public.global_shipment_items where shipment_id = p_id
     )
     or sp.global_stock_id in (
       select gs.id
       from public.global_stocks gs
       inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
       where gsi.shipment_id = p_id
     )
     or sp.held_stock_id in (
       select gs.id
       from public.global_stocks gs
       inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
       where gsi.shipment_id = p_id
     );

  update public.bill_lines bl
  set
    global_stock_id = null,
    shipment_item_id = null,
    updated_at = now()
  where bl.shipment_item_id in (
    select id from public.global_shipment_items where shipment_id = p_id
  )
  or bl.global_stock_id in (
    select gs.id
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where gsi.shipment_id = p_id
  );

  update public.sales_return_items sri
  set
    global_stock_id = null,
    updated_at = now()
  where sri.global_stock_id in (
    select gs.id
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where gsi.shipment_id = p_id
  );

  delete from public.global_shipments where id = p_id;
end;
$$;
