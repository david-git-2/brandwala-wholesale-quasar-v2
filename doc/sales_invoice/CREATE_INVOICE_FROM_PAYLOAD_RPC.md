# RPC Spec: `create_invoice_from_payload`

**Status:** Implemented (`supabase/migrations/20270831410000_create_sales_invoice_from_payload.sql`)  
**Scope:** One RPC to create any sales invoice — wholesale, retail, or dropship — from a single JSON payload (header + line items + options).  
**Pair:** [`UPDATE_INVOICE_FROM_PAYLOAD_RPC.md`](./UPDATE_INVOICE_FROM_PAYLOAD_RPC.md) (`update_sales_invoice_from_payload`)

---

## 1. Goal

Replace the multi-step desk flow (`create_sales_invoice` → `add_global_invoice_item` × N → `update_global_invoice_header` → `issue_wholesale_invoice`) with **one atomic RPC** that accepts all invoice data up front.

The caller sends everything needed to persist:

- Invoice header (`sales_invoices`) — **required**
- Line items (`sales_invoice_items`) — **optional**; omit or pass `[]` for a blank draft invoice
- Optional links (e.g. dropship `shop_order_id`)
- Optional post-create actions (issue, wallet hooks)

The RPC validates, writes, recomputes totals, and returns the created invoice snapshot. A blank invoice (header only, zero lines) is valid when `options.issue = false` (default).

---

## 2. RPC Signature

```sql
create_invoice_from_payload(
  p_tenant_id bigint,
  p_payload   jsonb
) returns jsonb
```

| Param | Type | Description |
| :--- | :--- | :--- |
| `p_tenant_id` | `bigint` | Issuing child tenant (`issued_by_tenant_id`). Must match staff membership. |
| `p_payload` | `jsonb` | Full invoice document (see §3). |

**Security:** `SECURITY DEFINER`, `search_path = public`. Caller must be active staff/admin on `p_tenant_id` or parent manager.

**Grants:** `authenticated` only.

---

## 3. Payload Contract

### 3.1 Top-level shape

```json
{
  "invoice": { },
  "items": [ ],
  "links": { },
  "options": { }
}
```

| Key | Required | Description |
| :--- | :--- | :--- |
| `invoice` | Yes | Header fields for `sales_invoices`. |
| `items` | No | Line items. Omit or pass `[]` to create a **blank draft** invoice (header only). |
| `links` | No | Cross-module references (dropship order, etc.). |
| `options` | No | Behavior flags (issue immediately, idempotency, etc.). |

---

### 3.2 `invoice` object

Maps to `sales_invoices` (write the **table**, not the `global_invoices` view).

| Field | Type | Required | Notes |
| :--- | :--- | :--- | :--- |
| `invoice_type` | `wholesale` \| `retail` \| `dropship` | Yes | Drives validation rules (§4). |
| `invoice_no` | `text` | No | Auto-generated via `generate_sales_invoice_number` when null/empty. |
| `invoice_date` | `date` | No | Default: `CURRENT_DATE`. |
| `billing_profile_id` | `bigint` | Conditional | Required for wholesale, retail account, dropship. Null for retail direct. |
| `recipient_profile_id` | `bigint` | No | Must belong to `p_tenant_id` when set. |
| `recipient_name` | `text` | No | Inline recipient snapshot. |
| `recipient_phone` | `text` | No | Inline recipient snapshot. |
| `recipient_address` | `text` | No | Inline recipient snapshot. |
| `retail_billing_mode` | `account` \| `direct` | Conditional | Required when `invoice_type = retail`. |
| `collection_source` | `billing_profile` \| `recipient` | No | Derived from type/rules when omitted (§4). |
| `due_date` | `date` | No | |
| `note` | `text` | No | |
| `discount_amount` | `numeric(12,2)` | No | Default `0`. |
| `shipping_charge` | `numeric(12,2)` | No | Default `0`. |
| `cod_charge_amount` | `numeric(12,2)` | No | Default `0`. Dropship COD courier fee. Legacy alias `cod_charge` accepted. |
| `print_charge` | `numeric(12,2)` | No | Default `0`. |
| `wrapping_charge` | `numeric(12,2)` | No | Default `0`. |
| `invoice_status` | `draft` \| `issued` | No | Default `draft`. Use `options.issue` as preferred control (§3.4). |

