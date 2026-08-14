# Procurement & Stock — Implementation Order

Simple build sequence for this module. Spec detail lives in linked docs — not duplicated here.

**Canon:** [PROCUREMENT_STOCK.md](./PROCUREMENT_STOCK.md) · [stock/schema.md](./stock/schema.md) · [shipment/schema.md](./shipment/schema.md) · [PROCUREMENT_STOCK_ISSUES.md](./PROCUREMENT_STOCK_ISSUES.md)

---

## ✅ Done — Shipment inbound (7A–14B)

One vendor/shipment · cost entries + stamp · status lifecycle · assign to child · shared ATP · locations column · movements RPC · pay/settle · vendor return · shop + desk ATP cutover.

Prod: `20270814000100` + `20270814000210`.

Thrift shared engine (**7C**) — separate vertical, not in this track.

---

## 🔜 Next — Warehouse & stock (do in order)

| # | Focus | Outcome |
|:-:|:---|:---|
| **W1** ✅ | **Movement UX** | `StockMovementsPage`: correct `sellable \| held \| unsellable` enum, from/to location, from/to availability, movement detail + post flow |
| **W2** ✅ | **Receive put-away** | `ReceiveShipmentDialog` + finalize: pick leaf `location_id` (default or per split); wire `receive_putaway` |
| **W3** ✅ | **Warehouse list ops** | `WarehouseStockListPage`: filter by location, row actions → draft movement (transfer / availability change) |
| **W4** ✅ | **Stock grain cutover** | Migrate balances from `stock_type_id` rows → `(shipment_item_id, availability, location_id)` unique grain |
| **W5** ✅ | **Allocation retirement** | Drop soft-qty sell path: listings + cart on `global_stock_id` only; retire `AllocateStockPage` when assign + ATP suffices |

---

## ⏸ Later (explicit defer)

| Item | Notes |
|:---|:---|
| Partial receive cost share | Fair stamp when batch arrives in parts |
| Weight / cost input audit | History on package weight revisions |
| Multi-warehouse / inter-site | Second site transfer |
| Multi-child assign (Option B) | One shipment → many children |
| Thrift → `shipment-engine` | Thrift vertical only |

---

## Agent rule

Work **one row** (W1, W2, …) per session. Read canon for that row; stop after review — do not stack phases.
