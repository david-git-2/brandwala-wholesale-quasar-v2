# Shipment and Commerce Accounting

The accounting system is responsible for calculating margins, gross profit, and tracking payments for both normal wholesale invoices and B2B storefront commerce invoices.

## Core Architecture

To track profitability and payment status across various business flows, the system uses two main tables and aggregates them through a unified shipment accounting ledger view.

### 1. Database Entities

*   **`inventory_accounting_entries`**: Stores financial records for normal (admin) wholesale invoice item sales.
*   **`commerce_accounting`**: Stores B2B storefront commerce order item costing and selling values.
*   **`v_shipment_accounting_ledger`**: A unified ledger view that `UNION ALL`s records from both of the above tables, standardizing their column structures so they can be parsed together for shipment-level financial analysis.

### 2. Unified Shipment Accounting Ledger View (`v_shipment_accounting_ledger`)

This view combines wholesale and commerce B2B orders to offer a single source of truth for shipment tracking. It maps the following fields:

| Field Name | Type | Description | Source (Normal) | Source (Commerce) |
| :--- | :--- | :--- | :--- | :--- |
| `type` | `text` | Indicator of the origin order type | `'normal'` | `'commerce'` |
| `id` | `bigint` | Record identifier | `iae.id` | `ca.id` |
| `tenant_id` | `bigint` | Scoped tenant ID | `iae.tenant_id` | `ca.tenant_id` |
| `invoice_id` | `bigint` | Associated invoice identifier | `iae.invoice_id` | `coi.invoice_id` |
| `inventory_item_id` | `bigint` | Linked inventory batch ID | `iae.inventory_item_id` | `ca.inventory_item_id` |
| `product_id` | `bigint` | Catalog product identifier | `iae.product_id` | `coi.product_id` |
| `quantity` | `numeric` | Net quantity sold (after returns) | `iae.quantity` | `coi.quantity` |
| `cost_amount` | `numeric` | Unit cost of the item in BDT | `iae.cost_amount` | `ca.cost_bdt` |
| `sell_price_amount` | `numeric` | Realized unit sell price (after discount) | `iae.sell_price_amount` | `ca.sell_price_bdt` |
| `total_cost_amount` | `numeric` | Cost of Goods Sold (COGS) | `iae.total_cost_amount` | `ca.cost_bdt * coi.quantity` |
| `total_sell_amount` | `numeric` | Net revenue (sell price * net qty - discount) | `iae.total_sell_amount` | `ca.sell_price_bdt * coi.quantity` |
| `gross_profit_amount` | `numeric` | Realized profit (total sell - total cost) | `iae.gross_profit_amount` | `(sell_price_bdt - cost_bdt) * qty` |
| `status` | `text` | Payment status (`'paid'` or `'due'`) | `iae.status` | `is_customer_group_paid` state |
| `shipment_id` | `bigint` | ID of the source container/shipment | `iae.shipment_id` | `si.shipment_id` |
| `shipment_item_id` | `bigint` | Source shipment item ID | `iae.shipment_item_id` | `ca.shipment_item_id` |
| `entry_date` | `date` | Date of the transaction entry | `iae.entry_date` | `ca.created_at::date` |

---

## Business Rules & Financial Math

### 1. Gross Profit Calculation

For both normal and commerce flows, Gross Profit is calculated as:
$$\text{Gross Profit} = \text{Total Sell Amount} - \text{Total Cost Amount}$$

*   **Total Cost Amount (COGS)**: Represents the cost of units that were *actually sold and not returned*.
    $$\text{Total Cost Amount} = (\text{Quantity Sold} - \text{Quantity Returned}) \times \text{Unit Cost}$$
*   **Total Sell Amount (Revenue)**: Represents the net realized revenue after applying both line returns and proportional header discounts.
    $$\text{Total Sell Amount} = (\text{Quantity Sold} \times \text{Original Unit Price}) - \text{Proportional Discount} - \text{Return Amount}$$

### 2. Payment Status Syncing

*   **Normal Invoices**: When payments are allocated to normal invoices (using the payment allocation RPC), the system runs `recompute_invoice_payment_status(invoice_id)` which updates the invoice's `paid_amount` and `payment_status`. A trigger updates `inventory_accounting_entries.status` to `'paid'` when the invoice is marked fully paid.
*   **Commerce Storefront Invoices**: When a commerce invoice status changes (`is_customer_group_paid`), the database trigger `trg_commerce_invoice_payment_status_sync` automatically updates all associated `commerce_accounting` rows to propagate the status to `'paid'` or `'due'`, keeping the ledger updated.
