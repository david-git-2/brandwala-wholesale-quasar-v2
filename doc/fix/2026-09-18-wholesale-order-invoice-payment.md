# Wholesale order → invoice → payment fix

**Date:** 2026-09-18  
**Target:** [money-story](../docs/features/sales_invoice/money-story.md)

## Broken (as-built before fix)

| Step | Doc target | Code before |
| :--- | :--- | :--- |
| Invoice desk create/issue | `create_sales_invoice_from_payload` | `create_global_invoice` + loop `add_global_invoice_item` + `issue_wholesale_invoice` |
| Catalog fulfill | Same payload RPC, `collection_source=billing_profile` | `create_global_invoice` + `post_global_invoice`; dropship allowed; `recipient` collection_source when not prepaid |
| Collect | `collect_wholesale_invoice_payment` | Matrix said `create_billing_profile_payment_with_allocations`; live UI already used collect RPC |
| Dropship on invoice detail | Remittance on finance desk | “Record COD” on invoice detail |

## Target flow

1. **Walk-in wholesale:** draft/proforma/issue via payload → `issued` + `due` → collect on invoice detail.
2. **Catalog shop order:** confirmed fixed_price/checkout_wholesale → `fulfill_shop_order_to_invoice` → payload issue → collect on linked invoice.
3. **Never:** COD face as `total_amount`; dropship via fulfill; remittance on wholesale collect.

## Phases implemented

1. Docs + gap rows SI11, SO12  
2. `CreateWholesaleInvoicePage` → payload RPC  
3. `fulfill_shop_order_to_invoice` rewrite  
4. Invoice detail wholesale collect only; dropship COD → remittance link  
5. Strip COD from wholesale payload writers; cost snapshot on issue
