# Procurement & Stock — Implementation Order

Simple build sequence for this module. Spec detail lives in linked docs — not duplicated here.

**Canon:** [PROCUREMENT_STOCK.md](./PROCUREMENT_STOCK.md) · [stock/schema.md](./stock/schema.md) · [shipment/schema.md](./shipment/schema.md) · [PROCUREMENT_STOCK_ISSUES.md](./PROCUREMENT_STOCK_ISSUES.md) · grades: [tag/presets.md](../tag/presets.md)

---

## ✅ Done — Shipment inbound (7A–14B)

One vendor/shipment · cost entries + stamp · status lifecycle · assign to child · shared ATP · locations column · movements RPC · pay/settle · vendor return · shop + desk ATP cutover.

Prod: `20270814000100` + `20270814000210`.

Thrift shared engine (**7C**) — separate vertical, not in this track.

---

## ✅ Done — Warehouse & stock (W1–W6)

| # | Focus | Outcome |
|:-:|:---|:---|
| **W1** ✅ | **Movement UX** | `StockMovementsPage`: correct `sellable \| held \| unsellable` enum, from/to location, from/to availability, movement detail + post flow |
| **W2** ✅ | **Receive put-away** | `ReceiveShipmentDialog` + finalize: pick leaf `location_id` (default or per split); wire `receive_putaway` *(superseded UX → **W6**)* |
| **W3** ✅ | **Warehouse list ops** | `WarehouseStockListPage`: filter by location, row actions → draft movement (transfer / availability change) |
| **W4** ✅ | **Stock grain cutover** | Migrate balances from `stock_type_id` rows → `(shipment_item_id, availability, location_id)` unique grain |
| **W5** ✅ | **Allocation retirement** | Drop soft-qty sell path: listings + cart on `global_stock_id` only; retire `AllocateStockPage` when assign + ATP suffices |
| **W6** ✅ | **Receive qty checklist + `received_quantity`** | Checklist UI (image, name, ordered, received). Persist `shipment_items.received_quantity` on finalize; post that qty as `sellable` @ default location. |

---

## ✅ Done — Tag catalog (platform T1)

System `stock_grade` + `color` seeds + list RPCs. Tenants select only. See [tag/IMPLEMENTATION_ORDER.md](../tag/IMPLEMENTATION_ORDER.md).

---

## 🔜 Next — Stock grades (W7)

Two layers stay separate:

| Layer | Values | Role |
|:---|:---|:---|
| **Sell gate** | `sellable` \| `held` \| `unsellable` | ATP — already live |
| **Grade** | tag FK → `stock_grade` catalog | Condition class on the balance row |

**Warehouse preset grades** (system tags — keep these):

| slug | Typical availability |
|:---|:---|
| `standard` | sellable (receive default) |
| `open_box` | sellable |
| `box_damage` | sellable |
| `box_less` | sellable |
| `badly_damaged` | unsellable |

Produce / clothing presets exist in seed for other verticals; BrandWala day one uses **warehouse**.

| # | Focus | Outcome |
|:-:|:---|:---|
| **W7a** | **Column + grain** | Add `global_stocks.grade_tag_id` → `tags.id`. Unique grain → `(shipment_item_id, availability, location_id, grade_tag_id)`. Backfill existing rows to warehouse `standard`. |
| **W7b** | **Receive posts grade** | Finalize / receive checklist posts `sellable` + `standard` (+ default location). No grade picker on receive. |
| **W7c** | **Movements change grade** | Availability and/or grade transfers via movements (e.g. standard → open_box staying sellable; or → badly_damaged + unsellable). Warehouse list shows grade. |

Spec: [stock/schema.md](./stock/schema.md) · [stock/workflow_flow.md](./stock/workflow_flow.md) · [tag/presets.md](../tag/presets.md)

---

## ⏸ Later (explicit defer)

| Item | Notes |
|:---|:---|
| Partial receive cost share | Fair stamp when batch arrives in parts (multi-wave) |
| Weight / cost input audit | History on package weight revisions |
| Multi-warehouse / inter-site | Second site transfer |
| Multi-child assign (Option B) | One shipment → many children |
| Thrift → `shipment-engine` | Thrift vertical only |
| Tenant-custom grades | System warehouse/produce/clothing presets only |
| Grade-based auto pricing | No discount % on tags; pricing stays elsewhere |

---

## Agent rule

Work **one row** (W7a → W7b → W7c) per session. Read canon for that row; stop after review — do not stack phases.
