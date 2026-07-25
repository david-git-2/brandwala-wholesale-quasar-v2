# Dropship B2B Invoice Refactor Task List

This document tracks the execution steps for refactoring the Dropship Accounting Invoice to a pure B2B Wholesale format, removing "dual-amount" complexities and separating third-party courier fees from Brandwala revenue.

## Goal
To treat dropship `global_invoices` strictly as a wholesale B2B sale to the middle man's billing profile, consisting of Goods + Packing + Print charges. Delivery and COD charges remain on the `shop_orders` ledger and do not leak into the B2B invoice.

## 1. Database Schema Updates
- [ ] Drop `face_subtotal_amount`, `accounting_subtotal_amount` columns from `global_invoices`.
- [ ] Drop `middle_man_payout_amount`, `middle_man_payout_status` from `global_invoices`
 (payout is now fully driven by `shop_orders`).
- [ ] Drop `cod_charge`, `courier_collected_amount`, `delivery_charge` from `global_invoices`. (Keep `shipping_charge` for standard wholesale use, but it is not used for courier dropship delivery).
- [ ] Drop `recipient_price_amount`, `line_face_total_amount` from `global_invoice_items`.
- [ ] Drop `return_face_amount`, `return_accounting_amount` from `global_return_items`. Rename to or keep a single `return_amount` column.

## 2. Backend RPC Updates
- [x] Refactor `create_dropship_invoice` RPC to:
  - Generate a single `subtotal_amount` based on `sell_price_amount` (B2B wholesale price).
  - Include only `packing_charge` and `print_charge`.
  - Exclude any COD or Delivery fee calculations.
  - Set `collection_source` to `billing_profile`.
- [x] Refactor return/void RPCs to use standard B2B return logic (credit the billing profile) instead of dual-amount clawbacks on the invoice.

## 3. Frontend UI Updates
- [x] **Invoice Details (`GlobalInvoiceDetailsPage.vue`)**: Remove the "Dual Price" tables (Accounting vs Face) for Dropship invoices. Render them exactly like standard Wholesale invoices.
- [x] **Settlement Ledger (`DropshipOrderDetailPage.vue` & Payout Reports)**: Ensure that COD amounts, middle-man payouts, and courier remittances are fetched directly from the `shop_orders` consignment fields, since they are no longer duplicated on `global_invoices`.
- [x] **Create Accounting Invoice Dialog**: Remove preview of "Face Totals" and "Courier Charges". Display a summary of Wholesale Items + Packing + Print.
