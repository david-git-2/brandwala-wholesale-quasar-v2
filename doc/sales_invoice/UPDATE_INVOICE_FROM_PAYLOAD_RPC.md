# RPC Spec: `update_sales_invoice_from_payload`

**Status:** Implemented (`supabase/migrations/20270831410000_create_sales_invoice_from_payload.sql`)  
**Pair:** [`CREATE_INVOICE_FROM_PAYLOAD_RPC.md`](./CREATE_INVOICE_FROM_PAYLOAD_RPC.md) (`create_sales_invoice_from_payload`)

---

## 1. Goal

Patch an existing **draft** or **proforma** invoice from one JSON payload. **Only keys present in the payload are updated** — omitted keys are left unchanged.

Supports:

- Partial header updates (`invoice` object)
- Line item updates by `id` (partial fields)
- New lines (no `id`, requires `global_stock_id`)
- Line removal (`remove_item_ids`)

---

## 2. RPC Signature

```sql
update_sales_invoice_from_payload(
  p_tenant_id  bigint,
  p_invoice_id bigint,
  p_payload    jsonb
) returns jsonb
```

| Param | Type | Description |
| :--- | :--- | :--- |
| `p_tenant_id` | `bigint` | Issuing child tenant. Staff check. |
| `p_invoice_id` | `bigint` | Invoice to update. |
| `p_payload` | `jsonb` | Patch document (see §3). |

**Security:** `SECURITY DEFINER`, `search_path = public`. Caller must be staff on `p_tenant_id`. Invoice `issued_by_tenant_id` must equal `p_tenant_id`.

**Editable statuses:** `draft`, `proforma_generated` only. Issued/void invoices reject with `INVOICE_NOT_EDITABLE`.

---

## 3. Payload Contract

### 3.1 Top-level shape

```json
{
  "invoice": { },
  "items": [ ],
  "remove_item_ids": [ ],
  "options": { }
}
```

| Key | Required | Description |
| :--- | :--- | :--- |
| `invoice` | No | Header fields to patch. Only included keys are written. |
| `items` | No | Lines to update (with `id`) or add (without `id`). |
| `remove_item_ids` | No | Array of `sales_invoice_items.id` to delete. |
| `options` | No | Reserved (`recompute_totals` default true). |

At least one of `invoice`, `items`, or `remove_item_ids` must be non-empty.

---

### 3.2 `invoice` object — patchable header fields

Send **only** the fields you want to change.

| Field | Type | Notes |
| :--- | :--- | :--- |
| `invoice_no` | `text` | |
| `invoice_date` | `date` | |
| `due_date` | `date` | |
| `billing_profile_id` | `bigint` | Must belong to `p_tenant_id`. |
| `recipient_profile_id` | `bigint` | Must belong to `p_tenant_id`. |
| `recipient_name` | `text` | |
| `recipient_phone` | `text` | |
| `recipient_address` | `text` | |
| `note` | `text` | |
| `discount_amount` | `numeric(12,2)` | |
| `shipping_charge` | `numeric(12,2)` | |
| `cod_charge_amount` | `numeric(12,2)` | Legacy alias `cod_charge` accepted. |
| `print_charge` | `numeric(12,2)` | |
| `wrapping_charge` | `numeric(12,2)` | |
| `collection_source` | `billing_profile` \| `recipient` | |

**Not patchable via this RPC:** `invoice_type`, `parent_tenant_id`, `issued_by_tenant_id`, `invoice_status`, payment fields (`paid_amount`, `due_amount`, …). Use issue/collect/void RPCs for lifecycle.

**Patch rule:** Key must be present in JSON (`invoice ? 'field'`). Explicit `null` clears nullable text fields; numerics treat `null` as `0` where applicable.

---

### 3.3 `items[]` — update or add

#### Update existing line (`id` required)

```json
{ "id": 90001, "quantity": 3, "sell_price_amount": 450 }
```

| Field | Required on update | Notes |
| :--- | :--- | :--- |
| `id` | Yes | Existing `sales_invoice_items.id` on this invoice. |
| `quantity` | No | If sent, must be `> 0`. |
| `sell_price_amount` | No | If sent, must be `>= 0`. |
| `line_discount_amount` | No | |
| `name_snapshot` | No | |
| `unit_cost_price` | No | |

Only sent fields change. `line_total_amount` is recomputed when qty, price, or discount change.

#### Add new line (no `id`)

```json
{
  "global_stock_id": 456,
  "quantity": 2,
  "sell_price_amount": 500
}
```

Same optional fields as create (see create spec §3.3). Stock must belong to invoice `parent_tenant_id`.

---

### 3.4 `remove_item_ids`

```json
"remove_item_ids": [90002, 90003]
```

Deletes draft lines belonging to this invoice. Ignores ids not on invoice.

---

### 3.5 `options`

| Field | Default | Description |
| :--- | :--- | :--- |
| `recompute_totals` | `true` | Call `recompute_global_invoice_totals` after all changes. |

---

## 4. Processing Steps

```text
1. AuthZ — staff on p_tenant_id
2. Load invoice FOR UPDATE; verify issued_by_tenant_id = p_tenant_id
3. Reject if status not in (draft, proforma_generated)
4. Reject if payload has no invoice/items/remove_item_ids changes
5. PATCH sales_invoices — only keys present in payload.invoice
6. FOR EACH remove_item_ids → DELETE sales_invoice_items
7. FOR EACH items[]:
     - has id → PATCH line (sent fields only)
     - no id → INSERT line (add_global_invoice_item rules)
8. recompute_global_invoice_totals (unless options.recompute_totals = false)
9. RETURN updated invoice + items snapshot
```

---

## 5. Response

### Success

```json
{
  "success": true,
  "invoice_id": 12345,
  "invoice_no": "INV-WS-20260827-0001",
  "invoice_status": "draft",
  "payment_status": "due",
  "invoice": { },
  "items": [ ],
  "removed_item_ids": [90002]
}
```

### Failure

```json
{
  "success": false,
  "error": "human-readable message",
  "code": "VALIDATION_ERROR | NOT_FOUND | ACCESS_DENIED | INVOICE_NOT_EDITABLE | EMPTY_PAYLOAD"
}
```

---

## 6. Examples

### 6.1 Patch note and discount only

```json
{
  "p_tenant_id": 25,
  "p_invoice_id": 12345,
  "p_payload": {
    "invoice": {
      "note": "Revised terms",
      "discount_amount": 100
    }
  }
}
```

### 6.2 Update one line, add one line, remove one line

```json
{
  "p_tenant_id": 25,
  "p_invoice_id": 12345,
  "p_payload": {
    "items": [
      { "id": 90001, "quantity": 5, "sell_price_amount": 480 },
      { "global_stock_id": 789, "quantity": 1, "sell_price_amount": 1200 }
    ],
    "remove_item_ids": [90002]
  }
}
```

### 6.3 Recipient + charges

```json
{
  "p_tenant_id": 25,
  "p_invoice_id": 12345,
  "p_payload": {
    "invoice": {
      "recipient_name": "New Name",
      "recipient_phone": "01700000001",
      "shipping_charge": 80,
      "cod_charge_amount": 25,
      "print_charge": 10
    }
  }
}
```

---

## 7. Relationship to Existing RPCs

| Today | After this RPC |
| :--- | :--- |
| `update_global_invoice_header` + `update_global_invoice_item` + `add_global_invoice_item` + `remove_global_invoice_item` | Single patch call |

Legacy RPCs remain until desk UI cutover.
