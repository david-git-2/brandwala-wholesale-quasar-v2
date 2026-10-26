-- Lots keyed by outcome_id; backfill synthetic general extras for existing stock rows.

do $$
declare
  r record;
  v_outcome_id bigint;
  v_kind public.global_shipment_outcome_kind;
begin
  for r in
    select gs.*, gsi.purchase_price, gsi.landed_cost_bdt
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where gs.outcome_id is null
  loop
    v_kind := case
      when r.availability = 'sellable'::public.stock_availability then 'sellable'::public.global_shipment_outcome_kind
      else 'unsellable'::public.global_shipment_outcome_kind
    end;

    insert into public.global_shipment_item_outcomes (
      parent_tenant_id,
      shipment_item_id,
      quantity,
      kind,
      reason,
      purchase_price,
      cost
    ) values (
      r.parent_tenant_id,
      r.shipment_item_id,
      r.quantity,
      v_kind,
      'general'::public.global_shipment_outcome_reason,
      coalesce(r.purchase_price, 0),
      r.landed_cost_bdt
    )
    returning id into v_outcome_id;

    update public.global_stocks
    set outcome_id = v_outcome_id
    where id = r.id;
  end loop;
end $$;

alter table public.global_stocks drop constraint if exists global_stocks_grain_unique;

alter table public.global_stocks
  add constraint global_stocks_outcome_grain_unique
  unique (outcome_id, availability, location_id, grade_tag_id);

comment on constraint global_stocks_outcome_grain_unique on public.global_stocks is
  'One lot row per outcome × availability × bin × grade (US-7).';
