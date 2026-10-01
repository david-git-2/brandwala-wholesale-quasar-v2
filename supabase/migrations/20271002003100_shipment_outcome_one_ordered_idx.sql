-- One paper (ordered) outcome per shipment line.

create unique index if not exists global_shipment_item_outcomes_one_ordered_idx
  on public.global_shipment_item_outcomes (shipment_item_id)
  where reason = 'ordered';
