-- Remove shipment_orders support and related RPC functions.
drop function if exists public.create_shipment_order(integer, integer);
drop function if exists public.update_shipment_order(integer, integer, integer);
drop function if exists public.delete_shipment_order(integer);

drop table if exists public.shipment_orders cascade;
