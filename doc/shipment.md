# Shipment Management & Accounting

The `shipment` module handles inbound logistics tracking, container-level inventory receiving, and calculates container-level financial performance.

---

## 1. Costing Model

When items arrive in a shipment, their unit landing cost is calculated dynamically considering currency conversion and overhead factors:
*   **Currency Rates**: cargo rates, GBP conversion rates, etc.
*   **Inspections and Splits**: Units are cataloged as received, damaged, or stolen.

---

## 2. Shipment Accounting Metrics

The Shipment Accounting Detail screen computes overall container performance by pulling data from both wholesale sales (`inventory_accounting_entries`) and B2B storefront orders (`commerce_accounting`) via the unified `v_shipment_accounting_ledger` view.

The financial metrics are defined as follows:

### A. Cost Metrics (Cost Side)
*   **Shipment Cost Total (BDT)**: The total landing cost of all items received in the shipment.
    $$\text{Shipment Cost Total} = \sum (\text{Received Qty}_i \times \text{Unit Cost}_i)$$
*   **Damage/Stolen Loss (BDT)**: The landing cost loss from goods received as damaged or stolen.
    $$\text{Loss Total} = \sum (\text{Unit Cost}_i \times (\text{Damaged Qty}_i + \text{Stolen Qty}_i))$$
*   **Usable Inventory Cost (BDT)**: The cost of received stock that is in sellable condition.
    $$\text{Usable Cost} = \text{Shipment Cost Total} - \text{Loss Total}$$
*   **Sold COGS (BDT)**: The cost of units that have been sold.
    $$\text{Sold COGS} = \sum \text{total\_cost\_amount} \quad \text{(from unified ledger entries)}$$
*   **Remaining Inventory Cost (BDT)**: The value of remaining inventory still in stock.
    $$\text{Remaining Inventory Cost} = \text{Usable Cost} - \text{Sold COGS}$$

### B. Revenue & Profit Metrics (Earning Side)
*   **Invoice Revenue (BDT)**: The net revenue generated from the shipment.
    $$\text{Invoice Revenue} = \sum \text{total\_sell\_amount} \quad \text{(from unified ledger entries)}$$
*   **Realized Gross Profit (BDT)**: The gross profit realized from sales.
    $$\text{Realized Gross Profit} = \sum \text{gross\_profit\_amount} \quad \text{(from unified ledger entries)}$$
*   **Paid Amount (BDT)**: The total amount paid by clients. Fetched from normal `invoices` (column `paid_amount`) and commerce B2B invoices (column `amount_paid`) using composite keys (`normal_{id}` and `commerce_{id}`).
*   **P/L vs Shipment Cost (BDT)**: Net profit/loss relative to the initial container cost.
    $$\text{P/L vs Shipment Cost} = \text{Invoice Revenue} - \text{Shipment Cost Total}$$
