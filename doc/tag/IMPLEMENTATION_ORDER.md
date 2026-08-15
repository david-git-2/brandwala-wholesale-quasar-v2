# Tag catalog — Implementation Order

Spec: [UNIVERSAL_TAGGING_SYSTEM.md](./UNIVERSAL_TAGGING_SYSTEM.md) · [schema.md](./schema.md) · [presets.md](./presets.md)

Platform foundation — build **before** stock `grade_tag_id` (procurement T3 depends on T1).

---

## 🔜 Phases

| # | Focus | Outcome | Status |
|:-:|:---|:---|:---:|
| **T1** | Categories + seed | `tag_categories`; normalize `tags`; seed `stock_grade` (warehouse/produce/clothing) + `color`; system read-only for tenants | ✅ Done |
| **T2** | Shipment progress | Move progress tags under `module_key = shipment_progress`; keep denorm `progress_tag_id` | |
| **T3** | Stock grade FK | Same as procurement **W7** — `global_stocks.grade_tag_id`; receive → `standard`; movements change grade — [../procurement_stock/IMPLEMENTATION_ORDER.md](../procurement_stock/IMPLEMENTATION_ORDER.md). After W7: W8 organize-by-shipment, W9 return inbound. | 🔜 Next (W7) |
| **T4** | Color + shop/sale | Product primary color FK; shop/sale category via `entity_tags` | |

---

## ⏸ Later

| Item | Notes |
| :--- | :--- |
| Tenant-custom categories/tags | Shop campaigns, local progress rename |
| Platform admin UI for seeds | Until then: SQL seed migrations only |
| Wallet expense tags | Promote ledger `metadata` → `entity_tags` |

---

## Agent rule

Work **one row** (T1, T2, …) per session. Read canon for that row; stop after review.
