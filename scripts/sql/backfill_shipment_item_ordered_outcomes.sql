-- Backfill global_shipment_item_outcomes paper rows (reason = ordered).
--
-- Requires: migration 20271002003000_shipment_outcome_reason_ordered.sql (enum + unique index).
--
-- When to run:
--   • After that migration on local (`pnpm run backend:local`)
--   • On production after the same migration is applied
--
-- How to run on production:
--   Supabase Dashboard → SQL Editor → New query → paste this file → Run
--   Or: run section 1 first, then 2–3.
--
-- Safe to re-run:
--   • Remap skips lines that already have reason `ordered`
--   • Insert skips lines that already have reason `ordered`
-- Does not create received/general rows. Does not touch lots.

-- ---------------------------------------------------------------------------
-- 1. Preview (read-only)
-- ---------------------------------------------------------------------------
select
  count(*) as shipment_items,
  count(*) filter (
    where exists (
      select 1
      from public.global_shipment_item_outcomes o
      where o.shipment_item_id = i.id
        and o.reason = 'ordered'
    )
  ) as items_with_ordered,
  count(*) filter (
    where not exists (
      select 1
      from public.global_shipment_item_outcomes o
      where o.shipment_item_id = i.id
        and o.reason = 'ordered'
    )
  ) as items_missing_ordered,
  count(*) filter (
    where exists (
      select 1
      from public.global_shipment_item_outcomes o
      where o.shipment_item_id = i.id
        and o.reason = 'general'
    )
  ) as items_with_general
from public.global_shipment_items i;

select
  o.reason,
  count(*) as rows
from public.global_shipment_item_outcomes o
group by o.reason
order by o.reason;

-- ---------------------------------------------------------------------------
-- 2. Remap paper-shaped `general` rows → `ordered`
--    Only when qty + price match the line and the line has no ordered row yet.
-- ---------------------------------------------------------------------------
update public.global_shipment_item_outcomes o
set reason = 'ordered'
from public.global_shipment_items i
where o.shipment_item_id = i.id
  and o.reason = 'general'
  and o.quantity = i.ordered_quantity
  and o.purchase_price = i.purchase_price
  and not exists (
    select 1
    from public.global_shipment_item_outcomes x
    where x.shipment_item_id = i.id
      and x.reason = 'ordered'
  )
  and o.id = (
    select min(g.id)
    from public.global_shipment_item_outcomes g
    where g.shipment_item_id = i.id
      and g.reason = 'general'
      and g.quantity = i.ordered_quantity
      and g.purchase_price = i.purchase_price
  );

-- ---------------------------------------------------------------------------
-- 3. Insert `ordered` for every line that still has none
-- ---------------------------------------------------------------------------
insert into public.global_shipment_item_outcomes (
  parent_tenant_id,
  shipment_item_id,
  quantity,
  kind,
  reason,
  purchase_price,
  cost
)
select
  s.parent_tenant_id,
  i.id,
  i.ordered_quantity,
  'sellable'::public.global_shipment_outcome_kind,
  'ordered'::public.global_shipment_outcome_reason,
  coalesce(i.purchase_price, 0),
  i.landed_cost_bdt
from public.global_shipment_items i
join public.global_shipments s on s.id = i.shipment_id
where not exists (
  select 1
  from public.global_shipment_item_outcomes o
  where o.shipment_item_id = i.id
    and o.reason = 'ordered'
);

-- ---------------------------------------------------------------------------
-- 4. Verify
-- ---------------------------------------------------------------------------
select
  count(*) as shipment_items,
  count(*) filter (
    where exists (
      select 1
      from public.global_shipment_item_outcomes o
      where o.shipment_item_id = i.id
        and o.reason = 'ordered'
    )
  ) as items_with_ordered,
  count(*) filter (
    where not exists (
      select 1
      from public.global_shipment_item_outcomes o
      where o.shipment_item_id = i.id
        and o.reason = 'ordered'
    )
  ) as items_missing_ordered
from public.global_shipment_items i;
