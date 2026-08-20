# Sales Invoice Numbering Engine

## Overview
The Sales Invoice Numbering Engine generates sequential, collision-free, human-readable invoice numbers across all sales invoice types in Brandwala Wholesale.

---

## 1. Numbering Scheme

Invoice numbers adhere to the following standard daily pattern:

$$\text{INV}-\{\text{TYPE}\}-\{\text{YYYYMMDD}\}-\{\text{SEQ}\}$$

### Invoice Type Identifiers:
| Invoice Type | Code | Example Output | Description |
| :--- | :---: | :--- | :--- |
| **Wholesale** | `WS` | `INV-WS-20260820-0001` | B2B bulk sales billed to Customer Billing Profile |
| **Retail** | `RT` | `INV-RT-20260820-0001` | Direct retail consumer & account invoices |
| **Dropship** | `DS` | `INV-DS-20260820-0001` | Reseller / dropship fulfillment invoices |

* **Date Format (`YYYYMMDD`)**: Represents the invoice issue date.
* **Daily Sequence Counter (`SEQ`)**: 4-digit zero-padded sequential number (`0001`, `0002`, ...), automatically resetting daily for each tenant and invoice type combination.

---

## 2. Database Architecture

### Counter Table: `sales_invoice_counters`
State is maintained in `public.sales_invoice_counters`:

```sql
CREATE TABLE public.sales_invoice_counters (
    tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    invoice_type public.global_invoice_type NOT NULL,
    date_key text NOT NULL, -- Format: YYYYMMDD
    last_value bigint DEFAULT 0 NOT NULL CHECK (last_value >= 0),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    PRIMARY KEY (tenant_id, invoice_type, date_key)
);
```

### Generator Function: `generate_sales_invoice_number`
Atomic UPSERT increments the counter safely under high concurrency:

```sql
SELECT public.generate_sales_invoice_number(
  p_tenant_id => 1,
  p_invoice_type => 'wholesale'::global_invoice_type,
  p_date => CURRENT_DATE
);
-- Returns: 'INV-WS-20260820-0001'
```

---

## 3. Integration & Fallback Behavior

1. **Automatic Database Resolution**:
   In `public.create_sales_invoice`:
   If `p_invoice_no` is omitted, `NULL`, or empty/whitespace, the database automatically calls `generate_sales_invoice_number` to assign the sequential number.

2. **Custom Overrides**:
   Users can still manually provide custom invoice numbers in the UI (e.g. for legacy or external reference matching). When left blank, the placeholder reminds the user that it will be auto-generated.

3. **Frontend API**:
   Available in TypeScript via `invoiceRepository.generateInvoiceNumber`:
   ```ts
   const invoiceNo = await invoiceRepository.generateInvoiceNumber(tenantId, 'wholesale', '2026-08-20');
   ```
