# Products Module

The `products` module manages the product catalog used by cart/order/invoice flows.

## Key Features

- Product master data (name, code, barcode, image, etc.).
- Pricing fields used by commerce UI.
- Product lookup for inventory mapping.

## Commerce Relationship

- Cart/order items are product-based at input time.
- Invoice workflow maps product lines to concrete inventory items for final cost accounting.

## Tenant 11 Notes

- Active and used by commerce cart/order/invoice as the catalog source.
