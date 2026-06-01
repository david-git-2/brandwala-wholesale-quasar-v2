# Inventory Module

The `inventory` module provides stock source-of-truth for ecommerce and shipment-driven stock control.

## Key Features

- Store item-level cost and product linkage.
- Track stock quantities:
  - available
  - reserved
  - damaged
  - stolen
  - expired
  - open box
- Track inventory movements for audit.

## Ecommerce Integration

- Commerce invoice rows select a specific inventory item.
- Selected inventory cost is copied to commerce order item cost.
- Stock decreases on assignment and increases on de-assignment/removal.

## Tenant 11 Notes

- Inventory is active and mandatory for reliable commerce cost/accounting accuracy.
