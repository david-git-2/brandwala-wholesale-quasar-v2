# Accounting flows and golden scenarios

**Job:** Concrete row-by-row state across kernel entities for end-to-end workflows — regression baselines and golden tests. Narrative: [money-story](../features/bills_pays/money-story.md).

Tables (live): `bills`, `bill_lines`, `pays`, `pay_allocations`, `cashbook_entries`, `cashbook_accounts`, `profiles`.

---

## Scenario A — Dropship order, courier net remittance

**Actors:** Tenant T, dropshipper profile P, courier profile C. Order O at ship. **COD ≠ sales.**

### At ship (dispatch)

| Table | Rows (effect) |
| :--- | :--- |
| `bills` | **B1** AR: tenant → merchant, `total_amount = 1500`, `invoice_status = issued`, `shop_order_id = O` (live) |
| `bills` | **B2** AP: courier AP `total_amount = 80`, `invoice_type = ap`, issued |
| `bill_lines` | B1: lines totaling 1500 (not COD 2200) |
| `shop_orders` | `global_invoice_id` → B1 (live FK) |

### At delivery (courier custody)

| Table | Rows |
| :--- | :--- |
| `cashbook_entries` | Courier entity **credit 2200** (custody — not tenant sales) |

### Remittance (bank net 2120)

| Step | Table | Effect |
| :--- | :--- | :--- |
| Pay in | `pays` | **Pay R**: `amount = 2120`, `source = courier_remittance` |
| Alloc | `pay_allocations` | 1500 → B1 |
| Leftover | custody | Merchant P **+620** |
| Cash | `cashbook_entries` | Tenant operating **+2120** |

### Merchant payout later

| Step | Effect |
| :--- | :--- |
| `dispense_middleman_payout_from_tenant` | **620** out; no alloc to B1 |

**Golden assert:** Sales = 1500; cash in = 2120; merchant custody 0 after payout.

---

## Scenario B — Multi-currency shipment AP and landed cost

Shipment **S-42**. Target: one bill per `(bucket, currency)`; live may differ until WA15.

| `bills` | `source_key` | Currency |
| :--- | :--- | :--- |
| AP-1 | `material:USD` | USD |
| AP-2 | `freight:GBP` | GBP |

Pay freight: `exchange_rate = 155.50` frozen on `cashbook_entries`. `refresh_global_shipment_fx_from_ap_payments()` uses **paid** rates for landed cost.

---

## Scenario C — Wholesale take with overpayment and custody offset

| Step | State |
| :--- | :--- |
| B1 issued | `total_amount = 1500` |
| Collect 2000 | Alloc 1500 → B1; custody **+500** |
| B2 issued | 800 |
| Settle B2 | Apply 500 custody + 300 cash → B2 paid |

**Golden assert:** No extra bill for 500; `get_bill_net_balances(B2).due = 0`.

---

## Scenario D — Wholesale take (simple)

Buyer ABC, sell 1500, pay 1500 cash — see [money-story § Wholesale take](../features/bills_pays/money-story.md).

| Layer | Store |
| :--- | :--- |
| BILL | Take issued, paid |
| PAY + ALLOC | 1500 → bill |
| CASHBOOK | Tenant +1500 |

---

## Test harness

Compare RPC ids + `get_bill_net_balances` JSON to scenarios above. Reconcile with [08-AUDIT-RECONCILIATION-AND-RUNBOOK](08-AUDIT-RECONCILIATION-AND-RUNBOOK.md). Roadmap: [07-TDD-AND-VERIFICATION-SUITE](07-TDD-AND-VERIFICATION-SUITE.md).