**Derived by server (never accepted from payload):**

- `parent_tenant_id` — `resolve_parent_tenant_id(p_tenant_id)`
- `issued_by_tenant_id` — `p_tenant_id`
- `created_by` — `auth.uid()`
- `payment_status`, `paid_amount`, `due_amount`, `subtotal_amount`, `total_amount` — computed from lines + charges unless `options.issue = false` and status is `draft`

---

### 3.3 `items[]` array

Each element maps to one `sales_invoice_items` row.

| Field | Type | Required | Notes |
| :--- | :--- | :--- | :--- |
| `global_stock_id` | `bigint` | Yes | Stock row to sell. Validated for ATP when issuing. |
| `quantity` | `numeric(12,3)` | Yes | Must be `> 0`. |
| `sell_price_amount` | `numeric(12,2)` | Yes | Must be `>= 0`. |
| `line_discount_amount` | `numeric(12,2)` | No | Default `0`. |
| `name_snapshot` | `text` | No | Default from shipment item / product when omitted. |
| `barcode_snapshot` | `text` | No | Default from stock snapshot. |
| `product_code_snapshot` | `text` | No | Default from stock snapshot. |
| `product_id` | `bigint` | No | Default from stock. |
| `shipment_item_id` | `bigint` | No | Default from `global_stocks.shipment_item_id`. |
| `unit_cost_price` | `numeric(12,2)` | No | Default `calculate_landed_unit_cost(shipment_item_id)` at issue time. **Snapshot only** — not updated when shipment costs are revised or re-stamped after receive. |
| `assigned_child_tenant_id` | `bigint` | No | Default from shipment assignment. |
| `line_total_amount` | `numeric(12,2)` | No | Default `quantity * sell_price_amount - line_discount_amount`. |

**Rules:**

- `items` may be omitted or `[]` → **blank invoice** (header only). `subtotal_amount = 0`; `total_amount` = header charges only (`shipping_charge + cod_charge_amount + print_charge + wrapping_charge - discount_amount`, floored at 0).
- **`options.issue = true` with zero line items → reject** (`code: VALIDATION_ERROR`, message: *At least one line item is required to issue*).
- When `items` is empty and `links.shop_order_id` is set with `options.copy_lines_from_order = true`, server copies lines from `shop_order_items` before insert (dropship convenience; see §4.3).
- When `items` is non-empty: duplicate `global_stock_id` in the same payload merges into one line (sum quantities).
- All items must resolve to stock owned under the invoice `parent_tenant_id` network.

---

### 3.4 `links` object (optional)

| Field | Type | When used |
| :--- | :--- | :--- |
| `shop_order_id` | `bigint` | Dropship B2B: set `shop_orders.global_invoice_id` after create. Order must be `dropship`, `delivered` or `payment_received`, and not already invoiced. |
| `source_module` | `wholesale` \| `shop` \| `dropship` | Audit metadata only. Default from `invoice_type`. |
| `idempotency_key` | `text` | Stored in invoice `note` metadata or dedicated column if added later; used with `options.idempotent` (§3.5). |

---

### 3.5 `options` object (optional)

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `issue` | `boolean` | `false` | When `true`, final invoice status is `issued`, stock is consumed, totals frozen, AR created. Requires at least one line item. When `false`, status stays `draft` (blank invoice allowed). |
| `copy_lines_from_order` | `boolean` | `false` | When `true` and `items` is empty: copy lines from `links.shop_order_id` → `shop_order_items`. Dropship only. |
| `idempotent` | `boolean` | `false` | When `true` + `links.idempotency_key`, return existing invoice if key already used for this tenant. |
| `skip_stock_consume` | `boolean` | `false` | Only allowed when `issue = false`. For proforma/draft previews. |
| `wallet` | `object` | null | Optional post-issue wallet hooks (dropship `invoice_billed`, etc.). |

---

## 4. Type-Specific Validation

