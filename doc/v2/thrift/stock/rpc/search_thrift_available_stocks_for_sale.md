# RPC: `search_thrift_available_stocks_for_sale`

Single round-trip POS stock picker for thrift sales create.

Replaces the old client pattern (stocks search + settings + shipment lean stocks).

Permission: `thrift_sales` create/view **or** `thrift_stock` view.  
Landed cost: [`compute_thrift_landed_unit_cost`](./compute_thrift_landed_unit_cost.md).

Domain: [../workflow.md](../workflow.md) · [../schema.md](../schema.md).

## Args

| Arg | Type | Required | Notes |
| :--- | :--- | :---: | :--- |
| `p_tenant_id` | bigint | Yes | |
| `p_search` | text | Yes* | Empty → `[]` |
| `p_customer_phone` | text | No | Digits-normalized; includes matching `RESERVED` holds |
| `p_limit` | int | No | Default 50, max 100 |

## Behaviour

1. Match `AVAILABLE` stocks (and hold-matching `RESERVED` when phone present) by name / barcode / brand / color / size.  
2. Exclude soft-deleted (`deleted_at`).  
3. Per row: `landed_cost` via `compute_thrift_landed_unit_cost`; `default_sell_price` matches shipment `resolveListedSellPrice`:
   - if `is_listed_price_manual` → `listed_unit_price`
   - else → `ceil_thrift_retail_price(landed * (1 + coalesce(markup_rate_override, shipment.default_markup_rate, 0)))` (same endings as web `ceilThriftRetailPrice`: 50 / 90)
4. Return JSON array (snake_case keys).

## Call

```ts
await supabase.rpc('search_thrift_available_stocks_for_sale', {
  p_tenant_id: tenantId,
  p_search: query,
  p_customer_phone: phone ?? null,
  p_limit: 50,
})
```
