# B2B Storefront Commerce Invoices

The `commerce_invoice` module manages billing, payment status tracking, and inventory allocation for B2B storefront commerce orders.

---

## 1. Commerce Discount Spreading Policy

When a head-level discount is applied to a B2B commerce invoice, it is proportionally distributed across the commerce order items to calculate their net wholesale sell prices.

### Implementation

*   **Trigger**: `trg_commerce_invoice_discount_spreader` on `commerce_invoices` (`after update of discount_amount, total_amount`).
*   **Trigger Condition**: Fires when the header discount is adjusted or the invoice `total_amount` changes (ensuring it runs after items are added, removed, or updated).
*   **Formula**:
    The discount for a commerce item $i$ is calculated as:
    $$\text{Line Discount}_i = \text{Round} \left( \frac{\text{Quantity}_i \times \text{Recipient Price}_i}{\text{Commerce Invoice Subtotal}} \times \text{Invoice Discount}, 2 \right)$$
    *Rounding adjustments are allocated to the last order item.*
*   **Accounting Side Effect**:
    Updates `sell_price_bdt` in the `commerce_accounting` table to propagate the discounted unit price downstream:
    $$\text{sell\_price\_bdt} = \frac{(\text{Original Sell Price} \times \text{Quantity}) - \text{Line Discount}}{\text{Quantity}}$$

---

## 2. Commerce Payment Status Synchronization

To ensure that revenue from B2B customer group storefront orders is marked as paid or outstanding in shipment ledger calculations, the database synchronizes payment statuses automatically.

*   **Trigger**: `trg_commerce_invoice_payment_status_sync` on `commerce_invoices` (`after insert or update of is_customer_group_paid`).
*   **Action**: Automatically sets `commerce_accounting.is_customer_group_paid` to `true` or `false` for all order items linked to the invoice, ensuring that the ledger immediately reflects whether the transaction is `'paid'` or `'due'`.
