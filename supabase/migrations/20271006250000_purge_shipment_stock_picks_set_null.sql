-- Allow purge_archived_shipment: order stock picks keep row but lose shipment refs.

alter table public.shop_order_item_stock_picks
  drop constraint if exists shop_order_item_stock_picks_shipment_id_fkey;
alter table public.shop_order_item_stock_picks
  add constraint shop_order_item_stock_picks_shipment_id_fkey
  foreign key (shipment_id) references public.global_shipments(id) on delete set null;

alter table public.shop_order_item_stock_picks
  drop constraint if exists shop_order_item_stock_picks_shipment_item_id_fkey;
alter table public.shop_order_item_stock_picks
  add constraint shop_order_item_stock_picks_shipment_item_id_fkey
  foreign key (shipment_item_id) references public.global_shipment_items(id) on delete set null;
