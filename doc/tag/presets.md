# Tag catalog — system presets (seed)

Canon: [UNIVERSAL_TAGGING_SYSTEM.md](./UNIVERSAL_TAGGING_SYSTEM.md) · [schema.md](./schema.md)

**Control:** platform seed only day one. Tenants select; they do not edit.

All rows below: `is_system = true`, `tenant_id = NULL`.

---

## 1. module_key = `stock_grade`

Cardinality: **single**.  
Tenant/parent setting points at one category (`warehouse` \| `produce` \| `clothing`).

### 1.1 Category `warehouse` (import / electronics-style)

| slug | name | metadata |
| :--- | :--- | :--- |
| `standard` | Standard | `{ "maps_to_availability": "sellable" }` |
| `open_box` | Open box | `{ "maps_to_availability": "sellable" }` |
| `box_damage` | Box damage | `{ "maps_to_availability": "sellable" }` |
| `box_less` | Box less | `{ "maps_to_availability": "sellable" }` |
| `badly_damaged` | Badly damaged | `{ "maps_to_availability": "unsellable" }` |

Receive default: `standard` + `availability = sellable`.

### 1.2 Category `produce` (placeholder — tune at implement)

| slug | name | metadata |
| :--- | :--- | :--- |
| `fresh` | Fresh | `{ "maps_to_availability": "sellable" }` |
| `ripe` | Ripe | `{ "maps_to_availability": "sellable" }` |
| `seconds` | Seconds | `{ "maps_to_availability": "sellable" }` |
| `waste` | Waste | `{ "maps_to_availability": "unsellable" }` |

### 1.3 Category `clothing` (placeholder — tune at implement)

| slug | name | metadata |
| :--- | :--- | :--- |
| `new` | New | `{ "maps_to_availability": "sellable" }` |
| `display` | Display | `{ "maps_to_availability": "sellable" }` |
| `defect` | Defect | `{ "maps_to_availability": "sellable" }` |
| `return` | Return | `{ "maps_to_availability": "sellable" }` |

---

## 2. module_key = `color`

Cardinality: **single** (primary product color).  
One system category `code = default`.

| slug | name | color (hex) |
| :--- | :--- | :--- |
| `black` | Black | `#111827` |
| `white` | White | `#F9FAFB` |
| `grey` | Grey | `#6B7280` |
| `red` | Red | `#DC2626` |
| `blue` | Blue | `#2563EB` |
| `green` | Green | `#16A34A` |
| `yellow` | Yellow | `#EAB308` |
| `orange` | Orange | `#EA580C` |
| `pink` | Pink | `#DB2777` |
| `purple` | Purple | `#7C3AED` |
| `brown` | Brown | `#92400E` |
| `beige` | Beige | `#D4A574` |
| `navy` | Navy | `#1E3A5F` |
| `multicolor` | Multicolor | `#A855F7` |

Extend via seed migration only (platform), not tenant CRUD day one.

---

## 3. Deferred seeds (document only until T2/T4)

| module_key | Notes |
| :--- | :--- |
| `shipment_progress` | Migrate existing progress tags into a category; tenant customize later |
| `shop_category` / `sale_category` | Stubs when shop/sales wire filters |

---

## 4. Metadata note

Grade metadata maps tags to availability status (`sellable` | `unsellable`). Stock storage tracks tag FK + availability.

