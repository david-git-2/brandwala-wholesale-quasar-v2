# RPC and API contracts

**Job:** Definitive contract for kernel `SECURITY DEFINER` functions — parameters, returns, validations, errors. **Target** names use `kernel_*` prefix; **live** names are what Postgres exposes today.

Implementations: `supabase/schemas/bills_pays/03_rpcs.sql`. Types: grep `web/src/types/database.types.ts` for each function.

---

## Conventions

| Rule | Detail |
| :--- | :--- |
| Security | `SECURITY DEFINER`, `SET search_path = public` |
| Auth | `membership_has_module_action`, `is_tenant_staff`, or parent-tenant checks inside RPC |
| Errors | `RAISE EXCEPTION '…'` — message is user-facing in app; no SQLSTATE catalog required yet |
| Money | `numeric(12,2)` on bills/pays; FX `numeric(15,6)` on rates |
| Returns | Row type (`bills`, `pays`) or `jsonb` bundle for reads |

---

## `kernel_upsert_draft_bill` (target)

**Live:** `create_sales_invoice`, `create_sales_invoice_from_payload`, shipment `sync_shipment_ap_bills` (draft only), compose payloads.

```text
kernel_upsert_draft_bill(
  p_parent_tenant_id bigint,
  p_from_profile_id bigint,
  p_to_profile_id bigint,
  p_source_type text,
  p_source_id text,
  p_source_key text DEFAULT NULL,
  p_settlement_kind text DEFAULT NULL,  -- take | condition
  p_currency_code text DEFAULT 'BDT',
  p_lines jsonb DEFAULT '[]'
) RETURNS bills
```

| Validation | Error (typical) |
| :--- | :--- |
| Caller is staff on `p_parent_tenant_id` | Access denied |
| Profiles same books tenant | Profile tenant mismatch |
| AP lines: no `global_stock_id` | (adapter-specific) |
| Unique source plug | Duplicate bill for source |

---

## `kernel_issue_bill` (target)

**Live:** `issue_sales_invoice`, `issue_shipment_ap_bills`, `issue_bill_adjustment` (notes).

```text
kernel_issue_bill(p_bill_id bigint) RETURNS bills
```

| Validation | Error |
| :--- | :--- |
| `invoice_status = draft` | Already issued |
| Stock lines: ATP / qty | `insufficient ATP` / `Insufficient stock` |
| Empty lines | Cannot issue empty invoice |
| AP | No stock movement; may require shipment `costs_locked` for batch issue |

Side effects: FIFO deduct, `invoice_status → issued`, stamp totals, movement rows.

---

## `kernel_post_payment` (target)

**Live:** `post_customer_receipt_with_allocations` (pay in), `post_ap_payout_with_allocations` (pay out).

```text
kernel_post_payment(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_amount numeric,
  p_received_on date,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_instruments jsonb DEFAULT '[]',
  p_allocations jsonb DEFAULT '[]',  -- [{ "bill_id", "amount" }]
  p_source text DEFAULT 'customer_cash',
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL  -- target only
) RETURNS pays
```

| Validation | Error |
| :--- | :--- |
| `sum(alloc) ≤ p_amount` | Allocation exceeds payment |
| Each alloc ≤ bill net due | Over-allocation |
| Tenant cash move without point | (target — [BP15](../features/bills_pays/00-gaps.md)) |
| FX pair when foreign_amount set | Rate required |

Side effects: `pays`, `pay_allocations`, `pay_instruments`, `cashbook_entries` (+ pots when wired), `unallocated_amount` → custody ledger.

---

## `kernel_create_bill_adjustment` (target)

**Live:** `create_bill_adjustment`, then `issue_bill_adjustment` if draft.

```text
kernel_create_bill_adjustment(
  p_parent_bill_id bigint,
  p_kind text,              -- credit_note | debit_note
  p_amount numeric,
  p_reason text,
  p_issue boolean DEFAULT true,
  p_refund_amount numeric DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_lines jsonb DEFAULT '[]'
) RETURNS bills
```

| Validation | Error |
| :--- | :--- |
| Parent issued | Parent not issued |
| Positive amount | Invalid amount |
| Kind enum | Invalid kind |

---

## `kernel_reverse_payment` (target)

**Live:** Partial — collect void paths; full reverse [BP12](../features/bills_pays/00-gaps.md) / [WA13](../features/bills_pays/00-gaps.md).

```text
kernel_reverse_payment(
  p_pay_id bigint,
  p_reason text,
  p_reverse_leftover boolean DEFAULT true
) RETURNS pays  -- or jsonb audit bundle
```

| Validation | Error |
| :--- | :--- |
| Pay exists, not already reversed | Not found / already reversed |
| Cheque / AP rules | (product-specific) |

Must: delete or negate allocs, restore bill `due_amount` via kernel refresh, reverse custody credits — **without** editing issued `total_amount`.

---

## Read RPCs (stable)

| RPC | Returns |
| :--- | :--- |
| `get_bill_net_balances(p_bill_id)` | `jsonb` — face, notes, paid, due |
| `get_bill_detail_bundle` / list helpers | grep schema — prefer these over raw `pay_allocations` sums |

Adapters must use read RPCs ([05-ADAPTER-INTEGRATION-GUIDE](05-ADAPTER-INTEGRATION-GUIDE.md)).
