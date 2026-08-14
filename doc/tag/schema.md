# Tag catalog — schema (v2)

Canon: [UNIVERSAL_TAGGING_SYSTEM.md](./UNIVERSAL_TAGGING_SYSTEM.md) · Seeds: [presets.md](./presets.md)

Live bridge: existing `public.tags` (task module) + `public.entity_tags` + `tags.group_name`. T1 introduces `tag_categories` and normalizes `tags.category_id`.

---

## 1. `tag_categories`

| Column | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT PK | Yes | |
| `module_key` | TEXT | Yes | `stock_grade` \| `color` \| `shop_category` \| `sale_category` \| `shipment_progress` \| … |
| `code` | TEXT | Yes | Preset key within module — e.g. `warehouse`, `produce`, `clothing`, `default` |
| `name` | TEXT | Yes | Display name |
| `cardinality` | TEXT | Yes | `single` \| `many` |
| `is_system` | BOOLEAN | Yes | `true` = platform seed; tenants cannot edit |
| `tenant_id` | BIGINT FK NULL | No | `NULL` if system; set if tenant-owned category (later) |
| `sort_order` | INT | No | |
| `is_active` | BOOLEAN | Yes | Default true |

**Uniques:** `(module_key, code)` where `tenant_id IS NULL`; later `(tenant_id, module_key, code)` for custom.

---

## 2. `tags`

| Column | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT PK | Yes | |
| `category_id` | BIGINT FK → `tag_categories` | Yes | Parent category (after T1) |
| `slug` | TEXT | Yes | Machine id — unique per category |
| `name` | TEXT | Yes | Display |
| `color` | TEXT | No | Hex for badges / color swatches |
| `metadata` | JSONB | Yes | Default `{}` — module-specific (see below) |
| `sort_order` | INT | No | |
| `is_active` | BOOLEAN | Yes | Default true |
| `tenant_id` | BIGINT NULL | No | Prefer inherit from category; keep null for system tags |

**Unique:** `(category_id, slug)`.

### `metadata` conventions

| module_key | Example keys |
| :--- | :--- |
| `stock_grade` | `maps_to_availability` (`sellable` \| `unsellable`) — no discount % |
| `color` | optional; hex primarily on `tags.color` |
| `shipment_progress` | optional stepper hints |

---

## 3. `entity_tags` (soft / multi attach)

| Column | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT PK | Yes | |
| `tenant_id` | BIGINT FK | Yes | RLS scope |
| `tag_id` | BIGINT FK → `tags` | Yes | |
| `entity_type` | TEXT | Yes | e.g. `shipment`, `product`, `shop_product_listing`, `wallet_ledger` |
| `entity_id` | TEXT | Yes | Target id as text |
| `created_at` | TIMESTAMPTZ | Yes | |

**Unique:** `(tenant_id, tag_id, entity_type, entity_id)`.  
Indexes: `(entity_type, entity_id)`, `(tag_id)`.

Use for `shop_category`, `sale_category`, `shipment_progress` (SSOT), soft labels.  
**Do not** use as the only grade link on `global_stocks`.

---

## 4. Consumer FKs (not tag tables)

| Column | On | Rule |
| :--- | :--- | :--- |
| `grade_tag_id` | `global_stocks` | Required for sellable graded qty (T3). FK → `tags.id` where category `module_key = stock_grade` |
| `progress_tag_id` | `global_shipments` | Optional denorm; SSOT remains `entity_tags` |
| `color_tag_id` | products (T4) | Optional primary color FK |

Stock unique grain after T3:

```text
(shipment_item_id, availability, location_id, grade_tag_id)
```

---

## 5. RLS sketch

| Actor | System categories/tags | Tenant custom (later) | entity_tags |
| :--- | :--- | :--- | :--- |
| Platform superadmin | CRUD | — | — |
| Tenant member | **SELECT** only | CRUD own | CRUD own tenant rows |
| Anon | none | none | none |

Day one: no tenant write on `is_system = true` rows (enforce in RPC / RLS).

---

## 6. Live migration notes (T1)

- Add `tag_categories`; backfill from distinct `tags.group_name` / progress seeds where possible.
- Add `tags.category_id`; keep `group_name` dual-read until cutover.
- Seed `stock_grade` + `color` per [presets.md](./presets.md).
- Do not drop task-module tag usage until callers migrated.

---

## 7. RPC List (T1)

- `public.list_tag_categories(p_module_key text default null) -> json` — **authenticated**; system + caller’s tenant categories
- `public.list_tags_for_category(p_category_id bigint default null, p_module_key text default null, p_code text default null) -> json`
- `public.get_tag_by_slug(p_category_id bigint default null, p_module_key text default null, p_code text default null, p_slug text default null) -> json`

No create/update/delete RPCs (seed-only system catalog). Write RLS blocks `is_system = true` tags.