### 4.1 Wholesale (`invoice_type = wholesale`)

| Rule | |
| :--- | :--- |
| `billing_profile_id` | Required. Must belong to `p_tenant_id`. |
| `retail_billing_mode` | Must be null. |
| `collection_source` | `billing_profile` (default). |
| Recipient | Defaults from billing profile when recipient fields omitted. |

### 4.2 Retail (`invoice_type = retail`)

| `retail_billing_mode` | `billing_profile_id` | `collection_source` |
| :--- | :--- | :--- |
| `account` | Required | `billing_profile` |
| `direct` | Must be null | `recipient` |

Recipient name/phone/address required for `direct` when no `recipient_profile_id`.

### 4.3 Dropship (`invoice_type = dropship`)

| Rule | |
| :--- | :--- |
| `billing_profile_id` | Required (middle-man / reseller account). |
| `retail_billing_mode` | Must be null. |
| `collection_source` | `recipient` by default; `billing_profile` when order/payload marks prepaid. |
| `links.shop_order_id` | Recommended. When set, invoice number default is `INV-DS-{order_no}` if `invoice_no` omitted. |
| Order status | When `shop_order_id` set: order must be `delivered` or `payment_received`. |

Blank dropship invoice (no lines) is allowed as a **draft** (`options.issue = false`), same as wholesale/retail.

When `links.shop_order_id` is set and `items` is empty, server may copy lines from `shop_order_items` if `options.copy_lines_from_order = true`. Otherwise the invoice is created with zero lines (blank draft).

---

## 5. Processing Steps (server)

```text
1. AuthZ — staff on p_tenant_id
2. Parse + schema-validate p_payload
3. Type rules (§4)
4. Resolve invoice_no (generate if empty)
5. Idempotency check (if enabled)
6. IF items empty AND options.copy_lines_from_order → hydrate items from shop_order_items
7. IF options.issue AND item count = 0 → reject (VALIDATION_ERROR)
8. BEGIN transaction
9. INSERT sales_invoices (header)
10. FOR EACH item → INSERT sales_invoice_items (parent_tenant_id only; never tenant_id alias)
11. recompute_global_invoice_totals(invoice_id)
12. IF options.issue → issue path (stock consume, status = issued, payment_status = due)
13. IF links.shop_order_id → UPDATE shop_orders.global_invoice_id
14. IF options.wallet → run wallet hooks
15. COMMIT
16. RETURN success payload (§6)
```

**Critical implementation note:** Always insert into `sales_invoice_items` (table). Do not insert both `tenant_id` and `parent_tenant_id` through the `global_invoice_items` view.

---

## 6. Response Contract

### 6.1 Success

```json
{
  "success": true,
  "invoice_id": 12345,
  "invoice_no": "INV-WS-20260827-0001",
  "invoice_status": "issued",
  "payment_status": "due",
  "issued": true,
  "invoice": {
    "id": 12345,
    "parent_tenant_id": 10,
    "issued_by_tenant_id": 25,
    "invoice_type": "wholesale",
    "invoice_no": "INV-WS-20260827-0001",
    "billing_profile_id": 55,
    "subtotal_amount": 1000.00,
    "discount_amount": 0.00,
    "shipping_charge": 0.00,
    "cod_charge_amount": 0.00,
    "print_charge": 0.00,
    "wrapping_charge": 0.00,
    "total_amount": 1000.00,
    "paid_amount": 0.00,
    "due_amount": 1000.00,
    "collection_source": "billing_profile"
  },
  "items": [
    {
      "id": 90001,
      "global_stock_id": 456,
      "quantity": 2,
      "sell_price_amount": 500.00,
      "line_total_amount": 1000.00
    }
  ],
  "links": {
    "shop_order_id": null
  }
}
```

### 6.2 Failure

```json
{
  "success": false,
  "error": "human-readable message",
  "code": "VALIDATION_ERROR | NOT_FOUND | ACCESS_DENIED | STOCK_INSUFFICIENT | DUPLICATE_INVOICE | ISSUE_REQUIRES_ITEMS"
}
```

HTTP/RPC layer may still return Postgres errors for unexpected failures; business failures should use the JSON shape above.

