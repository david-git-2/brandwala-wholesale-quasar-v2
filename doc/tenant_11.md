# Tenant 11 Documentation

This document captures the currently enabled modules and operational behavior for **Tenant ID 11**.

## Tenant Summary

- `tenant_id`: `11`
- Commerce stack is active (`commerce_shop`, `commerce_cart`, `commerce_order`, `commerce_invoice`, `commerce_accounting`)
- Core operations modules are active (`inventory`, `shipment`, `vendor`, `products`, `investor`)

## Active Modules (from tenant_modules)

| Row ID | Module Key | Active | Created At (UTC) | Updated At (UTC) |
| :--- | :--- | :--- | :--- | :--- |
| 20 | `inventory` | `true` | `2026-05-22T10:02:52.459605+00:00` | `2026-05-22T10:02:52.459605+00:00` |
| 23 | `commerce_shop` | `true` | `2026-05-22T13:46:26.406114+00:00` | `2026-05-23T07:20:54.622875+00:00` |
| 24 | `shipment` | `true` | `2026-05-22T13:46:51.0031+00:00` | `2026-05-22T13:46:51.0031+00:00` |
| 25 | `vendor` | `true` | `2026-05-22T13:47:00.010487+00:00` | `2026-05-22T13:47:00.010487+00:00` |
| 26 | `products` | `true` | `2026-05-22T13:47:09.874944+00:00` | `2026-05-22T13:47:09.874944+00:00` |
| 28 | `investor` | `true` | `2026-05-22T13:47:26.923693+00:00` | `2026-05-22T13:47:26.923693+00:00` |
| 29 | `commerce_order` | `true` | `2026-05-23T07:21:55.752657+00:00` | `2026-05-23T07:21:55.752657+00:00` |
| 30 | `commerce_invoice` | `true` | `2026-05-23T07:22:03.592879+00:00` | `2026-05-23T07:22:03.592879+00:00` |
| 52 | `commerce_accounting` | `true` | `2026-06-01T09:53:00.249782+00:00` | `2026-06-01T09:53:00.249782+00:00` |
| 55 | `commerce_cart` | `true` | `2026-06-01T11:42:24.959841+00:00` | `2026-06-01T11:52:55.157492+00:00` |

## Tenant 11 Flow (End-to-End)

1. Customer uses `commerce_cart` in shop scope to add products and set recipient price.
2. Cart is placed into `commerce_order` with recipient information, delivery/wrapping/COD/invoice print charges.
3. Admin opens `commerce_order` details and generates a `commerce_invoice`.
4. Invoice items are mapped to real inventory items from `inventory`.
5. Stock is adjusted and inventory movement rows are written when items are assigned/removed.
6. `commerce_accounting` stores per-order-item financial rows (cost, sell, recipient sell, paid state).

## Delivery Charge Rule in Tenant 11

The current ecommerce rule in this tenant is:

- If delivery is **inclusive**, delivery charge is **not added** to grand total, but it **reduces profit**.
- If delivery is **exclusive**, delivery charge is **added** to grand total, and not deducted again as inclusive cost.

This rule is implemented in cart summary, order/invoice totals sync, and customer order profit display.

## Operational Notes

- Inventory assignment is now explicit per commerce order item (`inventory_item_id`, `shipment_item_id`).
- Commerce accounting is maintained as one row per `order_item_id` and updated via upsert.
- Removing invoice items reverses stock quantity impact.
- Tenant should keep shipment and inventory data healthy for accurate ecommerce cost/profit.
