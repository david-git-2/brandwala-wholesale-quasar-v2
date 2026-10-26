# State machines and lifecycles

**Job:** Valid transitions and triggers — bill states (`draft` → `issued` → `voided`), `take` vs `condition` revenue timing, credit/debit notes, pay allocation vs profile custody/leftover. Live enum: `invoice_status` on `bills`; payment: `payment_status` (`due` / `partially_paid` / `paid`).

---

## 1. Bill lifecycle

```text
[ draft ] ── issue_* ──► [ issued ] ──(alloc + paid)──► payment_status = paid
    │                         │
 void (draft only)       void (only if 0 pays & rules allow)
    │                         │
    ▼                         ▼
[ voided ]               [ voided ]

Issued + paid or adjusted after issue:
    └──► child [ credit_note | debit_note ] (draft → issue via create_bill_adjustment / issue_bill_adjustment)
```

| Transition | Typical RPC / trigger | Guards |
| :--- | :--- | :--- |
| draft → issued | `issue_sales_invoice`, `issue_shipment_ap_bills`, dropship issue at ship, `issue_bill_adjustment` | Lines valid; stock FIFO when stock lines; AP has no stock lines |
| draft → voided | void draft helpers | No issued stock moves |
| issued → voided | void bill RPCs | **No pays** (or reverse pays first); no illegal stock state |
| issued → note | `create_bill_adjustment` | Parent issued; amount & kind per kernel rules |

**Do not:** issue a bill from the pay desk ([spec US-3](../features/bills_pays/spec.md)).

---

## 2. Settle and revenue timing

Target column: `settlement_kind`. Live stock AR often uses `channel_meta.delivery_kind` (`take` | `condition`).

| `settlement_kind` | Stock movement | Revenue recognition | Net due / aging |
| :--- | :--- | :--- | :--- |
| `take` | Deduct at **issue** (FIFO on `global_stock_id` lines) | At **issued** | Firm AR until paid |
| `condition` | Stock leaves on issue (memo / condition path) | When **paid** (not at issue) | Unpaid condition is not firm sales in reports |
| `null` (AP, fees, notes) | None on AP paper | N/A (expense / COGS via shipment costing) | AP obligation only |

Walk-in: **take** only. Proforma / delivery paper: **not** an issued bill until close → bill.

Dropship merchant bill: **take**-like — issued at ship; sales at issue amount (merchant total, not COD face). See [money-story](../features/bills_pays/money-story.md).

---

## 3. Payment and allocation

| Flow | Cashbook | Bill balance | Overflow |
| :--- | :--- | :--- | :--- |
| **Pay in** (collect, remittance) | Credit tenant pot / account | `pay_allocations` reduce `due_amount` | `unallocated_amount` → profile custody ledger |
| **Pay out** (AP, merchant dispense) | Debit tenant pot | Alloc to AP bills | Foreign alloc may restamp shipment FX (`post_ap_payout_with_allocations` → landed cost) |
| **Leftover apply** | Debit profile custody | Zero-cash or internal alloc row to target bill | Consumes custody balance |

Writers (live):

- Collect / remittance: `post_customer_receipt_with_allocations`
- AP payout: `post_ap_payout_with_allocations`
- Dropship profit payout: `dispense_middleman_payout_from_tenant` (cashbook, not bill alloc)

**Net balance reads:** `get_bill_net_balances(p_bill_id)` — issued face ± notes − allocations. Do not re-sum in feature code ([BP10](../features/bills_pays/00-gaps.md)).

---

## 4. Shipment AP sync (adapter state)

| Shipment costs | AP bills |
| :--- | :--- |
| `costs_locked = false` | `sync_shipment_ap_bills` refreshes **draft** (and may update unpaid issued per sync rules) |
| `lock_global_shipment_costs` | Sync then `issue_shipment_ap_bills` → **issued** |
| After issue | Commercial change = **credit/debit note**, not silent header edit |

Dropship courier AP: **issued at ship** (`upsert_dropship_courier_ap_bill`).

---

## 5. Stock sync touchpoints (kernel edges)

| Event | Stock |
| :--- | :--- |
| Issue wholesale / take bill | `global_stocks` deduct + movement (FIFO line) |
| Void issued bill (allowed) | Restore stock per void RPC |
| Dropship submit / pick | Allocation / held availability (shop_order); merchant bill at ship |
| AP issue | No stock lines on AP bill; costing from shipment + pays |

Stock ATP for shop carts includes draft invoice holds + cart qty (`global_stock_hold_qty`) — see procurement/shop specs; not part of bill `payment_status`.