---

## 7. Example Payloads

### 7.1 Wholesale — blank draft (no items)

```json
{
  "p_tenant_id": 25,
  "p_payload": {
    "invoice": {
      "invoice_type": "wholesale",
      "billing_profile_id": 55,
      "recipient_name": "ABC Traders",
      "recipient_phone": "01700000000",
      "recipient_address": "Dhaka",
      "note": "Draft — lines added later"
    },
    "options": {
      "issue": false
    }
  }
}
```

`items` omitted (or `"items": []`). Creates header with `invoice_status = draft`, `subtotal_amount = 0`, `total_amount = 0` (unless header charges set).

### 7.2 Wholesale (draft with lines)

```json
{
  "p_tenant_id": 25,
  "p_payload": {
    "invoice": {
      "invoice_type": "wholesale",
      "billing_profile_id": 55,
      "recipient_name": "ABC Traders",
      "recipient_phone": "01700000000",
      "recipient_address": "Dhaka",
      "note": "Counter sale"
    },
    "items": [
      {
        "global_stock_id": 456,
        "quantity": 2,
        "sell_price_amount": 500
      }
    ],
    "options": {
      "issue": false
    }
  }
}
```

### 7.3 Retail direct (issued)

```json
{
  "p_tenant_id": 25,
  "p_payload": {
    "invoice": {
      "invoice_type": "retail",
      "retail_billing_mode": "direct",
      "recipient_name": "Walk-in Customer",
      "recipient_phone": "01800000000",
      "recipient_address": "Shop pickup"
    },
    "items": [
      {
        "global_stock_id": 789,
        "quantity": 1,
        "sell_price_amount": 1200
      }
    ],
    "options": {
      "issue": true
    }
  }
}
```

### 7.4 Dropship B2B (issued, linked to order)

```json
{
  "p_tenant_id": 25,
  "p_payload": {
    "invoice": {
      "invoice_type": "dropship",
      "billing_profile_id": 55,
      "recipient_profile_id": 12,
      "recipient_name": "End Customer",
      "recipient_phone": "01900000000",
      "recipient_address": "Chittagong",
      "print_charge": 10,
      "wrapping_charge": 20,
      "discount_amount": 0,
      "note": "Tenant B2B invoice at delivered"
    },
    "items": [
      {
        "global_stock_id": 901,
        "quantity": 2,
        "sell_price_amount": 500,
        "unit_cost_price": 300
      }
    ],
    "links": {
      "shop_order_id": 45678,
      "idempotency_key": "dropship-invoice:45678"
    },
    "options": {
      "issue": true,
      "idempotent": true,
      "wallet": {
        "invoice_billed": true,
        "source_type": "shop_order",
        "source_id": "45678"
      }
    }
  }
}
```

---

## 8. Relationship to Existing RPCs

| Today | After this RPC |
| :--- | :--- |
| `create_sales_invoice` + N × `add_global_invoice_item` + `issue_wholesale_invoice` | Single call |
| `issue_dropship_tenant_b2b_invoice` (order id only) | Becomes thin wrapper: build payload from order → call `create_invoice_from_payload` |
| `create_dual_invoice_from_dropship_order` | Deprecated in favor of wrapper + this RPC |

Existing RPCs stay until cutover; new UI and integrations should target `create_invoice_from_payload` only.

---

## 9. Out of Scope (v1)

- Payments / allocations in the same call
- Returns
- Void / unpost
- Partial issue across multiple stock movements with custom FIFO override
- Thrift POS invoices (`thrift_sales_invoices`)

---

## 10. Migration / Types Checklist (when implemented)

1. Add migration: `CREATE OR REPLACE FUNCTION create_invoice_from_payload ...`
2. Grant `EXECUTE` to `authenticated`
3. `pnpm run backend:types`
4. Add `web` repository method + optional Zod schema mirroring §3
5. Point desk create flows at this RPC behind a feature flag
6. Add integration tests: blank wholesale draft (no items), wholesale draft with lines, retail direct issue, dropship + order link + copy_lines_from_order, issue rejected with zero items, idempotency, insufficient stock
