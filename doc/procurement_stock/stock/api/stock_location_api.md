# Stock Locations API

Parent warehouse **shelf → slot → box** catalog (`stock_locations`). Schema: [../schema.md](../schema.md) §2.1.

**Module:** `global_stock_location` (`view` | `create` | `edit` | `delete`)

No auto-seed — empty until staff add places.

---

## 1. List

* **RPC:** `list_stock_locations(p_parent_tenant_id, p_include_inactive?)`
* Returns **flat** rows (UI builds tree via `parent_location_id`)
* Order by `sort_order`, `code`

```typescript
const { data, error } = await supabase.rpc('list_stock_locations', {
  p_parent_tenant_id: tenantId,
  p_include_inactive: true,
})
```

### Row shape

```json
{
  "id": 1,
  "parent_tenant_id": 12,
  "parent_location_id": null,
  "code": "S1",
  "name": "Shelf 1",
  "kind": "shelf",
  "is_default": true,
  "is_pickable": true,
  "sort_order": 0,
  "is_active": true,
  "created_at": "2026-08-13T00:00:00Z",
  "updated_at": "2026-08-13T00:00:00Z"
}
```

`kind`: `shelf` | `slot` | `box` | `returns`

---

## 2. Upsert

* **RPC:** `upsert_stock_location(...)`
* Create when `p_id` is null (`create`); update when set (`edit`)
* `p_parent_location_id`: nesting — shelf/returns root; slot under shelf|returns; box under slot
* Default only on **leaves**; adding a child clears default on the parent

```typescript
const { data, error } = await supabase.rpc('upsert_stock_location', {
  p_parent_tenant_id: tenantId,
  p_code: 'S1-03',
  p_name: 'Shelf 1 Slot 3',
  p_kind: 'slot',
  p_parent_location_id: shelfId,
  p_is_pickable: true,
  p_sort_order: 10,
  p_is_active: true,
  p_is_default: false,
  p_id: null,
})
```

---

## 3. Set default

* **RPC:** `set_default_stock_location(p_id)` — requires `edit`
* Target must be **active leaf**

```typescript
await supabase.rpc('set_default_stock_location', { p_id: locationId })
```

---

## 4. Delete

* **RPC:** `delete_stock_location(p_id)` — requires `delete` or `edit`
* Hard delete; **children cascade** (deleting a shelf removes its slots/boxes)

```typescript
await supabase.rpc('delete_stock_location', { p_id: locationId })
```
