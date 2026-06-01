# Commerce Accounting Module

This document describes ecommerce accounting behavior for Tenant 11 (`commerce_accounting`).

## Purpose

Track financials for each commerce order line after invoice linkage and inventory assignment.

## Key Fields Tracked

- `order_item_id`
- `inventory_item_id`
- `shipment_item_id`
- `cost_bdt`
- `sell_price_bdt`
- `recipient_sell_price_bdt`
- `is_customer_group_paid`

## Rules

- Accounting is maintained as one row per `order_item_id`.
- Entries are created/updated from invoice/item workflows using upsert behavior.
- Paid status syncs with invoice payment status.

## Tenant 11 Notes

- Module activated on `2026-06-01`.
- Works directly with `commerce_invoice` and `inventory` flows.
