# Dropship Management Desk (v1 UI shell)

Staff-facing settlement desk for dropship orders after delivery. **Current state: dummy UI only** — no RPCs, wallet writes, or invoice generation are wired.

Related: [`SHOP_ORDER.md`](./SHOP_ORDER.md) (dropship desk inventory), [`WALLET.md`](../wallet/WALLET.md) (ledger rules), existing [`DropshipFinanceHubPage`](../../web/src/modules/shop_order/pages/DropshipFinanceHubPage.vue) (3-step courier remittance flow).

---

## 1. Routes (UI shell)

| Route | Page | Status |
| :--- | :--- | :--- |
| `/:tenantSlug?/app/shop/dropship-management` | [`DropshipManagementPage.vue`](../../web/src/modules/shop_order/pages/DropshipManagementPage.vue) | Dummy list + search/filter |
| `/:tenantSlug?/app/shop/dropship-management/:id` | [`DropshipManagementDetailPage.vue`](../../web/src/modules/shop_order/pages/DropshipManagementDetailPage.vue) | Dummy settlement form |

Dummy seed data: [`dropshipManagementDummyOrders.ts`](../../web/src/modules/shop_order/data/dropshipManagementDummyOrders.ts).

---

## 2. List page fields

| Field | Source (today) | Target (live) |
| :--- | :--- | :--- |
| Order name | `name` | `shop_orders.order_no` |
| Merchant | `merchant` | Reseller / customer group display name |
| Recipient | `recipient` | Delivery contact name |
| Courier | `courierName` | Assigned courier service |
| Status | `status` | `shop_orders.status` (desk-specific subset TBD) |
| Calculated COD | `calculatedCod` | Confirmed resell invoice total |

---

## 3. Detail page — field inventory

### Header / context

| Field | UI | Notes |
| :--- | :--- | :--- |
| Order name | Title | |
| Merchant · Recipient | Subtitle | |
| Status badge | Header | |
| Recipient phone | Meta strip | |
| Courier name | Meta strip | |
| AWB | Meta strip | |

### COD summary

| Field | Editable | Notes |
| :--- | :--- | :--- |
| **Total calculated COD** | No (auto) | Expected COD from confirmed resell invoice before delivery adjustments |
| **Total collected COD** | Yes (input) | Actual cash collected by courier at delivery |

Show variance when collected ≠ calculated.

### Cost breakdown (invoice paper summary layout)

Two columns per row — **label** on the left, **value or input** on the right. Same pattern as `DropshipOrderConfirmedInvoicePaper` summary. Auto rows show **Auto** under the label.

| Row | Right side | Notes |
| :--- | :--- | :--- |
| Total calculated COD | Amount (auto) | Expected COD from confirmed resell invoice |
| Total collected COD | Number input | Actual cash collected by courier |
| Recipient pays | Amount (auto) | Resell items total |
| Delivery | Amount input + payer toggle | Payer: recipient / merchant / company |
| Print | Amount input + payer toggle | Same pattern |
| Packing | Amount input + payer toggle | Same pattern |
| Return cost | Amount input + payer toggle | Same pattern |
| Return reason note | Textarea | Free text when return cost &gt; 0 |
| Discount (company pay) | Amount input | **Deduct from company profit** |
| Reseller purchase cost | Amount input | Wholesale / floor purchase total |
| Reseller profit | Amount (auto) | See §4 |
| Total cost | Amount (auto) | Purchase + all charge lines |
| Company profit | Amount (auto) | After discount |

### Settlement action

| Control | Label | Wired |
| :--- | :--- | :--- |
| Primary button | **Payment received & wallet updated** | No |

---

## 4. Proposed calculated formulas (discussion — not locked)

Dummy UI uses placeholder math so the page feels alive. **Replace before wiring backend.**

```
total_cost = reseller_purchase_cost
           + delivery + print + packing + return_cost

reseller_profit = total_collected_cod
                - reseller_purchase_cost
                - sum(charges where payer = merchant)

company_profit = reseller_profit - discount_company_pay
```

**Open questions**

1. Should **company-paid** charges reduce `company_profit` directly (in addition to discount)?
2. Should **recipient-paid** charges affect `recipient_pays` vs `total_collected_cod` reconciliation?
3. How do **partial delivery / partial return** qty changes flow from processing desk into this page?
4. Is `total_collected_cod` the single source of truth for courier remittance, or does finance hub still own step 2?

---

## 5. Wallet flow — to discuss (not wired)

Today’s live dropship money path is the **Finance Hub 3-step** model ([`WALLET.md`](../wallet/WALLET.md) §2.2):

```mermaid
flowchart LR
    A["1. Delivered costing"] --> B["2. Courier remittance"]
    B --> C["3. Merchant payout"]
```

This desk proposes a **single “payment received”** action. Options to decide:

| Option | Behavior | Pros | Cons |
| :--- | :--- | :--- | :--- |
| **A. Replace finance hub for dropship** | One RPC posts courier credit + tenant cash + merchant margin atomically | Faster ops UX | Large transactional RPC; harder reversals |
| **B. Desk = step 1 only** | Button calls existing `confirm_delivered_costing` equivalent | Reuses ledger rules | Staff still visit finance hub for remittance/payout |
| **C. Desk orchestrates 3 RPCs** | UI runs steps 1→3 in sequence with preview | Clear audit trail | More clicks; partial failure handling |
| **D. Queue + async job** | Button enqueues settlement job | Safe retries | Delayed feedback |

**Ledger entities (expected)**

| Wallet | Movement (sketch) |
| :--- | :--- |
| Courier | Credit `total_collected_cod` on delivery confirm |
| Tenant (operating) | Credit on bank remittance (if split from A) |
| Merchant | Credit `reseller_profit` on payout |
| Tenant | Debit merchant payout + company-paid discounts |

Need product decision: does **“wallet updated”** mean courier only, or courier + merchant + tenant in one click?

---

## 6. Invoice creation — to discuss (not wired)

Existing dropship invoices:

| Invoice | Page / component | When |
| :--- | :--- | :--- |
| Internal confirmed invoice | `DropshipOrderConfirmedInvoicePaper` | After order confirm / processing |
| Recipient resell invoice | Customer invoice preview | Ready for pickup / print |

**Open questions for this desk**

1. Does settlement **create** a new invoice, or **finalize** amounts on an existing `global_invoices` row?
2. Should discount (company pay) appear as a line item, metadata, or separate credit note?
3. Are print/packing charges invoice lines or fulfillment metadata only?
4. Link to `global_invoices` vs dropship-specific snapshot table for immutable settlement audit?

**Suggested default (for review):**

- Settlement does **not** create a new invoice document.
- It writes a **`dropship_settlement_snapshot`** (name TBD) keyed by `shop_order_id` with all charge lines, payers, collected COD, and computed profits.
- Recipient-facing invoice stays unchanged; internal PDF may append settlement summary later.

---

## 7. Next implementation steps (when approved)

1. Agree formulas (§4) and wallet option (§5).
2. Add migration: settlement snapshot table + RPC `get_dropship_management_order` / `save_dropship_settlement_draft`.
3. Wire list to real orders (delivered + awaiting settlement filter).
4. Wire settlement button to chosen wallet RPC(s).
5. Add TanStack query keys under `shopOrderQueryKeys`.
6. Remove [`dropshipManagementDummyOrders.ts`](../../web/src/modules/shop_order/data/dropshipManagementDummyOrders.ts).

---

## 8. Out of scope (v1 shell)

- Permissions beyond `shop_order_mgmt`
- Reversal / edit-after-settlement
- Multi-currency
- Integration with wholesale `global_invoices` AR
