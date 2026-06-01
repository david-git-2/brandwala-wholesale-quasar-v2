# Shipment Module

The `shipment` module manages inbound shipment batches and their linkage to inventory records.

## Key Features

- Create shipment records and shipment items.
- Track status and movement of inbound goods.
- Link shipment items to inventory items (`source_type = shipment`).

## Commerce Relationship

- When a commerce invoice item uses an inventory row sourced from shipment,
  `shipment_item_id` can be preserved for traceability in commerce order/accounting.

## Tenant 11 Notes

- Shipment is active and supports inventory provenance for ecommerce costing.
