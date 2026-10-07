-- Stock picks have NOT NULL shipment_id / global_stock_id; SET NULL on purge fails (23502).

alter table public.shop_order_item_stock_picks
  drop constraint if exists shop_order_item_stock_picks_global_stock_id_fkey;
alter table public.shop_order_item_stock_picks
  add constraint shop_order_item_stock_picks_global_stock_id_fkey
  foreign key (global_stock_id) references public.global_stocks(id) on delete cascade;

alter table public.shop_order_item_stock_picks
  drop constraint if exists shop_order_item_stock_picks_shipment_item_id_fkey;
alter table public.shop_order_item_stock_picks
  add constraint shop_order_item_stock_picks_shipment_item_id_fkey
  foreign key (shipment_item_id) references public.global_shipment_items(id) on delete cascade;

alter table public.shop_order_item_stock_picks
  drop constraint if exists shop_order_item_stock_picks_shipment_id_fkey;
alter table public.shop_order_item_stock_picks
  add constraint shop_order_item_stock_picks_shipment_id_fkey
  foreign key (shipment_id) references public.global_shipments(id) on delete cascade;

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

  delete from public.global_shipments where id = p_id;
end;
$$;
