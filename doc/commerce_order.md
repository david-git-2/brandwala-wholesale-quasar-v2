# Commerce Order Module

The `commerce_order` module manages recipient order intake and admin-side order lifecycle for ecommerce.

## Key Features

- Place orders from cart with recipient details.
- Persist charges:
  - `delivery_charge`
  - `wrapping_charge`
  - `cod`
  - `invoice_print_charge`
  - `is_delivery_charge_inclusive`
- Track order statuses:
  - `placed`
  - `reviewing`
  - `shipping`
  - `delivered`
  - `cancelled`
- Generate linked commerce invoices.

## Pricing Rule

- Inclusive delivery: delivery is not added to total but is treated as profit-impact cost.
- Exclusive delivery: delivery is added to total.

## Tenant 11 Notes

- Active and used as the primary order intake from `commerce_cart`.
- Order items are later tied to real inventory item IDs for accurate costing.
