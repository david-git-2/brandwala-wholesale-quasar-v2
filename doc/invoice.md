# Invoice Management

The `invoice` module handles billing, itemized tracking, payment allocations, and customer return routing for wholesale orders.

---

## 1. Invoice Discount Spreading Policy

When a head-level discount is applied or modified on an invoice, the system proportionally distributes it down to each individual line item to calculate the net sell price and gross margins accurately.

### Technical Implementation

*   **Trigger**: `trg_invoice_discount_spreader` on `invoices` table (`after update of discount_amount, subtotal_amount`).
*   **Formula**:
    The discount for an item $i$ is calculated as:
    $$\text{Line Discount}_i = \text{Round} \left( \frac{\text{Line Subtotal}_i}{\text{Invoice Subtotal}} \times \text{Invoice Discount}, 2 \right)$$
    *To prevent rounding discrepancies, the final item in the invoice receives the remaining undistributed discount.*
*   **Accounting Side Effects**:
    The trigger automatically updates the corresponding row in `inventory_accounting_entries`:
    *   $\text{Sell Price Amount} = \frac{\text{Original Subtotal} - \text{Line Discount}}{\text{Quantity Sold}}$
    *   $\text{Total Sell Amount} = \text{Original Subtotal} - \text{Line Discount} - \text{Return Amount}$
    *   $\text{Gross Profit Amount} = \text{Total Sell Amount} - \text{Total Cost Amount}$

---

## 2. Flexible Customer Returns Policy

When items are returned by customers, the system supports a disjoint stock pool model and provides two distinct inventory routing methods to handle the returned stock.

### Disjoint Stock Pools
Returned quantities are routed directly to their respective disjoint pools to ensure accurate bookkeeping:
*   **Normal Sealed Units** $\rightarrow$ `available_quantity`
*   **Open Box Units** $\rightarrow$ `open_box_quantity`
*   **Damaged Units** $\rightarrow$ `damaged_quantity`

### Return Routing Modes

Admins can choose where to route the returned items via the `apply_invoice_item_return` RPC:

#### Mode A: Return to Existing Batch (`p_return_to_new_batch = false`)
*   Returned quantities are added directly back to the original source inventory batch (`inventory_stocks` row).
*   Logs an `adjustment` type movement record on the original inventory item.

#### Mode B: Return to New Separate Batch (`p_return_to_new_batch = true`)
*   Creates a new separate batch group (`inventory_items`) copying metadata from the original item and appending `" returned"` to its name.
*   Creates a new `inventory_stocks` record initialized with the returned quantities.
*   Logs a `received` type movement record on the new item batch, ensuring returns are kept isolated.

### Financial Adjustments
Upon a return, the system:
1.  Decrements the net active `quantity` in `inventory_accounting_entries` and updates `return_quantity` and `return_amount`.
2.  Recalculates `total_sell_amount`, `total_cost_amount` (COGS on net active items), and `gross_profit_amount`.
3.  Recalculates the invoice `subtotal_amount` and `total_amount`.
4.  Invokes `recompute_invoice_payment_status` to determine if the invoice status is now paid, due, or partially paid.
