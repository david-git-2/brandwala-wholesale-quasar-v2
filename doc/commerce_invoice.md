# Commerce Invoice Module

The `commerce_invoice` module handles billing and item-level inventory assignment for ecommerce orders.

## Key Features

- Create invoice from a commerce order.
- Maintain invoice totals (`total_amount`, `amount_paid`, `amount_due`).
- Add/remove invoice items.
- Assign/change inventory item per invoice row.
- Auto-sync item `cost_bdt` from selected inventory item.
- Maintain stock movement on assignment/removal.

## Total Calculation Rule

Invoice total uses:

- `subtotal + wrapping + cod` when delivery is inclusive
- `subtotal + delivery + wrapping + cod` when delivery is exclusive

## Tenant 11 Notes

- This module is active and integrated with `inventory` and `commerce_accounting`.
- Invoice item inventory assignment is required for accurate accounting and stock movement.
