# Commerce Cart Module

This document describes cart behavior used by Tenant 11 ecommerce flow (`commerce_cart`).

## Key Features

- Customer adds products by quantity.
- Customer sets recipient-facing sell price.
- Recipient form captures:
  - name
  - phone
  - shipping address
  - delivery charge
  - wrapping charge
  - COD
- Optional invoice print charge support.

## Summary Logic

- Grand total includes wrapping/COD/print always.
- Delivery is added only when delivery is exclusive.
- Inclusive delivery reduces profit instead of increasing total.

## Output

Cart placement writes into `commerce_orders` and `commerce_order_items` through `place_commerce_order`.
