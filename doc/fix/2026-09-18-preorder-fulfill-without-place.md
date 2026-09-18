# Pre-order fulfill without vendor PO

## Problem

Fulfill desk could not save stock picks when Demand desk had no vendor PO (`placed_quantity = 0`). DB enforced `delivered_quantity <= placed_quantity`.

Mark ready also wrote backlog from `confirmed - placed` instead of `confirmed - picks`, and catalog proforma invoices did not set `sales_invoices.shop_order_id`.

## Fix

- Drop `preorder_demand_delivered_lte_placed_check`.
- `upsert_preorder_demand`: cap picks at confirmed need (`open_qty`), not placed qty.
- `staff_set_catalog_ordered_qty`: backlog shortfall = confirmed − `preorder_demand.delivered_quantity`.
- `create_invoice_from_preorder_demand_document`: set `sales_invoices.shop_order_id` after create (not via payload — `create_sales_invoice_from_payload` only accepts dropship `shop_order_id`).
- Fulfill UI: allocation target = confirmed qty.

## Flow

Demand place order (vendor PO) is optional. When stock is on hand, staff pick on Fulfill → Mark ready → proforma from picks only.
