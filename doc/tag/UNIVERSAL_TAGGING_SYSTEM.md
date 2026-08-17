# Universal Tag Catalog (v2)

> **Single Source of Truth** for Brandwala’s shared tag dictionary.  
> Schema: [schema.md](./schema.md) · Seeds: [presets.md](./presets.md) · Build order: [IMPLEMENTATION_ORDER.md](./IMPLEMENTATION_ORDER.md)

## 1. What this is

**Platform foundation** (not a sellable SKU). One catalog serves many consumers:

| Consumer | module_key examples | Role |
| :--- | :--- | :--- |
| Stock grade | `stock_grade` | Condition / price class on warehouse balances |
| Product color | `color` | Filter / display |
| Shop / sale category | `shop_category`, `sale_category` | Browse filters / stubs |
| Shipment progress | `shipment_progress` | Soft journey labels (lifecycle stays a column) |
| Wallet expense (later) | `expense` | Ledger classification only |

**Not** wallet identity, order/shipment lifecycle, permissions, or payment methods — see §4.

---

## 2. Control model (locked)

| Kind | `tenant_id` | Who edits | Day-one examples |
| :--- | :--- | :--- | :--- |
| **System** | `NULL` | **Platform superadmin only** (DB seed day one; optional platform UI later) | Stock grade presets, color palette |
| **Tenant custom** | set | Tenant admin (**later**) | Shop campaigns, local progress names |

**Day one for `stock_grade` + `color`:** seed only. Tenants **read and select** — they do **not** create/edit/delete those categories or tags.

---

## 3. Identity vs classification (locked)

| Job | Tool | Tags? |
| :--- | :--- | :---: |
| Money / access / lifecycle identity | FK, status enum, wallet | **Never** |
| Shared vocabulary / filters / grade **catalog** | `tag_categories` + `tags` | **Yes** |
| Stock **balance slice** (which grade this qty is) | `global_stocks.grade_tag_id` → `tags.id` | Catalog yes; **attachment = FK column** |
| Soft multi labels | `entity_tags` | **Yes** |

**Stock grade:** catalog = tags; ATP still = `availability` (`sellable` \| `held` \| `unsellable`). Tags never replace availability — [procurement stock schema](../procurement_stock/stock/schema.md).

---

## 4. Where **not** to use tags

| Domain | Use instead |
| :--- | :--- |
| Wallet / ledger **owner** | `entity_type` + `entity_id` |
| Order / remittance / shipment **lifecycle** | Status enums |
| Permissions / modules | Grant system |
| Payment method | Payment method tables |
| Stock sell gate (ATP) | `stock_availability` |
| Grade qty stored only as `text[]` / jsonb / M2M without FK | **Forbidden** for stock grade |

If removing the tag would break money or access control, it was never a tag.

---

## 5. Attachment matrix (locked)

| module_key | Cardinality | How stored on the entity |
| :--- | :--- | :--- |
| `stock_grade` | **single** | **`global_stocks.grade_tag_id` → tags.id`** (not array; not entity_tags-only) |
| `color` | **single** (primary) | Product FK → `tags.id` (preferred) or single entity_tags |
| `shop_category` / `sale_category` | **many** | `entity_tags` |
| `shipment_progress` | **single** | `entity_tags` + optional denorm `progress_tag_id` on shipment |

---

## 6. Vertical presets (stock grade)

Grades differ by **business type**, not free-form per tenant:

| Category `code` | Use |
| :--- | :--- |
| `warehouse` | Import / electronics-style (Standard, Open box, …) |
| `produce` | Fresh / seconds / waste |
| `clothing` | New / display / defect / return |

Parent (or tenant setting) selects **one** `stock_grade` category; stock rows reference tags from that category. Full seed lists: [presets.md](./presets.md).

---

## 7. Phasing

| Phase | Scope |
| :--- | :--- |
| **T1** | `tag_categories` + normalized `tags`; platform/seed; stock_grade + color seeds |
| **T2** | Align `shipment_progress` to categories |
| **T3** | `global_stocks.grade_tag_id` + unique grain + movements |
| **T4** | Product color + shop/sale filters |

Live bridge today: task-era `tags` + `entity_tags` + `group_name` (shipment progress). T1 migrates toward categories without breaking progress.

---

## 8. Related docs

| Doc | Relationship |
| :--- | :--- |
| [schema.md](./schema.md) | Tables, uniques, RLS sketch |
| [presets.md](./presets.md) | Seed lists |
| [IMPLEMENTATION_ORDER.md](./IMPLEMENTATION_ORDER.md) | Build sequence |
| [../procurement_stock/stock/schema.md](../procurement_stock/stock/schema.md) | Availability + grade FK |
| [../wallet/UNIVERSAL_WALLET_LEDGER.md](../wallet/UNIVERSAL_WALLET_LEDGER.md) | Money identity; interim ledger metadata |
| [../MASTER_PLAN.md](../MASTER_PLAN.md) | Index |
