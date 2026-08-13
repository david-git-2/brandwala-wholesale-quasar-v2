# Feature Blueprint: Courier Bulk Remittance & Batch Settlement System

> **Feature Title**: Courier Bulk Remittance & Multi-Order Settlement System  
> **Target Module**: `shop_order` (Dropship Desk) / Accounting & Treasury  
> **Status**: Proposed Architecture Specification  
> **Author**: Senior Product Architect & PM  

---

## 1. Executive Summary & Value Proposition

### 1.1 Business Problem
In e-commerce and dropship fulfillment, courier services (such as Steadfast, Pathao, REDX, Paperfly) collect Cash on Delivery (COD) from end customers for dozens or hundreds of delivered orders simultaneously. Couriers do **not** remit funds order-by-order; instead, they disburse a single bulk bank payout (e.g., ৳2,45,000 for 120 orders) accompanied by a batch remittance statement.

Currently, logging remittances one order at a time via individual order detail pages is:
1. **Extremely Slow & Tedious**: Requires staff to open 100+ separate order pages manually.
2. **Error-Prone**: High risk of entry mistakes, duplicate entries, or missed orders.
3. **Lacks Batch Auditability**: No central record tying a bank transfer reference / deposit transaction ID to the specific set of orders it covered.

### 1.2 The Solution
The **Courier Bulk Remittance System** introduces a dedicated batch settlement workflow allowing ops and finance staff to:
- Create a **Courier Remittance Batch Header** (Courier name, Statement ID, Bank TRX ID, Total Bank Net Deposit).
- Select delivered orders or paste bulk tracking/AWB numbers to auto-match orders.
- Reconcile line item totals against bank deposits with live variance tracking.
- Post the entire batch atomically in a single RPC execution, marking all included orders as `payment_received`, creating global payment records, and posting invoice payments.

---

