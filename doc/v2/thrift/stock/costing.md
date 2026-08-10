# Thrift Costing Engine — Landed Cost & Markup

> Dual-phase: UI `computeThriftUnitCosts`; SQL `compute_thrift_landed_unit_cost` authoritative at **report time** (live join via invoice line `stock_id`). Invoice create stubs line cost/profit to `0`.

See [rpc/compute_thrift_landed_unit_cost.md](./rpc/compute_thrift_landed_unit_cost.md) · golden: [fixtures/](./fixtures/).

## Landed unit cost (summary)

```
    product_unit_cost = (origin + extra_origin) * product_fx
    shipment_cargo = cargo_kg * cargo_rate * cargo_fx
    costing_qty = 1 when status=SOLD and quantity=0, else max(quantity, 0)
    U = sum(costing_qty) over shipment stocks (at least 1)
    ops = hand_tag*U + sticker*U + labor + transport + washing
    cargo_share = weight-based if total_weight_kg > 0 else equal split
    landed = product_unit_cost + cargo_share + ops/U + additional_charges
```

Weights on stock are **grams**. Suggested sell uses retail ceil (50/90) × markup.

Sold units keep costable rows (soft-delete archive, not hard delete) so report-time COGS stays joinable.
