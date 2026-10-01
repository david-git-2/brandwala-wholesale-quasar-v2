-- Table exists from 20271001150000; GRANT may not have run on already-applied DBs.
grant all on table public.global_shipment_item_outcomes to authenticated;
grant all on table public.global_shipment_item_outcomes to service_role;
grant all on sequence public.global_shipment_item_outcomes_id_seq to authenticated;
grant all on sequence public.global_shipment_item_outcomes_id_seq to service_role;

grant all on table public.global_shipment_local_costs to authenticated;
grant all on table public.global_shipment_local_costs to service_role;
grant all on sequence public.global_shipment_local_costs_id_seq to authenticated;
grant all on sequence public.global_shipment_local_costs_id_seq to service_role;