## 2. Target User Workflows & UX Mockup

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│  Dropship Desk > Courier Remittances > New Batch Remittance                            │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ [1. Batch Header Information]                                                          │
│  Courier Service: [ Steadfast Courier ▼ ]    Statement ID: [ ST-REMIT-2026-07-28-091 ]  │
│  Bank TRX Ref:    [ EBL-TRX-9923841   ]    Deposit Date: [ 2026-07-28              ]  │
│  Bank Net Deposit: ৳2,45,000.00                                                        │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ [2. Add Orders / Bulk Match]                                                            │
│  (•) Select Pending Delivered Orders   ( ) Paste CSV / Tracking Numbers                │
│                                                                                        │
│  [✓] Select All (85 Orders)  | Search tracking/order...                                │
│  ┌───┬──────────────┬──────────────────┬──────────────┬──────────────┬──────────────┐  │
│  │   │ Order No.    │ Tracking / AWB   │ COD Collect  │ Courier Fee  │ Net Remit    │  │
│  ├───┼──────────────┼──────────────────┼──────────────┼──────────────┼──────────────┤  │
│  │ [✓│ ORD-2026-101 │ ST-9823412       │ ৳ 3,500.00   │ ৳   120.00   │ ৳ 3,380.00   │  │
│  │ [✓│ ORD-2026-102 │ ST-9823413       │ ৳ 1,200.00   │ ৳    80.00   │ ৳ 1,120.00   │  │
│  └───┴──────────────┴──────────────────┴──────────────┴──────────────┴──────────────┘  │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ [3. Reconciliation Summary Card]                                                       │
│  Total COD Collected: ৳ 2,54,000.00 | Total Courier Charges: ৳ 9,000.00                │
│  Net Batch Calculated: ৳ 2,45,000.00 | Bank Net Deposit:     ৳ 2,45,000.00                │
│  Variance: ৳ 0.00 [ Balanced ✓ ]                                                       │
│                                                                                        │
│                                                   [ Save Draft ]  [ Post Batch & Settle ]│
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. System Architecture & Database Schema (Supabase Postgres)

### 3.1 New Tables

#### `courier_remittance_batches` (Header Table)
Stores the batch metadata for courier payout transfers.

```sql
create table if not exists public.courier_remittance_batches (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  courier_service_id bigint not null references public.courier_services(id),
  batch_no text not null, -- Courier Statement ID / Batch No
  bank_trx_id text, -- Bank deposit transaction ID / reference
  payment_date date not null default current_date,
  method text not null default 'bank_transfer',
  
  -- Financial Totals
  gross_cod_amount numeric(12,2) not null default 0.00,
  courier_charges_amount numeric(12,2) not null default 0.00,
  net_deposited_amount numeric(12,2) not null default 0.00,
  allocated_amount numeric(12,2) not null default 0.00,
  variance_amount numeric(12,2) not null default 0.00,
  
  -- Status & Tracking
  status text not null default 'draft' check (status in ('draft', 'posted', 'voided')),
  note text,
  created_by uuid references auth.users(id),
  posted_at timestamptz,
  posted_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  
  constraint uq_tenant_courier_batch_no unique (tenant_id, courier_service_id, batch_no)
);

-- RLS & Indexing
alter table public.courier_remittance_batches enable row level security;

create index idx_courier_remittance_batches_tenant_status 
  on public.courier_remittance_batches (tenant_id, status);
create index idx_courier_remittance_batches_courier 
  on public.courier_remittance_batches (courier_service_id);
```

#### `courier_remittance_items` (Line Item Allocation Table)
Maps individual `shop_orders` and `global_invoices` to a remittance batch.

```sql
create table if not exists public.courier_remittance_items (
  id bigint generated always as identity primary key,
  batch_id bigint not null references public.courier_remittance_batches(id) on delete cascade,
  shop_order_id bigint not null references public.shop_orders(id),
  global_invoice_id bigint references public.global_invoices(id),
  
  tracking_number text,
  awb_number text,
  
  cod_collected_amount numeric(12,2) not null default 0.00,
  courier_charge_amount numeric(12,2) not null default 0.00,
  net_remitted_amount numeric(12,2) not null default 0.00,
  
  status text not null default 'matched' check (status in ('matched', 'unmatched', 'processed', 'error')),
  error_message text,
  created_at timestamptz not null default now(),
  
  constraint uq_batch_shop_order unique (batch_id, shop_order_id)
);

-- RLS & Indexing
alter table public.courier_remittance_items enable row level security;

create index idx_courier_remittance_items_batch 
  on public.courier_remittance_items (batch_id);
create index idx_courier_remittance_items_order 
  on public.courier_remittance_items (shop_order_id);
```

---

## 4. Backend Database RPC Specifications

### 4.1 RPC: `create_or_update_courier_remittance_batch`
Creates or updates a remittance batch draft with its line items.

```sql
create or replace function public.create_or_update_courier_remittance_batch(
  p_batch_id bigint default null,
  p_courier_service_id bigint default null,
  p_batch_no text default null,
  p_bank_trx_id text default null,
  p_payment_date date default current_date,
  p_net_deposited_amount numeric default 0.00,
  p_note text default null,
  p_items jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
-- Plpgsql implementation creating draft batch header and syncing courier_remittance_items
$$;
```

### 4.2 RPC: `process_courier_bulk_remittance_batch` (Atomic Posting)
Executes posting for an entire batch of orders atomically:

1. **Validation**:
   - Ensures batch status is `'draft'`.
   - Validates that every item references an order in `'delivered'` status with a posted `global_invoice_id`.
2. **Order Processing Loop**:
   - For each allocated item in `courier_remittance_items`:
     - Inserts a record into `global_payments` for the net remitted amount.
     - Inserts into `invoice_payments` linking the payment to `global_invoice_id`.
     - Updates `global_invoices.paid_amount` and recomputes payment status.
     - Updates `shop_orders.status` to `'payment_received'`.
     - Stamps `shop_orders.courier_remittance_ref` with the `batch_no` and `courier_bank_trx_id` with `bank_trx_id`.
     - Sets item status to `'processed'`.
3. **Batch Status Finalization**:
   - Sets batch status to `'posted'`.
   - Stamps `posted_at = now()` and `posted_by = auth.uid()`.

---

## 5. Frontend Integration Architecture

### 5.1 Directory & File Structure
```
web/src/modules/shop_order/
├── composables/
│   ├── useCourierRemittancesQuery.ts     # Query list of remittance batches
│   ├── useCourierRemittanceDetailQuery.ts # Query batch header + line items
│   ├── useCourierRemittanceMutations.ts   # Create draft, update, post batch
│   └── useDeliveredOrdersForCourierQuery.ts # Fetch un-remitted delivered orders by courier
├── components/
│   ├── RemittanceBatchHeaderForm.vue      # Courier, TRX ID, Bank Deposit input fields
│   ├── RemittanceOrderSelectorTable.vue   # Table with search, check-boxes, amounts
│   ├── RemittanceBulkPasteModal.vue       # CSV/Text paste modal for bulk tracking match
│   └── RemittanceReconciliationCard.vue   # Live totals & variance calculator card
└── pages/
    ├── CourierRemittancesListPage.vue     # History table of all remittance statements
    └── CourierRemittanceDetailPage.vue     # Batch create/edit & post page
```

### 5.2 TanStack Query Integration Pattern (Strict Compliance)
Adheres to `docs/TANSTACK_QUERY_GUIDE.md`:

- **Query Keys**:
  - Remittance List: `['courier-remittances', tenantId, { courierId, status }]`
  - Remittance Detail: `['courier-remittance-detail', tenantId, batchId]`
  - Un-remitted Delivered Orders: `['delivered-orders-unremitted', tenantId, courierId]`

- **Mutations & Cache Invalidation**:
  - On `post_courier_bulk_remittance_batch` success:
    - Invalidate `['courier-remittances']`
    - Invalidate `['delivered-orders-unremitted']`
    - Invalidate `['shop-orders']`
    - Invalidate `['global-invoices']`

---

## 6. Page Layout & UI Standards Compliance

Adheres strictly to `docs/PAGE_LAYOUT_AND_LOADERS.md`:

1. **Page Header Standard**:
   - Uses `q-breadcrumbs` navigation (`Dropship Desk > Courier Remittances > New Batch`).
   - Title with status badge (`Draft` / `Posted`).
   - Actions: `Save Draft` button and primary `Post Batch & Settle` CTA.

2. **Skeleton Loaders**:
   - Displays custom skeleton rows for `RemittanceOrderSelectorTable` while fetching pending delivered orders.

---

## 7. Explicit Out of Scope (Non-Goals for V1)

1. **Automated Bank Statement OCR**: V1 requires manual entry or CSV text pasting of tracking numbers; direct PDF image OCR is out of scope.
2. **Multi-Currency Settlement**: All courier remittances assume local operating currency (BDT ৳).
3. **Automated Direct API Disbursement Push**: V1 processes internal accounting reconciliation; automated API triggers to courier payout APIs are non-goals for this phase.

---

## 8. Definition of Done (Checklist)

- [ ] Supabase Migration created with `courier_remittance_batches` and `courier_remittance_items` tables and RLS policies.
- [ ] Database RPCs (`create_or_update_courier_remittance_batch`, `process_courier_bulk_remittance_batch`) written and tested.
- [ ] TanStack Query composables (`useCourierRemittancesQuery`, `useCourierRemittanceMutations`) created.
- [ ] Quasar UI components built using design tokens and responsive layout.
- [ ] Automated batch calculation and live variance check verified.
- [ ] Verification performed testing bulk posting of 50+ delivered orders simultaneously.
