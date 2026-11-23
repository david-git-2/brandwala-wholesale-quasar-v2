# Document numbers — what they mean

Every order, bill, note, shipment, and stock movement gets a **reference number** you can search, print, and quote on the phone. New numbers follow the patterns below. **Older records** may still use legacy patterns at the bottom — both are valid in search.

Numbers are assigned **automatically** when the document is created. Staff do not pick the next number unless a supervisor enters a **manual override** on a bill (rare).

**Thrift** shops use a **different** invoice and return format. This page is for **BrandWala wholesale / dropship / app billing**, not thrift.

---

## How to read a number

Most numbers use **hyphens** between parts:

```text
PREFIX – (optional type) – (optional date) – sequence
```

| Part | Meaning |
| :--- | :--- |
| **Prefix** | What kind of document it is (`SO`, `INV`, `CN`, …). |
| **Type code** (sometimes) | Which sales channel the bill belongs to (`WS`, `RT`, `DS`). |
| **Date** (sometimes) | Which **day** or **month** the counter bucket uses (`251105` = 5 Nov 2025; `2511` = Nov 2025). Based on tenant timezone when the number is issued. |
| **Sequence** | A running counter for that tenant and bucket (usually 4 digits, zero-padded). |

If a step fails after the system reserved a number, the next document may **skip** a sequence value. That is normal.

---

## Shop orders

| | |
| :--- | :--- |
| **Example** | `SO-251105-0042` |
| **Where you see it** | Shop order list, order detail, checkout confirmation, dropship processing. |

| Segment | Meaning |
| :--- | :--- |
| `SO` | Shop order. |
| `251105` | Order date bucket (YYMMDD). |
| `0042` | 42nd shop order that day for this tenant (per counter). |

**Legacy:** `ORD-YYYYMMDD-#####` (random suffix). Still appears on old orders; new orders use `SO-`.

---

## Sales invoices (AR bills)

| | |
| :--- | :--- |
| **Example** | `INV-WS-2511-0042` |
| **Where you see it** | Bills desk, printed invoice, payment allocation, customer statement. |

| Segment | Meaning |
| :--- | :--- |
| `INV` | Sales invoice (standard bill). |
| `WS` | Wholesale. `RT` = retail. `DS` = dropship channel on the bill type (not the same as dropship B2B below). |
| `2511` | Month bucket (YYMM). |
| `0042` | Sequence within that month and type for this tenant. |

**Legacy:** `INV-WS-YYYYMMDD-####` (daily bucket). Still valid on old invoices.

---

## Credit notes and debit notes

Adjustments to an **issued** parent bill get their own number. They keep the parent’s sales type in the middle.

| | Credit note | Debit note |
| :--- | :--- | :--- |
| **Example** | `CN-WS-2511-0007` | `DN-WS-2511-0002` |
| **Prefix** | `CN` | `DN` |

Other segments match sales invoices (`WS` / `RT` / `DS`, month, sequence).

**Legacy:** `INV-CN-…` and `INV-DN-…` on older notes.

---

## AP bills (payables on inbound shipments)

| | |
| :--- | :--- |
| **Example** | `AP-2511-0031` |
| **Where you see it** | Shipment AP tabs, vendor AP lists. |

| Segment | Meaning |
| :--- | :--- |
| `AP` | Accounts payable bill (not a customer invoice). |
| `2511` | Month bucket (YYMM). |
| `0031` | Sequence for AP bills that month. |

**Legacy:** `INV-INV-…` (mis-generated AP). Treat as AP bill in search; new AP uses `AP-`.

---

## Dropship merchant B2B invoice

Bill from **tenant → merchant profile** when a dropship order is invoiced (not the end customer’s retail receipt).

| | |
| :--- | :--- |
| **Example** | `DS-2511-0009` |
| **Where you see it** | Dropship order linked bill, merchant statement. |

| Segment | Meaning |
| :--- | :--- |
| `DS` | Dropship B2B invoice series. |
| `2511` | Month bucket (YYMM). |
| `0009` | Sequence that month. |

The order is linked on the bill record (`shop_order_id`), not embedded in the number.

**Legacy:** `INV-DS-{order_no}` (invoice number contained the shop order number). Old rows only.

---

## Inbound shipments

| | |
| :--- | :--- |
| **Example** | `SHP-1042` |
| **Where you see it** | Shipment list, receive screens, search by shipment code. |

| Segment | Meaning |
| :--- | :--- |
| `SHP` | Shipment. |
| `1042` | Tenant shipment sequence (same integer as **tenant shipment id** in many screens). |

There is **no date** in the shipment code. Older shipments may show only the numeric id without `SHP-` in some views; search usually accepts both.

---

## Stock movements (warehouse audit)

Each posted movement gets a trace number. Prefix depends on **why** stock moved:

| Prefix | doc meaning | Example |
| :--- | :--- | :--- |
| `MOV` | General stock movement (issue, transfer, bill issue audit, etc.) | `MOV-251105-0187` |
| `SM` | Manual movement shell | `SM-251105-0042` |
| `RP` | Receive / put-away from inbound shipment | `RP-251105-0003` |
| `VR` | Vendor return from received shipment | `VR-251105-0001` |

For `MOV`, `SM`, `RP`, and `VR` with a date segment:

| Segment | Meaning |
| :--- | :--- |
| Prefix | Movement category (table above). |
| `251105` | Day bucket (YYMMDD). |
| `0187` | Sequence that day for this tenant and category. |

**Legacy:** suffix tied to an internal database id (long, not tenant-scoped). Old movement rows only.

---

## Thrift (separate system)

Thrift invoices look like `INV-YYYY-MM-#####` and returns like `RET-YYYY-MM-#####`. They do **not** follow the tables above. See the thrift module in the [Platform guide](/docs/modules/thrift).

---

## Quick lookup table

| You are looking at… | New format example | Main prefix |
| :--- | :--- | :--- |
| Shop order | `SO-251105-0042` | `SO` |
| Wholesale / retail / dropship invoice | `INV-WS-2511-0042` | `INV` |
| Credit / debit note | `CN-WS-2511-0007` | `CN` / `DN` |
| Shipment AP | `AP-2511-0031` | `AP` |
| Dropship merchant bill | `DS-2511-0009` | `DS` |
| Inbound shipment | `SHP-1042` | `SHP` |
| Stock movement | `MOV-251105-0187` | `MOV` / `SM` / `RP` / `VR` |

When in doubt, search by the **full string** shown on the document screen. Partial search (numeric id only) still works for shipments and many lists.
