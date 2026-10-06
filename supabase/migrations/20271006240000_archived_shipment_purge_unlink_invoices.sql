-- Purge any archived shipment; CASCADE stock; bill lines / returns / picks SET NULL on global_stock_id.

alter table public.bill_lines drop constraint if exists global_invoice_items_global_stock_id_fkey;
alter table public.bill_lines
  add constraint global_invoice_items_global_stock_id_fkey
  foreign key (global_stock_id) references public.global_stocks(id) on delete set null;

alter table public.sales_return_items drop constraint if exists global_return_items_global_stock_id_fkey;
alter table public.sales_return_items
  add constraint global_return_items_global_stock_id_fkey
  foreign key (global_stock_id) references public.global_stocks(id) on delete set null;

alter table public.shop_order_item_stock_picks drop constraint if exists shop_order_item_stock_picks_global_stock_id_fkey;
alter table public.shop_order_item_stock_picks
  add constraint shop_order_item_stock_picks_global_stock_id_fkey
  foreign key (global_stock_id) references public.global_stocks(id) on delete set null;

alter table public.shop_order_item_stock_picks drop constraint if exists shop_order_item_stock_picks_held_stock_id_fkey;
alter table public.shop_order_item_stock_picks
  add constraint shop_order_item_stock_picks_held_stock_id_fkey
  foreign key (held_stock_id) references public.global_stocks(id) on delete set null;

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

  delete from public.global_shipments where id = p_id;
end;
$$;
