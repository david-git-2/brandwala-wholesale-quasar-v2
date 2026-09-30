# Product-Based Costing (PBC) — API Contract (as-built)

> Cursor lists avoid `COUNT(*)` and offset paging. Full line loads for export/copy still use direct table reads or unpaginated helpers in the web repository.

---

## `list_product_based_costing_files`

Keyset list of costing files (newest first).

```sql
list_product_based_costing_files(
  p_search text default null,
  p_status text default null,
  p_tenant_id bigint default null,
  p_limit integer default 20,
  p_cursor_created_at timestamptz default null,
  p_cursor_id bigint default null
) returns jsonb
```

Response:

```json
{
  "data": [ /* file rows + customer_group_name */ ],
  "meta": {
    "has_more": true,
    "next_cursor": { "created_at": "...", "id": 123 },
    "limit": 20
  }
}
```

---

## `list_product_based_costing_items`

Keyset list of lines for one file (`sort_order`, then `id`). Requires `can_view_costing_item(p_file_id)`.

```sql
list_product_based_costing_items(
  p_file_id bigint,
  p_limit integer default 25,
  p_cursor_sort_order integer default null,
  p_cursor_id bigint default null
) returns jsonb
```

Response shape matches files list (`data` + `meta.has_more` + `meta.next_cursor` with `sort_order` and `id`).

---

## `get_product_based_costing_file_summary`

Unchanged: full-file aggregates (including `line_count`), not a page of items.

---

## `update_product_based_costing_items`

One call to PATCH many quote lines. Each object must have `id`. Other keys are optional; missing keys stay as they are.

```sql
update_product_based_costing_items(p_items jsonb) returns setof product_based_costing_items
```

Row-level rules still apply (`can_manage_costing_item`).

---

## Backlog (unchanged)

- `list_pbc_backlog_items`
- `add_pbc_backlog_to_file`
