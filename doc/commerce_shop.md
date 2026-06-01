# Commerce Shop Module

The `commerce_shop` module is the app-side entry for the isolated ecommerce workflow.

## Purpose

- Provide a dedicated commerce operation area separate from legacy order/invoice modules.
- Coordinate commerce cart, order, invoice, and accounting features under one flow.

## Main Responsibilities

- Route users to commerce pages.
- Enforce tenant-scoped ecommerce operations.
- Keep commerce workflow independent from non-commerce order flows.

## Linked Modules

- `commerce_cart`
- `commerce_order`
- `commerce_invoice`
- `commerce_accounting`
- `inventory` (for stock assignment and costing)

## Tenant 11 Usage

Tenant 11 uses this module as the base container for the entire ecommerce operation stack.
