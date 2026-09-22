-- Replace global_shipment_boxes.weight_kg with received_weight + shipping_weight (kg)
-- Idempotent: safe if weight_kg was already dropped (partial apply / re-run).
begin;

alter table public.global_shipment_boxes
  add column if not exists received_weight numeric,
  add column if not exists shipping_weight numeric;

do $migrate$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'global_shipment_boxes'
      and column_name = 'weight_kg'
  ) then
    update public.global_shipment_boxes
    set
      received_weight = coalesce(received_weight, weight_kg),
      shipping_weight = coalesce(shipping_weight, weight_kg);
  end if;
end
$migrate$;

update public.global_shipment_boxes
set
  received_weight = coalesce(received_weight, 0),
  shipping_weight = coalesce(shipping_weight, 0)
where received_weight is null
   or shipping_weight is null;

alter table public.global_shipment_boxes
  alter column received_weight set not null,
  alter column shipping_weight set not null;

alter table public.global_shipment_boxes
  drop constraint if exists global_shipment_boxes_weight_kg_check;

alter table public.global_shipment_boxes
  drop constraint if exists global_shipment_boxes_received_weight_check;

alter table public.global_shipment_boxes
  drop constraint if exists global_shipment_boxes_shipping_weight_check;

alter table public.global_shipment_boxes
  add constraint global_shipment_boxes_received_weight_check
    check (received_weight >= 0),
  add constraint global_shipment_boxes_shipping_weight_check
    check (shipping_weight >= 0);

alter table public.global_shipment_boxes
  drop column if exists weight_kg;

commit;
